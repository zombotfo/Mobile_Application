import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message_model.dart';
import '../models/chat_model.dart';
import 'cloudinary_service.dart';

/// ระบบแชท 1:1 คุยกับใครก็ได้ ไม่ต้องเป็นเพื่อนกันก่อน
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int _maxChatImageBytes = 650 * 1024;
  static const int _maxChatVideoBytes = 50 * 1024 * 1024;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  Stream<Map<String, dynamic>?> userProfileStream(String uid) =>
      _users.doc(uid).snapshots().map((doc) => doc.data());

  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data();
  }

  /// สร้าง id ห้องแชทแบบ deterministic จาก uid ทั้งสองฝั่ง (เรียงตัวอักษร)
  /// เพื่อให้เจอห้องเดิมเสมอไม่ว่าใครจะเป็นคนเริ่มทักก่อน
  String chatIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// READ (ดึงครั้งเดียว): ห้องแชททั้งหมดที่ผู้ใช้คนปัจจุบันอยู่ในนั้น
  Future<List<ChatSummary>> fetchChats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snap = await _chats
        .where('participants', arrayContains: user.uid)
        .orderBy('lastMessageAt', descending: true)
        .get();

    return snap.docs.map((d) => ChatSummary.fromDoc(d, user.uid)).toList();
  }

  /// Streams chat summaries so previews update as soon as a message is sent.
  Stream<List<ChatSummary>> chatsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const <ChatSummary>[]);

    return _chats
        .where('participants', arrayContains: user.uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatSummary.fromDoc(doc, user.uid))
            .toList());
  }

  /// สร้างห้องแชทถ้ายังไม่มี (merge กันทับของเดิม) แล้วคืน chatId ไปเปิดต่อ
  /// ใช้ได้กับผู้ใช้คนไหนก็ได้ตามปกติ — ยกเว้นถ้าอีกฝ่ายตั้งบัญชีเป็น
  /// private ไว้ จะทักได้เฉพาะตอนเป็นเพื่อนกันแล้วเท่านั้น
  Future<String> startChat({
    required String otherUid,
    required String otherUsername,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    if (user.uid != otherUid) {
      final targetDoc = await _users.doc(otherUid).get();
      final isPrivate = targetDoc.data()?['isPrivate'] as bool? ?? false;
      if (isPrivate) {
        final sorted = [user.uid, otherUid]..sort();
        final friendshipDoc = await _db
            .collection('friendships')
            .doc('${sorted[0]}_${sorted[1]}')
            .get();
        final isFriend = friendshipDoc.data()?['status'] == 'accepted';
        if (!isFriend) {
          throw Exception(
            'บัญชีนี้เป็นส่วนตัว ต้องเป็นเพื่อนกันก่อนถึงจะส่งข้อความได้',
          );
        }
      }
    }

    final chatId = chatIdFor(user.uid, otherUid);
    final myProfile = await _users.doc(user.uid).get();
    final myUsername =
        myProfile.data()?['username'] as String? ?? user.displayName ?? 'unknown';

    await _chats.doc(chatId).set({
      'participants': [user.uid, otherUid],
      'participantUsernames': {user.uid: myUsername, otherUid: otherUsername},
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': '',
    }, SetOptions(merge: true));

    return chatId;
  }

  /// ข้อความในห้องแชทที่เปิดดูอยู่ ใช้เรียลไทม์ (ต่างจากฟีดโพสต์ที่ poll
  /// แทน เพราะแชทที่กำลังเปิดอยู่ต้องการความไวในการเห็นข้อความใหม่)
  Stream<List<ChatMessage>> messagesStream(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final chatRef = _chats.doc(chatId);
    final batch = _db.batch();
    batch.set(chatRef.collection('messages').doc(), {
      'senderId': user.uid,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
    });
    batch.update(chatRef, {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': user.uid,
    });
    await batch.commit();
  }

  Future<void> sendImage({
    required String chatId,
    required XFile file,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบก่อน');
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxChatImageBytes) {
      throw Exception('รูปใหญ่เกินไป กรุณาเลือกภาพที่เล็กกว่า 650 KB');
    }

    final chatRef = _chats.doc(chatId);
    final batch = _db.batch();
    batch.set(chatRef.collection('messages').doc(), {
      'senderId': user.uid,
      'text': '',
      'mediaBase64': base64Encode(bytes),
      'mediaContentType': file.mimeType ?? 'image/jpeg',
      'mediaType': 'image',
      'sentAt': FieldValue.serverTimestamp(),
    });
    batch.update(chatRef, {
      'lastMessage': 'ส่งรูปภาพ',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': user.uid,
    });
    await batch.commit();
  }

  Future<void> sendVideo({
    required String chatId,
    required XFile file,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบก่อน');
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxChatVideoBytes) {
      throw Exception('วิดีโอใหญ่เกินไป กรุณาเลือกคลิปที่เล็กกว่า 50 MB');
    }

    final extension = file.name.contains('.') ? file.name.split('.').last : 'mp4';
    final url = await CloudinaryService().uploadVideo(
      bytes,
      filename: 'chat_${user.uid}.$extension',
    );

    final chatRef = _chats.doc(chatId);
    final batch = _db.batch();
    batch.set(chatRef.collection('messages').doc(), {
      'senderId': user.uid,
      'text': '',
      'mediaUrl': url,
      'mediaType': 'video',
      'sentAt': FieldValue.serverTimestamp(),
    });
    batch.update(chatRef, {
      'lastMessage': 'ส่งวิดีโอ',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': user.uid,
    });
    await batch.commit();
  }
}
