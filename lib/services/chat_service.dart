import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message_model.dart';
import '../models/chat_model.dart';

/// ระบบแชท 1:1 คุยกับใครก็ได้ ไม่ต้องเป็นเพื่อนกันก่อน
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

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

  /// สร้างห้องแชทถ้ายังไม่มี (merge กันทับของเดิม) แล้วคืน chatId ไปเปิดต่อ
  /// ใช้ได้กับผู้ใช้คนไหนก็ได้ ไม่เช็คสถานะเพื่อนเลย
  Future<String> startChat({
    required String otherUid,
    required String otherUsername,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

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
}
