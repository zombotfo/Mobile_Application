import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Stores one-way blocks and resolves block relationships between two users.
class BlockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _blockedUsers(String blockerUid) =>
      _db.collection('blocks').doc(blockerUid).collection('blockedUsers');

  Future<void> blockUser(String targetUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบก่อน');
    if (user.uid == targetUid) throw Exception('ไม่สามารถบล็อกบัญชีตัวเองได้');

    final ref = _blockedUsers(user.uid).doc(targetUid);
    if ((await ref.get()).exists) return;
    await ref.set({
      'blockerUid': user.uid,
      'blockedUid': targetUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String targetUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('กรุณาเข้าสู่ระบบก่อน');
    await _blockedUsers(uid).doc(targetUid).delete();
  }

  Future<bool> hasBlocked(String targetUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return (await _blockedUsers(uid).doc(targetUid).get()).exists;
  }

  Future<bool> isBlockedEitherWay(String otherUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == otherUid) return false;
    final results = await Future.wait([
      _blockedUsers(uid).doc(otherUid).get(),
      _blockedUsers(otherUid).doc(uid).get(),
    ]);
    return results.any((doc) => doc.exists);
  }

  /// IDs of people in a block relationship with the signed-in user.
  Future<Set<String>> fetchBlockedUserIds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final outgoing = await _blockedUsers(uid).get();
    final incoming = await _db
        .collectionGroup('blockedUsers')
        .where('blockedUid', isEqualTo: uid)
        .get();
    return {
      ...outgoing.docs.map((doc) => doc.id),
      ...incoming.docs.map((doc) => doc.data()['blockerUid'] as String),
    };
  }

  Future<Set<String>> fetchUsersWhoBlockedMe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};
    final incoming = await _db
        .collectionGroup('blockedUsers')
        .where('blockedUid', isEqualTo: uid)
        .get();
    return incoming.docs
        .map((doc) => doc.data()['blockerUid'] as String)
        .toSet();
  }

  Stream<Set<String>> blockedUserIdsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(<String>{});

    late StreamController<Set<String>> controller;
    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> outgoingSub;
    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> incomingSub;
    Set<String> outgoing = {};
    Set<String> incoming = {};

    void emit() => controller.add({...outgoing, ...incoming});

    controller = StreamController<Set<String>>(
      onListen: () {
        outgoingSub = _blockedUsers(uid).snapshots().listen(
          (snapshot) {
            outgoing = snapshot.docs.map((doc) => doc.id).toSet();
            emit();
          },
          onError: controller.addError,
        );
        incomingSub = _db
            .collectionGroup('blockedUsers')
            .where('blockedUid', isEqualTo: uid)
            .snapshots()
            .listen(
              (snapshot) {
                incoming = snapshot.docs
                    .map((doc) => doc.data()['blockerUid'] as String)
                    .toSet();
                emit();
              },
              onError: controller.addError,
            );
      },
      onCancel: () async {
        await outgoingSub.cancel();
        await incomingSub.cancel();
      },
    );
    return controller.stream;
  }
}
