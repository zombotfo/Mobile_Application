import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  const Comment({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String text;
  final DateTime createdAt;

  factory Comment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Comment(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorUsername: data['authorUsername'] as String? ?? 'unknown',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
