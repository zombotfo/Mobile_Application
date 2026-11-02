import 'package:cloud_firestore/cloud_firestore.dart';

/// สถานะของเราในชุมชนหนึ่งๆ
enum MembershipStatus {
  none, // ยังไม่ได้เข้าร่วม
  pending, // ส่งคำขอแล้ว รอเจ้าของชุมชนอนุมัติ
  active, // เป็นสมาชิกแล้ว (รวมเจ้าของชุมชนด้วย)
}

class Community {
  const Community({
    required this.id,
    required this.name,
    required this.joinType,
    required this.ownerId,
    required this.ownerUsername,
    required this.memberCount,
    this.imageBase64,
  });

  /// ชื่อชุมชนแบบตัวพิมพ์เล็ก ใช้เป็น document id (ทำให้ชื่อไม่ซ้ำกันเหมือน r/ ใน Reddit)
  final String id;
  final String name;
  final String joinType; // 'open' = ใครเข้าก็ได้ | 'approval' = ต้องได้รับอนุมัติ
  final String ownerId;
  final String ownerUsername;
  final int memberCount;
  final String? imageBase64;

  bool get requiresApproval => joinType == 'approval';

  factory Community.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Community(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      joinType: data['joinType'] as String? ?? 'open',
      ownerId: data['ownerId'] as String? ?? '',
      ownerUsername: data['ownerUsername'] as String? ?? '',
      memberCount: data['memberCount'] as int? ?? 0,
      imageBase64: data['imageBase64'] as String?,
    );
  }
}

/// สมาชิก/คำขอเข้าร่วมหนึ่งรายการ (ใช้ในหน้าอนุมัติคำขอของเจ้าของชุมชน)
class CommunityMember {
  const CommunityMember({
    required this.uid,
    required this.username,
    required this.status,
  });

  final String uid;
  final String username;
  final String status; // 'pending' | 'active'

  factory CommunityMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return CommunityMember(
      uid: data['uid'] as String? ?? '',
      username: data['username'] as String? ?? 'unknown',
      status: data['status'] as String? ?? 'pending',
    );
  }
}
