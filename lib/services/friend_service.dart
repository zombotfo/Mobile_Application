import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_model.dart';

/// ระบบเพื่อนเป็นแบบทางเดียว (เหมือนลิสต์บุ๊กมาร์กส่วนตัว) — กดเพิ่มได้เลย
/// ไม่ต้องรอฝั่งตรงข้ามกดยอมรับ และไม่เกี่ยวข้องกับการแชทเลย (แชทคุยกับ
/// ใครก็ได้โดยไม่ต้องเป็นเพื่อนกันก่อน ดู ChatService)
class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// ค้นหาผู้ใช้จากชื่อ (แบบ "ขึ้นต้นด้วย") ไม่รวมตัวเอง
  /// Firestore ไม่รองรับค้นหาแบบ contains กลางคำ จึงทำได้แค่ prefix match
  Future<List<AppUser>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final snap = await _users
        .orderBy('username')
        .startAt([trimmed])
        .endAt(['$trimmed\uf8ff'])
        .limit(20)
        .get();

    return snap.docs
        .where((d) => d.id != myUid)
        .map(
          (d) => AppUser(
            uid: d.id,
            username: d.data()['username'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<void> addFriend({
    required String friendUid,
    required String friendUsername,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    await _users.doc(user.uid).collection('friends').doc(friendUid).set({
      'username': friendUsername,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFriend(String friendUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    await _users.doc(user.uid).collection('friends').doc(friendUid).delete();
  }

  /// เช็คว่า [friendUid] อยู่ในลิสต์เพื่อนของผู้ใช้คนปัจจุบันหรือยัง
  Stream<bool> isFriendStream(String friendUid) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);
    return _users
        .doc(user.uid)
        .collection('friends')
        .doc(friendUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<List<AppUser>> fetchFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snap = await _users
        .doc(user.uid)
        .collection('friends')
        .orderBy('username')
        .get();

    return snap.docs
        .map(
          (d) => AppUser(
            uid: d.id,
            username: d.data()['username'] as String? ?? '',
          ),
        )
        .toList();
  }
}
