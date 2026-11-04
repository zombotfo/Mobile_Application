import 'package:flutter_test/flutter_test.dart';
import 'package:app_project/models/app_user_model.dart';
import 'package:app_project/models/chat_message_model.dart';
import 'package:app_project/models/chat_model.dart';
import 'package:app_project/models/comment_model.dart';
import 'package:app_project/models/post_model.dart';
import 'package:app_project/utils/time_ago.dart';

void main() {
  group('timeAgo', () {
    test('returns just now for a time less than one minute ago', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(seconds: 30))), 'เมื่อสักครู่');
    });

    test('returns minutes for a time less than one hour ago', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(minutes: 5))), '5 นาทีที่แล้ว');
    });

    test('returns hours for a time less than one day ago', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(hours: 3))), '3 ชั่วโมงที่แล้ว');
    });

    test('returns days for a time less than 30 days ago', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(days: 2))), '2 วันที่แล้ว');
    });

    test('returns months for a time less than 365 days ago', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(days: 60))), '2 เดือนที่แล้ว');
    });

    test('returns years for a time at least 365 days ago', () {
      expect(timeAgo(DateTime.now().subtract(const Duration(days: 730))), '2 ปีที่แล้ว');
    });
  });

  group('model constructors', () {
    test('AppUser stores uid and username', () {
      const user = AppUser(uid: 'u1', username: 'alice');
      expect(user.uid, 'u1');
      expect(user.username, 'alice');
    });

    test('Post stores required fields and default optional values', () {
      final createdAt = DateTime(2025, 1, 2);
      final post = Post(
        id: 'p1', authorId: 'u1', authorUsername: 'alice', title: 'Title',
        body: 'Body', createdAt: createdAt, upvoteCount: 4, commentCount: 2,
      );
      expect(post.id, 'p1');
      expect(post.createdAt, createdAt);
      expect(post.downvoteCount, 0);
      expect(post.reactionCounts, isEmpty);
      expect(post.imageBase64, isNull);
      expect(post.videoUrl, isNull);
    });

    test('Comment stores its text and author', () {
      final comment = Comment(
        id: 'c1', authorId: 'u2', authorUsername: 'bob', text: 'Nice!',
        createdAt: DateTime(2025, 1, 2),
      );
      expect(comment.text, 'Nice!');
      expect(comment.authorUsername, 'bob');
    });

    test('ChatSummary stores conversation fields', () {
      final date = DateTime(2025, 1, 2);
      final chat = ChatSummary(
        id: 'chat1', otherUserId: 'u2', otherUsername: 'bob',
        lastMessage: 'Hello', lastMessageAt: date, lastSenderId: 'u1',
      );
      expect(chat.otherUserId, 'u2');
      expect(chat.lastMessageAt, date);
      expect(chat.lastSenderId, 'u1');
    });

    test('ChatMessage stores sender, text, and sent time', () {
      final date = DateTime(2025, 1, 2);
      final message = ChatMessage(id: 'm1', senderId: 'u1', text: 'Hi', sentAt: date);
      expect(message.id, 'm1');
      expect(message.senderId, 'u1');
      expect(message.text, 'Hi');
      expect(message.sentAt, date);
    });
  });
}
/// ทดสอบพฤติกรรมพื้นฐานของแอป
