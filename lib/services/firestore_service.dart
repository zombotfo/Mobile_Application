import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/post_model.dart';

/// Firestore จำกัดขนาดเอกสารไม่เกิน ~1MB ต่อชิ้น กันไว้ไม่ให้เกิน
/// (ตั้งไว้ที่ 700KB เผื่อระยะปลอดภัยสำหรับฟิลด์อื่นๆ ในเอกสารเดียวกัน)
const int _maxImageBytes = 700 * 1024;

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
  Future<void> createPost({
    required String title,
    required String body,
    Uint8List? imageBytes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    if (imageBytes != null && imageBytes.length > _maxImageBytes) {
      throw Exception(
        'รูปใหญ่เกินไป (จำกัดประมาณ 700KB) ลองเลือกรูปอื่นที่ไฟล์เล็กกว่านี้',
      );
    }

    // ดึง username จากโปรไฟล์ Firestore (ไม่ใช้ displayName ตรงๆ
    // เพื่อให้สอดคล้องกับที่โชว์ในแอปเสมอ แม้ภายหลังจะมีหน้าแก้ไขโปรไฟล์)
    final profile = await _users.doc(user.uid).get();
    final username =
        profile.data()?['username'] as String? ?? user.displayName ?? 'unknown';

    await _posts.add({
      'authorId': user.uid,
      'authorUsername': username,
      'title': title.trim(),
      'body': body.trim(),
      'imageBase64': imageBytes != null ? base64Encode(imageBytes) : null,
      'createdAt': FieldValue.serverTimestamp(),
      'upvoteCount': 0,
      'commentCount': 0,
    });
  }

  /// สลับสถานะโหวตของผู้ใช้คนปัจจุบัน กดซ้ำ = ยกเลิกโหวต
  /// ใช้ transaction กันกรณีมีคนกดพร้อมกันหลายคนไม่ให้ยอดโหวตเพี้ยน
  Future<void> toggleUpvote(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final postRef = _posts.doc(postId);
    final voteRef = postRef.collection('votes').doc(user.uid);

    await _db.runTransaction((tx) async {
      final voteSnap = await tx.get(voteRef);
      final postSnap = await tx.get(postRef);
      final currentCount = (postSnap.data()?['upvoteCount'] as int?) ?? 0;

      if (voteSnap.exists) {
        tx.delete(voteRef);
        tx.update(postRef, {'upvoteCount': currentCount - 1});
      } else {
        tx.set(voteRef, {'votedAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'upvoteCount': currentCount + 1});
      }
    });
  }

  /// เช็คว่าผู้ใช้คนปัจจุบันโหวตโพสต์นี้ไปหรือยัง เพื่อโชว์สีปุ่มโหวตให้ถูก
  Stream<bool> hasUpvotedStream(String postId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);
    return _posts
        .doc(postId)
        .collection('votes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// ดึงเอกสารโปรไฟล์ของผู้ใช้คนปัจจุบัน (ใช้เปิดหน้าแก้ไขโปรไฟล์)
  Future<Map<String, dynamic>?> fetchOwnProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await _users.doc(user.uid).get();
    return doc.data();
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

  /// UPDATE: แก้ไขโพสต์ (หัวข้อ/เนื้อหา/รูปภาพ) — เฉพาะเจ้าของโพสต์เท่านั้น
  /// ที่แก้ได้จริง (บังคับโดย Firestore Security Rules ฝั่งเซิร์ฟเวอร์)
  /// [imageBytes] ไม่ใส่ = ไม่เปลี่ยนรูป, [removeImage] = true = เอารูปเดิมออก
  Future<void> updatePost({
    required String postId,
    required String title,
    required String body,
    Uint8List? imageBytes,
    bool removeImage = false,
  }) async {
    if (imageBytes != null && imageBytes.length > _maxImageBytes) {
      throw Exception(
        'รูปใหญ่เกินไป (จำกัดประมาณ 700KB) ลองเลือกรูปอื่นที่ไฟล์เล็กกว่านี้',
      );
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

    await _posts.doc(postId).update(updates);
  }

  /// DELETE: ลบโพสต์เดียว (เฉพาะเจ้าของ) — ลบ subcollection votes ที่ค้างอยู่
  /// ไปด้วยกันเป็น batch เดียว กันไม่ให้มีข้อมูลกำพร้าหลงเหลือ
  Future<void> deletePost(String postId) async {
    final postRef = _posts.doc(postId);
    final votes = await postRef.collection('votes').get();

    final batch = _db.batch();
    for (final doc in votes.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(postRef);
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