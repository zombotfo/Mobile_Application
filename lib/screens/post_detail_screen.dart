import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../services/firestore_service.dart';
import '../utils/time_ago.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _firestoreService = FirestoreService();
  final _commentController = TextEditingController();
  final _myUid = FirebaseAuth.instance.currentUser?.uid;

  late Post _post = widget.post;
  late final Stream<List<Comment>> _commentsStream =
      _firestoreService.commentsStream(widget.post.id);
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text;
    if (text.trim().isEmpty || _sending) return;

    setState(() => _sending = true);
    _commentController.clear();
    try {
      await _firestoreService.addComment(postId: _post.id, text: text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('แสดงความคิดเห็นไม่สำเร็จ ลองใหม่อีกครั้ง'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDeleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบความคิดเห็น'),
        content: const Text('ต้องการลบความคิดเห็นนี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _firestoreService.deleteComment(
        postId: _post.id,
        commentId: comment.id,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('โพสต์')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                PostCard(
                  post: _post,
                  inDetailView: true,
                  onUpdated: (updated) => setState(() => _post = updated),
                  onDeleted: () => Navigator.of(context).pop(),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    'ความคิดเห็น',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                StreamBuilder<List<Comment>>(
                  stream: _commentsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('โหลดความคิดเห็นไม่สำเร็จ'),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final comments = snapshot.data!;
                    if (comments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'ยังไม่มีความคิดเห็น เป็นคนแรกเลยสิ!',
                            style: TextStyle(color: Colors.black45),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: comments.map((c) {
                        final isOwner = c.authorId == _myUid;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text(
                              c.authorUsername.isNotEmpty
                                  ? c.authorUsername[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(
                            'u/${c.authorUsername}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(c.text),
                          ),
                          trailing: isOwner
                              ? IconButton(
                                  tooltip: 'ลบความคิดเห็น',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.black38,
                                  ),
                                  onPressed: () => _confirmDeleteComment(c),
                                )
                              : Text(
                                  timeAgo(c.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black38,
                                  ),
                                ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                      decoration: const InputDecoration(
                        hintText: 'แสดงความคิดเห็น...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Color(0xFFF0F0F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _sendComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
