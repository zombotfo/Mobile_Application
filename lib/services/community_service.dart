import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/community_model.dart';
import '../models/post_model.dart';

/// ไอคอนชุมชนฝังเป็น Base64 ในเอกสารเหมือนรูปโปรไฟล์ (จำกัดไม่เกิน ~700KB)
const int _maxIconBytes = 700 * 1024;

/// ระบบชุมชน (เหมือน subreddit): สร้างชุมชน, เข้าร่วม/ขออนุมัติ, ออกจากชุมชน
///
/// โครงสร้างข้อมูล:
/// - communities/{ชื่อตัวพิมพ์เล็ก}          ข้อมูลชุมชน
/// - communityMembers/{ชุมชน}~{uid}          สมาชิก 1 คน = 1 เอกสาร (status: active/pending)
///   ใช้เอกสารเดียวต่อสมาชิก เพื่อให้ทั้งผู้ขอเข้าร่วมและเจ้าของชุมชนจัดการ
///   เอกสารเดียวกันได้โดยไม่ต้องเขียนข้าม user doc ของกันและกัน
class CommunityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _communities =>
      _db.collection('communities');
  CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection('communityMembers');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  static final RegExp nameRegex = RegExp(r'^[A-Za-z0-9_ก-๙]{3,21}$');

  /// id เอกสารสมาชิก ใช้ ~ คั่น เพราะชื่อชุมชนมี _ ได้ (กันแยกส่วนผิด)
  String memberDocId(String communityId, String uid) => '$communityId~$uid';

  Future<String> _myUsername(User user) async {
    final profile = await _users.doc(user.uid).get();
    return profile.data()?['username'] as String? ??
        user.displayName ??
        'unknown';
  }

  /// CREATE: สร้างชุมชนใหม่ แล้วให้ผู้สร้างเป็นสมาชิกคนแรก (บทบาท owner)
  /// คืน id ของชุมชนที่สร้าง
  Future<String> createCommunity({
    required String name,
    required String joinType,
    Uint8List? imageBytes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final trimmed = name.trim();
    if (!nameRegex.hasMatch(trimmed)) {
      throw Exception('ชื่อชุมชนใช้ภาษาไทย a-z, 0-9 และ _ ได้ ความยาว 3–21 ตัวอักษร');
    }
    if (imageBytes != null && imageBytes.length > _maxIconBytes) {
      throw Exception('รูปใหญ่เกินไป (จำกัดประมาณ 700KB) ลองเลือกรูปอื่น');
    }

    final id = trimmed.toLowerCase();
    final ref = _communities.doc(id);
    if ((await ref.get()).exists) {
      throw Exception('มีชุมชนชื่อ r/$trimmed อยู่แล้ว ลองใช้ชื่ออื่น');
    }

    final username = await _myUsername(user);
    await ref.set({
      'name': trimmed,
      'nameLower': id,
      'joinType': joinType,
      'ownerId': user.uid,
      'ownerUsername': username,
      'memberCount': 1,
      'imageBase64': imageBytes != null ? base64Encode(imageBytes) : null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // เขียนแยกจากข้างบน (ไม่ใช่ batch เดียว) เพราะ rules ของเอกสารสมาชิก
    // ต้องอ่านเอกสารชุมชนที่มีอยู่แล้วเพื่อยืนยันว่าเราเป็นเจ้าของจริง
    try {
      await _members.doc(memberDocId(id, user.uid)).set({
        'communityId': id,
        'uid': user.uid,
        'username': username,
        'ownerId': user.uid,
        'role': 'owner',
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await ref.delete(); // ย้อนกลับ ไม่ให้เหลือชุมชนที่ไม่มีสมาชิกเลย
      rethrow;
    }
    return id;
  }

  Future<Community?> fetchCommunity(String communityId) async {
    final doc = await _communities.doc(communityId).get();
    return doc.exists ? Community.fromDoc(doc) : null;
  }

  /// Deletes a community and its member, post, and post subcollection records.
  /// The ownership check is repeated here so callers cannot delete another
  /// user's community by passing an arbitrary id.
  Future<void> deleteCommunity(String communityId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบก่อน');

    final communityRef = _communities.doc(communityId);
    final community = await communityRef.get();
    if (!community.exists || community.data()?['ownerId'] != user.uid) {
      throw Exception('คุณไม่มีสิทธิ์ลบชุมชนนี้');
    }

    final members = await _members
        .where('communityId', isEqualTo: communityId)
        .where('ownerId', isEqualTo: user.uid)
        .get();
    final posts = await _posts
        .where('communityId', isEqualTo: communityId)
        .get();

    final references = <DocumentReference<Map<String, dynamic>>>[
      ...members.docs.map((doc) => doc.reference),
    ];
    for (final post in posts.docs) {
      for (final subcollection in ['votes', 'comments', 'reactions', 'reports']) {
        final children = await post.reference.collection(subcollection).get();
        references.addAll(children.docs.map((doc) => doc.reference));
      }
      references.add(post.reference);
    }
    references.add(communityRef);

    // Rules for nested records check the post and its community owner. Keep
    // each commit small enough to stay within Firestore's rule lookup limit.
    const batchLimit = 10;
    for (var start = 0; start < references.length; start += batchLimit) {
      final end = (start + batchLimit).clamp(0, references.length).toInt();
      final batch = _db.batch();
      for (final reference in references.sublist(start, end)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }

  Future<List<Community>> fetchCommunitiesByIds(Iterable<String> ids) async {
    final list = ids.toList();
    final result = <Community>[];
    for (var i = 0; i < list.length; i += 10) {
      final chunk = list.sublist(i, min(i + 10, list.length));
      final snap =
          await _communities.where(FieldPath.documentId, whereIn: chunk).get();
      result.addAll(snap.docs.map(Community.fromDoc));
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  /// ค้นหาชุมชนจากชื่อ (แบบ "ขึ้นต้นด้วย")
  Future<List<Community>> searchCommunities(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final snap = await _communities
        .orderBy('nameLower')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(20)
        .get();
    return snap.docs.map(Community.fromDoc).toList();
  }

  /// id ของชุมชนที่เราเป็นสมาชิกแล้ว (ไม่รวมที่ยังรออนุมัติ)
  Future<Set<String>> fetchMyActiveCommunityIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snap = await _members.where('uid', isEqualTo: user.uid).get();
    return snap.docs
        .where((d) => d.data()['status'] == 'active')
        .map((d) => d.data()['communityId'] as String)
        .toSet();
  }

  Future<List<Community>> fetchMyCommunities() async {
    final ids = await fetchMyActiveCommunityIds();
    if (ids.isEmpty) return [];
    return fetchCommunitiesByIds(ids);
  }

  /// Popular communities the current user has not joined yet.
  Future<List<Community>> fetchRecommendedCommunities({
    Set<String> excludeIds = const <String>{},
    int limit = 8,
  }) async {
    final snapshot = await _communities
        .orderBy('memberCount', descending: true)
        .limit(40)
        .get();
    return snapshot.docs
        .map(Community.fromDoc)
        .where((community) => !excludeIds.contains(community.id))
        .take(limit)
        .toList();
  }

  Future<MembershipStatus> fetchMembershipStatus(String communityId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return MembershipStatus.none;
    final doc = await _members.doc(memberDocId(communityId, user.uid)).get();
    if (!doc.exists) return MembershipStatus.none;
    return doc.data()?['status'] == 'active'
        ? MembershipStatus.active
        : MembershipStatus.pending;
  }

  /// เข้าร่วมชุมชน: แบบเปิดเป็นสมาชิกทันที (+1 จำนวนสมาชิก)
  /// แบบต้องอนุมัติจะเป็นแค่ "คำขอ" (pending) รอเจ้าของชุมชนกดยอมรับก่อน
  Future<void> joinCommunity(Community community) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final username = await _myUsername(user);
    final isOpen = !community.requiresApproval;

    final batch = _db.batch();
    batch.set(_members.doc(memberDocId(community.id, user.uid)), {
      'communityId': community.id,
      'uid': user.uid,
      'username': username,
      'ownerId': community.ownerId,
      'role': 'member',
      'status': isOpen ? 'active' : 'pending',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    if (isOpen) {
      batch.update(_communities.doc(community.id), {
        'memberCount': FieldValue.increment(1),
      });
    }
    await batch.commit();
  }

  /// ออกจากชุมชน หรือยกเลิกคำขอที่ส่งไป ([wasActive] = เคยเป็นสมาชิกจริง
  /// ถึงจะลดจำนวนสมาชิก ถ้าเป็นแค่คำขอค้างอยู่ไม่ต้องลด)
  Future<void> leaveCommunity(
    String communityId, {
    required bool wasActive,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    final batch = _db.batch();
    batch.delete(_members.doc(memberDocId(communityId, user.uid)));
    if (wasActive) {
      batch.update(_communities.doc(communityId), {
        'memberCount': FieldValue.increment(-1),
      });
    }
    await batch.commit();
  }

  /// คำขอเข้าร่วมที่รออนุมัติ (ใช้ได้เฉพาะเจ้าของชุมชน)
  Future<List<CommunityMember>> fetchPendingRequests(
    String communityId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    // กรอง status ฝั่ง client เพื่อไม่ต้องสร้าง composite index เพิ่ม
    final snap = await _members
        .where('communityId', isEqualTo: communityId)
        .where('ownerId', isEqualTo: user.uid)
        .get();
    return snap.docs
        .map(CommunityMember.fromDoc)
        .where((m) => m.status == 'pending')
        .toList();
  }

  /// Live count of pending join requests across communities owned by this user.
  Stream<int> pendingRequestsCountForOwnerStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream<int>.value(0);

    return _members
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length);
  }

  /// Live count of pending requests for one owned community.
  Stream<int> pendingRequestsCountStream(String communityId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream<int>.value(0);

    return _members
        .where('communityId', isEqualTo: communityId)
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => doc.data()['status'] == 'pending')
            .length);
  }

  /// Active members only; pending join requests are never included.
  Future<List<CommunityMember>> fetchActiveMembers(String communityId) async {
    final snap = await _members
        .where('communityId', isEqualTo: communityId)
        .where('status', isEqualTo: 'active')
        .get();
    final members = snap.docs.map(CommunityMember.fromDoc).toList();
    members.sort(
      (a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()),
    );
    return members;
  }

  Future<void> approveRequest(String communityId, String memberUid) async {
    final batch = _db.batch();
    batch.update(_members.doc(memberDocId(communityId, memberUid)), {
      'status': 'active',
    });
    batch.update(_communities.doc(communityId), {
      'memberCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> declineRequest(String communityId, String memberUid) {
    return _members.doc(memberDocId(communityId, memberUid)).delete();
  }

  /// โพสต์ทั้งหมดในชุมชน เรียงใหม่สุดก่อน (เรียงฝั่ง client เลี่ยง index)
  Future<List<Post>> fetchCommunityPosts(String communityId) async {
    final snap = await _posts.where('communityId', isEqualTo: communityId).get();
    final posts = snap.docs.map(Post.fromDoc).toList();
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  /// กรองโพสต์ให้เหลือเฉพาะที่เราเห็นได้: โพสต์ทั่วไป (ไม่อยู่ในชุมชน),
  /// โพสต์ของตัวเอง, หรือโพสต์ในชุมชนที่เราเป็นสมาชิกอยู่
  static List<Post> filterVisible(List<Post> posts, Set<String> myCommunityIds) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return posts
        .where(
          (p) =>
              p.communityId == null ||
              p.authorId == myUid ||
              myCommunityIds.contains(p.communityId),
        )
        .toList();
  }
}
