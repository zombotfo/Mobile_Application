import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.upvoteCount,
    required this.commentCount,
    this.imageBase64,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String title;
  final String body;
  final DateTime createdAt;
  final int upvoteCount;
  final int commentCount;
  final String? imageBase64;

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Post(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorUsername: data['authorUsername'] as String? ?? 'unknown',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      // ตอนเพิ่งสร้างโพสต์ serverTimestamp ยังไม่ถูกเขียนกลับมาทันที
      // (เป็น null ชั่วขณะ) จึง fallback เป็นเวลาปัจจุบันเพื่อกันแอป crash
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      upvoteCount: data['upvoteCount'] as int? ?? 0,
      commentCount: data['commentCount'] as int? ?? 0,
      imageBase64: data['imageBase64'] as String?,
    );
  }
}