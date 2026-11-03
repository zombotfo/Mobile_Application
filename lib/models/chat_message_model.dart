import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.mediaUrl,
    this.mediaBase64,
    this.mediaType,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final String? mediaUrl;
  final String? mediaBase64;
  final String? mediaType;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mediaUrl: data['mediaUrl'] as String?,
      mediaBase64: data['mediaBase64'] as String?,
      mediaType: data['mediaType'] as String?,
    );
  }
}
