import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';

/// Firestore จำกัดขนาดเอกสารไม่เกิน ~1MB ต่อชิ้น กันไว้ไม่ให้เกิน
/// (ตั้งไว้ที่ 700KB เผื่อระยะปลอดภัยสำหรับฟิลด์อื่นๆ ในเอกสารเดียวกัน)
const int _maxImageBytes = 700 * 1024;

/// วิดีโอไม่ได้ฝังในเอกสาร (อัปโหลดไป Cloudinary แทน) จึงกำกวดขนาดได้กว้าง
/// กว่ารูปมาก แต่ยังกันไว้ไม่ให้ใหญ่เกินจนอัปโหลดนานหรือกินโควตาฟรีเร็วเกินไป
const int _maxVideoBytes = 50 * 1024 * 1024; // 50MB

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  /// เรียกตอนสมัครสมาชิกสำเร็จ เพื่อสร้างเอกสารโปรไฟล์ผู้ใช้ใน Firestore
  /// (แยกจาก Firebase Auth ซึ่งเก็บแค่ email/password/displayName)
  Future<void> createUserProfile({
    required String uid,
    required String username,
    required String email,
  }) {
    return _users.doc(uid).set({
      'username': username,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'postKarma': 0,
    });
  }

  /// สตรีมโพสต์ทั้งหมดแบบเรียลไทม์ (เก็บไว้เผื่อใช้ในอนาคต — หน้า feed
  /// ปัจจุบันเปลี่ยนไปใช้ fetchPosts() แบบ poll เป็นรอบแทนแล้ว)
  Stream<List<Post>> postsStream() {
    return _posts
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromDoc).toList());
  }

  /// READ (ดึงครั้งเดียว ไม่ใช่เรียลไทม์): ใช้คู่กับการ poll เป็นรอบ
  /// (เช่นทุก 1 นาที) แทนการเปิด listener ค้างไว้ตลอดเวลา
  Future<List<Post>> fetchPosts() async {
    final snap = await _posts.orderBy('createdAt', descending: true).get();
    return snap.docs.map(Post.fromDoc).toList();
  }

  /// [imageBytes] ไม่บังคับ — ถ้าแนบมาจะเข้ารหัสเป็น Base64 แล้วฝังไว้ใน
  /// เอกสารโพสต์เลย (ไม่ต้องพึ่งบริการเก็บไฟล์แยกต่างหาก)
  /// [videoBytes] ไม่บังคับเช่นกัน — ถ้าแนบมาจะอัปโหลดขึ้น Cloudinary ก่อน
  /// แล้วเก็บแค่ลิงก์ไว้ (ไฟล์วิดีโอใหญ่เกินจะฝังในเอกสารได้)
  /// ใส่ได้แค่อย่างใดอย่างหนึ่ง ไม่ใช่ทั้งรูปและวิดีโอพร้อมกัน
  Future<void> createPost({
    required String title,
    required String body,
    Uint8List? imageBytes,
    Uint8List? videoBytes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    if (imageBytes != null && imageBytes.length > _maxImageBytes) {
      throw Exception(
        'รูปใหญ่เกินไป (จำกัดประมาณ 700KB) ลองเลือกรูปอื่นที่ไฟล์เล็กกว่านี้',
      );
    }
    if (videoBytes != null && videoBytes.length > _maxVideoBytes) {
      throw Exception('วิดีโอใหญ่เกินไป (จำกัดประมาณ 50MB) ลองใช้คลิปสั้นลง');
    }

    // ดึง username จากโปรไฟล์ Firestore (ไม่ใช้ displayName ตรงๆ
    // เพื่อให้สอดคล้องกับที่โชว์ในแอปเสมอ แม้ภายหลังจะมีหน้าแก้ไขโปรไฟล์)
    final profile = await _users.doc(user.uid).get();
    final username =
        profile.data()?['username'] as String? ?? user.displayName ?? 'unknown';

    String? videoUrl;
    if (videoBytes != null) {
      videoUrl = await _uploadVideoToCloudinary(videoBytes);
    }

    await _posts.add({
      'authorId': user.uid,
      'authorUsername': username,
      'title': title.trim(),
      'body': body.trim(),
      'imageBase64': imageBytes != null ? base64Encode(imageBytes) : null,
      'videoUrl': videoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'upvoteCount': 0,
      'downvoteCount': 0,
      'commentCount': 0,
      'reactionCounts': <String, int>{},
    });
  }

  /// อัปโหลดวิดีโอขึ้น Cloudinary แบบ unsigned upload (คนละ endpoint กับรูป
  /// ต้องใช้ /video/upload ไม่ใช่ /image/upload) แล้วคืน URL มาเก็บในโพสต์
  Future<String> _uploadVideoToCloudinary(Uint8List bytes) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/video/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'post.mp4'),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('อัปโหลดวิดีโอไม่สำเร็จ (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  /// ตั้งค่าโหวตของผู้ใช้คนปัจจุบัน: [value] เป็น 1 (ถูกใจ) หรือ -1 (ไม่ถูกใจ)
  /// กดปุ่มเดิมซ้ำ = ยกเลิกโหวต, กดอีกปุ่ม = สลับฝั่งทันที (เลือกได้แค่
  /// อย่างใดอย่างหนึ่งต่อโพสต์ เหมือน Reddit) ใช้ transaction กันยอดเพี้ยน
  Future<void> setVote(String postId, int value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final postRef = _posts.doc(postId);
    final voteRef = postRef.collection('votes').doc(user.uid);

    await _db.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      final postSnap = await tx.get(postRef);
      final currentUp = (postSnap.data()?['upvoteCount'] as int?) ?? 0;
      final currentDown = (postSnap.data()?['downvoteCount'] as int?) ?? 0;
      final existingValue = voteSnap.data()?['value'] as int?;

      if (existingValue == value) {
        // กดปุ่มเดิมซ้ำ = ยกเลิกโหวต
        tx.delete(voteRef);
        final field = value == 1 ? 'upvoteCount' : 'downvoteCount';
        final newCount = (value == 1 ? currentUp : currentDown) - 1;
        tx.update(postRef, {field: newCount});
        return;
      }

      tx.set(voteRef, {
        'value': value,
        'votedAt': FieldValue.serverTimestamp(),
      });

      if (existingValue == null) {
        // ยังไม่เคยโหวตมาก่อน
        final field = value == 1 ? 'upvoteCount' : 'downvoteCount';
        final newCount = (value == 1 ? currentUp : currentDown) + 1;
        tx.update(postRef, {field: newCount});
      } else {
        // เคยกดอีกฝั่งไว้ สลับฝั่งทันที (ลบของเก่า เพิ่มของใหม่)
        tx.update(postRef, {
          'upvoteCount': value == 1 ? currentUp + 1 : currentUp - 1,
          'downvoteCount': value == -1 ? currentDown + 1 : currentDown - 1,
        });
      }
    });
  }

  /// ดึงสถานะโหวตปัจจุบันของผู้ใช้คนนี้สำหรับโพสต์นี้ (1 / -1 / null)
  Stream<int?> voteValueStream(String postId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);
    return _posts
        .doc(postId)
        .collection('votes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.data()?['value'] as int?);
  }

  /// อิโมจิที่เลือก react ได้ (คนละชุดกับปุ่มถูกใจ/ไม่ถูกใจด้านบน)
  static const List<String> reactionEmojis = ['❤️', '😂', '😮', '😢', '😡'];

  /// ตอบสนองโพสต์ด้วยอิโมจิ: แตะอันเดิมซ้ำ = ยกเลิก, แตะอันอื่น = เปลี่ยน
  /// เลือกได้แค่ 1 อิโมจิต่อคนต่อโพสต์ (เหมือน Facebook reaction)
  Future<void> setReaction(String postId, String emoji) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final postRef = _posts.doc(postId);
    final reactionRef = postRef.collection('reactions').doc(user.uid);

    await _db.runTransaction((tx) async {
      final reactionSnap = await tx.get(reactionRef);
      final postSnap = await tx.get(postRef);
      final counts = Map<String, dynamic>.from(
        postSnap.data()?['reactionCounts'] as Map? ?? const {},
      );
      final existingEmoji = reactionSnap.data()?['emoji'] as String?;

      int countFor(String e) => (counts[e] as int?) ?? 0;

      if (existingEmoji == emoji) {
        tx.delete(reactionRef);
        counts[emoji] = countFor(emoji) - 1;
      } else {
        if (existingEmoji != null) {
          counts[existingEmoji] = countFor(existingEmoji) - 1;
        }
        counts[emoji] = countFor(emoji) + 1;
        tx.set(reactionRef, {
          'emoji': emoji,
          'reactedAt': FieldValue.serverTimestamp(),
        });
      }

      tx.update(postRef, {'reactionCounts': counts});
    });
  }

  /// ดึงอิโมจิที่ผู้ใช้คนปัจจุบัน react ไว้กับโพสต์นี้ (null = ยังไม่ได้ react)
  Stream<String?> myReactionStream(String postId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);
    return _posts
        .doc(postId)
        .collection('reactions')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.data()?['emoji'] as String?);
  }

  /// ดึงเอกสารโปรไฟล์ของผู้ใช้คนปัจจุบัน (ใช้เปิดหน้าแก้ไขโปรไฟล์)
  Future<Map<String, dynamic>?> fetchOwnProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return fetchUserProfile(user.uid);
  }

  /// ดึงเอกสารโปรไฟล์ของผู้ใช้คนไหนก็ได้จาก uid (ใช้เปิดหน้าโปรไฟล์คนอื่น)
  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data();
  }

  /// โพสต์ทั้งหมดของผู้ใช้คนไหนก็ได้ เรียงใหม่สุดก่อน (เรียงฝั่ง client
  /// แทน orderBy ใน query เพื่อเลี่ยงการต้องสร้าง composite index เพิ่ม)
  Future<List<Post>> fetchPostsByAuthor(String uid) async {
    final snap = await _posts.where('authorId', isEqualTo: uid).get();
    final posts = snap.docs.map(Post.fromDoc).toList();
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  /// ดึงแค่รูปโปรไฟล์ (Base64) ของผู้ใช้คนไหนก็ได้จาก uid — ใช้โชว์อวาตาร์
  /// ในหน้าหลัก (ของตัวเอง) และในการ์ดโพสต์ (ของเจ้าของโพสต์)
  Future<String?> fetchUserPhotoBase64(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data()?['photoBase64'] as String?;
  }

  /// UPDATE: แก้ไขชื่อผู้ใช้และ/หรือรูปโปรไฟล์ ทั้งในเอกสารโปรไฟล์ Firestore,
  /// displayName ฝั่ง Firebase Auth และ "โพสต์เก่าทั้งหมด" ของผู้ใช้คนนี้
  /// ให้ชื่อตรงกัน (ตอนสร้างโพสต์เราคัดลอก username ฝังไว้ในแต่ละโพสต์เพื่อ
  /// ลดการอ่านซ้ำ เปลี่ยนชื่อทีหลังจึงต้องไล่อัปเดตโพสต์เก่าตามไปด้วย)
  /// [photoBytes] ไม่ใส่ = ไม่เปลี่ยนรูป, [removePhoto] = true = เอารูปเดิมออก
  Future<void> updateUsername(
    String newUsername, {
    Uint8List? photoBytes,
    bool removePhoto = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    if (photoBytes != null && photoBytes.length > _maxImageBytes) {
      throw Exception(
        'รูปใหญ่เกินไป (จำกัดประมาณ 700KB) ลองเลือกรูปอื่นที่ไฟล์เล็กกว่านี้',
      );
    }

    final trimmed = newUsername.trim();
    final updates = <String, dynamic>{'username': trimmed};
    if (photoBytes != null) {
      updates['photoBase64'] = base64Encode(photoBytes);
    } else if (removePhoto) {
      updates['photoBase64'] = null;
    }

    await _users.doc(user.uid).update(updates);
    await user.updateDisplayName(trimmed);

    final ownPosts = await _posts.where('authorId', isEqualTo: user.uid).get();
    if (ownPosts.docs.isEmpty) return;

    // Firestore จำกัดไม่เกิน 500 operation ต่อ 1 batch จึงแบ่งอัปเดตเป็นชุดๆ
    const chunkSize = 500;
    for (var i = 0; i < ownPosts.docs.length; i += chunkSize) {
      final batch = _db.batch();
      for (final doc in ownPosts.docs.skip(i).take(chunkSize)) {
        batch.update(doc.reference, {'authorUsername': trimmed});
      }
      await batch.commit();
    }
  }

  /// UPDATE: แก้ไขโพสต์ (หัวข้อ/เนื้อหา/สื่อแนบ) — เฉพาะเจ้าของโพสต์เท่านั้น
  /// ที่แก้ได้จริง (บังคับโดย Firestore Security Rules ฝั่งเซิร์ฟเวอร์)
  /// รูปและวิดีโอ: ไม่ใส่ = ไม่เปลี่ยน, removeImage/removeVideo = true = เอาออก
  Future<void> updatePost({
    required String postId,
    required String title,
    required String body,
    Uint8List? imageBytes,
    bool removeImage = false,
    Uint8List? videoBytes,
    bool removeVideo = false,
  }) async {
    if (imageBytes != null && imageBytes.length > _maxImageBytes) {
      throw Exception(
        'รูปใหญ่เกินไป (จำกัดประมาณ 700KB) ลองเลือกรูปอื่นที่ไฟล์เล็กกว่านี้',
      );
    }
    if (videoBytes != null && videoBytes.length > _maxVideoBytes) {
      throw Exception('วิดีโอใหญ่เกินไป (จำกัดประมาณ 50MB) ลองใช้คลิปสั้นลง');
    }

    final updates = <String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
    };
    if (imageBytes != null) {
      updates['imageBase64'] = base64Encode(imageBytes);
    } else if (removeImage) {
      updates['imageBase64'] = null;
    }

    if (videoBytes != null) {
      updates['videoUrl'] = await _uploadVideoToCloudinary(videoBytes);
    } else if (removeVideo) {
      updates['videoUrl'] = null;
    }

    await _posts.doc(postId).update(updates);
  }

  /// DELETE: ลบโพสต์เดียว (เฉพาะเจ้าของ) — ลบ subcollection votes, comments
  /// และ reactions ที่ค้างอยู่ไปด้วยกันเป็น batch เดียว กันไม่ให้มีข้อมูลกำพร้า
  Future<void> deletePost(String postId) async {
    final postRef = _posts.doc(postId);
    final votes = await postRef.collection('votes').get();
    final comments = await postRef.collection('comments').get();
    final reactions = await postRef.collection('reactions').get();

    final batch = _db.batch();
    for (final doc in votes.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in comments.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in reactions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(postRef);
    await batch.commit();
  }

  /// READ (เรียลไทม์): ความคิดเห็นของโพสต์ เรียงเก่าสุดขึ้นก่อน
  /// ใช้ตอนเปิดหน้ารายละเอียดโพสต์อยู่ (ต้องการความไวเห็นคอมเมนต์ใหม่ทันที
  /// ต่างจากฟีดโพสต์หลักที่ poll แทน)
  Stream<List<Comment>> commentsStream(String postId) {
    return _posts
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(Comment.fromDoc).toList());
  }

  /// CREATE: แสดงความคิดเห็น — เพิ่มเอกสารคอมเมนต์ และเพิ่ม commentCount
  /// ของโพสต์พร้อมกันเป็น batch เดียว (ใช้ increment กันปัญหาค่าชนกัน
  /// ถ้ามีคนคอมเมนต์พร้อมกันหลายคน)
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final profile = await _users.doc(user.uid).get();
    final username =
        profile.data()?['username'] as String? ?? user.displayName ?? 'unknown';

    final postRef = _posts.doc(postId);
    final batch = _db.batch();
    batch.set(postRef.collection('comments').doc(), {
      'authorId': user.uid,
      'authorUsername': username,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(postRef, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  /// DELETE: ลบความคิดเห็น (เจ้าของคอมเมนต์ หรือเจ้าของโพสต์ลบได้)
  /// ลดค่า commentCount ของโพสต์ลง 1 พร้อมกันไปด้วย
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final postRef = _posts.doc(postId);
    final batch = _db.batch();
    batch.delete(postRef.collection('comments').doc(commentId));
    batch.update(postRef, {'commentCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  /// CREATE: รายงานโพสต์ — ใช้ uid ของผู้รายงานเป็น document id เอง
  /// เพื่อกันไม่ให้คนเดียวกันรายงานโพสต์เดียวกันซ้ำหลายครั้ง (set ทับของเดิม)
  Future<void> reportPost(String postId, {required String reason}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    await _posts.doc(postId).collection('reports').doc(user.uid).set({
      'reason': reason,
      'reportedAt': FieldValue.serverTimestamp(),
    });
  }

  /// DELETE: ลบบัญชีถาวร — ลบโพสต์ทั้งหมดของผู้ใช้ + เอกสารโปรไฟล์ใน Firestore
  /// ก่อน (ใช้ batch ให้ลบพร้อมกันเป็นชุดเดียว) แล้วค่อยลบบัญชีจาก Firebase Auth
  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final uid = user.uid;
    final ownPosts = await _posts.where('authorId', isEqualTo: uid).get();

    final batch = _db.batch();
    for (final doc in ownPosts.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_users.doc(uid));
    await batch.commit();

    // ลบบัญชีจริงจาก Firebase Auth เป็นขั้นตอนสุดท้าย
    // (ถ้า session เก่าเกินไป Firebase จะโยน error 'requires-recent-login'
    // ต้องให้ผู้ใช้ออกจากระบบแล้วเข้าใหม่ก่อนจะลบได้)
    await user.delete();
  }
}
