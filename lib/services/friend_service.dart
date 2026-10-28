import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user_model.dart';
import '../models/friendship_model.dart';

/// ระบบเพื่อนแบบขอ-ยอมรับ: ฝั่งที่กด "เพิ่มเพื่อน" จะเป็นการส่งคำขอ
/// (status: pending) ต้องให้อีกฝ่ายกด "ยอมรับ" (status: accepted) ก่อน
/// ถึงจะเป็นเพื่อนกันจริง เก็บเป็นเอกสารเดียวต่อคู่ (ไม่ใช่คนละ subcollection
/// ของแต่ละคน) เพื่อให้ทั้งสองฝ่ายอ่าน/แก้ไขความสัมพันธ์เดียวกันได้โดยไม่ต้อง
/// มีสิทธิ์เขียนข้าม user doc ของกันและกัน (Firestore rules จัดการง่ายกว่า)
class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection('friendships');

  /// id ของเอกสารความสัมพันธ์ แบบ deterministic จาก uid ทั้งสองฝั่ง
  /// (เรียงตัวอักษร) หาเจอเสมอไม่ว่าใครจะเป็นคนส่งคำขอก่อน
  String friendshipIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// ค้นหาผู้ใช้จากชื่อ (แบบ "ขึ้นต้นด้วย") ไม่รวมตัวเอง
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

  /// สถานะความสัมพันธ์ระหว่างเรากับ [otherUid] แบบเรียลไทม์ — ใช้ตัดสินใจ
  /// ว่าปุ่มเพื่อนควรเขียนว่าอะไร (เพิ่มเพื่อน/ยกเลิกคำขอ/ยอมรับคำขอ/เพื่อนกันแล้ว)
  Stream<FriendshipStatus> friendshipStatusStream(String otherUid) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(FriendshipStatus.none);

    final id = friendshipIdFor(user.uid, otherUid);
    return _friendships.doc(id).snapshots().map((doc) {
      if (!doc.exists) return FriendshipStatus.none;
      final data = doc.data()!;
      if (data['status'] == 'accepted') return FriendshipStatus.friends;
      final requestedBy = data['requestedBy'] as String?;
      return requestedBy == user.uid
          ? FriendshipStatus.requestSent
          : FriendshipStatus.requestReceived;
    });
  }

  /// ส่งคำขอเป็นเพื่อน
  Future<void> sendFriendRequest({
    required String targetUid,
    required String targetUsername,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final id = friendshipIdFor(user.uid, targetUid);
    final profile = await _users.doc(user.uid).get();
    final myUsername =
        profile.data()?['username'] as String? ?? user.displayName ?? 'unknown';

    await _friendships.doc(id).set({
      'participants': [user.uid, targetUid]..sort(),
      'usernames': {user.uid: myUsername, targetUid: targetUsername},
      'status': 'pending',
      'requestedBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ยอมรับคำขอเป็นเพื่อนที่ [otherUid] ส่งมา — เพิ่ม friendCount ให้ทั้ง
  /// สองฝ่ายพร้อมกัน (เก็บเป็นตัวเลขสะสมในโปรไฟล์ แทนการนับสดจาก
  /// friendships ทุกครั้ง เพราะอ่านเอกสารมิตรภาพของคนอื่นที่เราไม่เกี่ยวข้อง
  /// ไม่ได้ตาม rules — ดูหน้าโปรไฟล์คนอื่นแล้ว permission-denied ถ้านับสด)
  Future<void> acceptFriendRequest(String otherUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');
    final id = friendshipIdFor(user.uid, otherUid);

    final batch = _db.batch();
    batch.update(_friendships.doc(id), {'status': 'accepted'});
    batch.update(_users.doc(user.uid), {'friendCount': FieldValue.increment(1)});
    batch.update(_users.doc(otherUid), {'friendCount': FieldValue.increment(1)});
    await batch.commit();
  }

  /// ใช้ได้ทั้ง 3 กรณี: ปฏิเสธคำขอที่เขาส่งมา, ยกเลิกคำขอที่เราส่งไป,
  /// หรือเลิกเป็นเพื่อนกัน — ลด friendCount ของทั้งสองฝ่ายด้วย เฉพาะกรณีที่
  /// เคยเป็นเพื่อนกันจริง (status เดิมเป็น accepted) ไม่ใช่แค่คำขอค้างอยู่
  Future<void> removeFriendship(String otherUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');
    final id = friendshipIdFor(user.uid, otherUid);
    final ref = _friendships.doc(id);

    final doc = await ref.get();
    final wasAccepted = doc.data()?['status'] == 'accepted';

    final batch = _db.batch();
    batch.delete(ref);
    if (wasAccepted) {
      batch.update(_users.doc(user.uid), {'friendCount': FieldValue.increment(-1)});
      batch.update(_users.doc(otherUid), {'friendCount': FieldValue.increment(-1)});
    }
    await batch.commit();
  }

  /// คำขอที่ "คนอื่นส่งมาหาเรา" และยังไม่ได้ตอบรับ
  Future<List<Friendship>> fetchIncomingRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snap = await _friendships
        .where('participants', arrayContains: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    return snap.docs
        .map((d) => Friendship.fromDoc(d, user.uid))
        .where((f) => f.requestedBy != user.uid)
        .toList();
  }

  /// เพื่อนที่ยอมรับกันแล้วทั้งหมดของผู้ใช้คนปัจจุบัน
  Future<List<Friendship>> fetchFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snap = await _friendships
        .where('participants', arrayContains: user.uid)
        .where('status', isEqualTo: 'accepted')
        .get();

    return snap.docs.map((d) => Friendship.fromDoc(d, user.uid)).toList();
  }
}