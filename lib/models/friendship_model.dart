import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus {
  none, // ไม่มีความสัมพันธ์ใดๆ
  requestSent, // เราส่งคำขอไปแล้ว รออีกฝ่ายตอบรับ
  requestReceived, // อีกฝ่ายส่งคำขอมา รอเรายอมรับ
  friends, // เป็นเพื่อนกันแล้ว
}

class Friendship {
  const Friendship({
    required this.id,
    required this.otherUid,
    required this.otherUsername,
    required this.status,
    required this.requestedBy,
    required this.createdAt,
  });

  final String id;
  final String otherUid;
  final String otherUsername;
  final String status; // 'pending' | 'accepted'
  final String requestedBy;
  final DateTime createdAt;

  factory Friendship.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String myUid,
  ) {
    final data = doc.data() ?? const {};
    final participants = List<String>.from(
      data['participants'] as List? ?? const [],
    );
    final usernames = Map<String, dynamic>.from(
      data['usernames'] as Map? ?? const {},
    );
    final otherUid = participants.firstWhere(
      (id) => id != myUid,
      orElse: () => '',
    );

    return Friendship(
      id: doc.id,
      otherUid: otherUid,
      otherUsername: usernames[otherUid] as String? ?? 'unknown',
      status: data['status'] as String? ?? 'pending',
      requestedBy: data['requestedBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
