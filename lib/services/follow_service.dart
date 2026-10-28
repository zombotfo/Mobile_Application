import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ระบบติดตาม (follow) — ต่างจากเพื่อน: กดติดตามได้ทันที ไม่ต้องรอฝั่งตรงข้าม
/// ยอมรับ และไม่ใช่ความสัมพันธ์สองทาง (ฉันติดตามเขา ไม่ได้แปลว่าเขาติดตามฉัน)
class FollowService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<void> followUser({
    required String targetUid,
    required String targetUsername,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');
    if (user.uid == targetUid) return; // กันติดตามตัวเอง

    await _users.doc(user.uid).collection('following').doc(targetUid).set({
      // เก็บ targetUid ซ้ำเป็นฟิลด์ด้วย (นอกจากเป็น doc id อยู่แล้ว)
      // เพื่อให้ query แบบ collectionGroup หาคนติดตามทั้งหมดของ target ได้
      'targetUid': targetUid,
      'targetUsername': targetUsername,
      'followedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollowUser(String targetUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');
    await _users.doc(user.uid).collection('following').doc(targetUid).delete();
  }

  Stream<bool> isFollowingStream(String targetUid) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);
    return _users
        .doc(user.uid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// จำนวนคนที่ติดตาม [uid] อยู่ — นับจาก subcollection following ของ
  /// "ทุกคน" ที่มี targetUid ตรงกับ uid นี้ (collection group query)
  Future<int> fetchFollowerCount(String uid) async {
    final agg = await _db
        .collectionGroup('following')
        .where('targetUid', isEqualTo: uid)
        .count()
        .get();
    return agg.count ?? 0;
  }

  /// จำนวนคนที่ [uid] กำลังติดตามอยู่
  Future<int> fetchFollowingCount(String uid) async {
    final agg = await _users.doc(uid).collection('following').count().get();
    return agg.count ?? 0;
  }
}
