import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
  });

  final String id;
  final String otherUserId;
  final String otherUsername;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastSenderId;

  /// [currentUid] ใช้หาว่า "อีกฝ่าย" ในห้องแชทนี้คือใคร (ไม่ใช่ตัวเอง)
  factory ChatSummary.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String currentUid,
  ) {
    final data = doc.data() ?? const {};
    final participants = List<String>.from(
      data['participants'] as List? ?? const [],
    );
    final usernames = Map<String, dynamic>.from(
      data['participantUsernames'] as Map? ?? const {},
    );
    final otherUid = participants.firstWhere(
      (id) => id != currentUid,
      orElse: () => '',
    );

    return ChatSummary(
      id: doc.id,
      otherUserId: otherUid,
      otherUsername: usernames[otherUid] as String? ?? 'unknown',
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSenderId: data['lastSenderId'] as String? ?? '',
    );
  }
}
