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
    this.downvoteCount = 0,
    this.reactionCounts = const {},
    this.imageBase64,
    this.videoUrl,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String title;
  final String body;
  final DateTime createdAt;
  final int upvoteCount;
  final int downvoteCount;
  final int commentCount;
  final Map<String, int> reactionCounts; // เช่น {'❤️': 3, '😂': 1}
  final String? imageBase64; // รูปภาพ: เก็บเป็น Base64 ฝังในเอกสารนี้เลย
  final String? videoUrl; // วิดีโอ: ไฟล์ใหญ่เกินจะฝัง จึงอัปโหลดขึ้น
  // Cloudinary แล้วเก็บแค่ลิงก์ไว้ตรงนี้แทน (โพสต์หนึ่งมีได้แค่รูปหรือ
  // วิดีโออย่างใดอย่างหนึ่ง ไม่ใช่ทั้งคู่พร้อมกัน)

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
      downvoteCount: data['downvoteCount'] as int? ?? 0,
      commentCount: data['commentCount'] as int? ?? 0,
      reactionCounts: Map<String, int>.from(
        (data['reactionCounts'] as Map?)?.map(
              (key, value) => MapEntry(key as String, value as int? ?? 0),
            ) ??
            const {},
      ),
      imageBase64: data['imageBase64'] as String?,
      videoUrl: data['videoUrl'] as String?,
    );
  }
}