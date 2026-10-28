import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../screens/chat_detail_screen.dart';
import '../screens/edit_post_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../utils/time_ago.dart';
import 'post_video_player.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onUpdated,
    this.onDeleted,
    this.inDetailView = false,
  });

  final Post post;

  /// เรียกตอนแก้ไขโพสต์สำเร็จ ส่งโพสต์เวอร์ชันใหม่กลับไป ให้ฟีดอัปเดต
  /// การ์ดนี้ทันทีโดยไม่ต้องรอรอบ poll ถัดไป
  final ValueChanged<Post>? onUpdated;

  /// เรียกตอนลบโพสต์สำเร็จ ให้ฟีดเอาการ์ดนี้ออกจากจอทันที
  final VoidCallback? onDeleted;

  /// true เมื่อการ์ดนี้แสดงอยู่ใน PostDetailScreen อยู่แล้ว — ปิดการแตะแถว
  /// คอมเมนต์เพื่อเปิดหน้ารายละเอียดซ้ำซ้อน (เปิดหน้าตัวเองซ้อนตัวเอง)
  final bool inDetailView;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _firestoreService = FirestoreService();
  final _chatService = ChatService();

  // สร้าง stream เช็คสถานะโหวต/reaction แค่ครั้งเดียวตอนการ์ดถูกสร้าง
  // (late final) ไม่ใช่ทุกครั้งที่ build() — ถ้าสร้างใหม่ทุกครั้งที่ list
  // rebuild (เช่นตอนโพสต์อื่นถูกโหวต ทำให้ทั้ง list สร้างใหม่) ไอคอนของ
  // ทุกการ์ดจะกระพริบ reset ไปพร้อมกันหมด แม้จะไม่ได้โหวต/react โพสต์นั้น
  late final Stream<int?> _voteValueStream =
      _firestoreService.voteValueStream(widget.post.id);
  late final Stream<String?> _myReactionStream =
      _firestoreService.myReactionStream(widget.post.id);

  // ดึงรูปโปรไฟล์ของเจ้าของโพสต์แค่ครั้งเดียว (late final) ไม่ fetch ซ้ำ
  // ทุกครั้งที่การ์ด rebuild (เช่นตอนมีคนโหวต ทำให้ทั้ง list สร้างใหม่)
  late final Future<String?> _authorPhotoFuture =
      _firestoreService.fetchUserPhotoBase64(widget.post.authorId);

  bool get _isOwner =>
      widget.post.authorId == FirebaseAuth.instance.currentUser?.uid;

  void _openAuthorProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(uid: widget.post.authorId),
      ),
    );
  }

  Future<void> _handleVote(int value) async {
    try {
      await _firestoreService.setVote(widget.post.id, value);
    } catch (_) {
      // เช่น rules ปฏิเสธ หรือเน็ตหลุด กันไม่ให้ error เงียบๆ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('โหวตไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    }
  }

  Future<void> _handleReaction(String emoji) async {
    try {
      await _firestoreService.setReaction(widget.post.id, emoji);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<Post>(
      MaterialPageRoute(builder: (_) => EditPostScreen(post: widget.post)),
    );
    if (updated != null) widget.onUpdated?.call(updated);
  }

  void _openDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post)),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบโพสต์'),
        content: const Text('ต้องการลบโพสต์นี้ถาวรหรือไม่?'),
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
      await _firestoreService.deletePost(widget.post.id);
      widget.onDeleted?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    }
  }

  Future<void> _openChatWithAuthor() async {
    try {
      final chatId = await _chatService.startChat(
        otherUid: widget.post.authorId,
        otherUsername: widget.post.authorUsername,
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatId: chatId,
              otherUsername: widget.post.authorUsername,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปิดแชทไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    }
  }

  Future<void> _openReportDialog() async {
    const reasons = [
      'สแปมหรือโฆษณา',
      'เนื้อหาไม่เหมาะสม',
      'คุกคาม/กลั่นแกล้ง',
      'ข้อมูลเท็จ',
      'อื่นๆ',
    ];
    var selected = reasons.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('รายงานโพสต์'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map(
                  (r) => RadioListTile<String>(
                    title: Text(r),
                    value: r,
                    groupValue: selected,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setDialogState(() => selected = v!),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ส่งรายงาน'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await _firestoreService.reportPost(widget.post.id, reason: selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งรายงานแล้ว ขอบคุณที่ช่วยตรวจสอบ')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งรายงานไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _openAuthorProfile,
                  child: Row(
                    children: [
                      FutureBuilder<String?>(
                        future: _authorPhotoFuture,
                        builder: (context, snapshot) {
                          final photo = snapshot.data;
                          return CircleAvatar(
                            radius: 11,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            backgroundImage: photo != null
                                ? MemoryImage(base64Decode(photo))
                                : null,
                            child: photo == null
                                ? Text(
                                    post.authorUsername.isNotEmpty
                                        ? post.authorUsername[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'u/${post.authorUsername}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '· ${timeAgo(post.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // เมนู "..." : เจ้าของเห็นแก้ไข/ลบ คนอื่นเห็นแค่รายงาน
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: 'ตัวเลือกเพิ่มเติม',
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: Colors.black45,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _openEdit();
                        break;
                      case 'delete':
                        _confirmDelete();
                        break;
                      case 'message':
                        _openChatWithAuthor();
                        break;
                      case 'profile':
                        _openAuthorProfile();
                        break;
                      case 'report':
                        _openReportDialog();
                        break;
                    }
                  },
                  itemBuilder: (context) => _isOwner
                      ? const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('แก้ไขโพสต์'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'ลบโพสต์',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ]
                      : [
                          const PopupMenuItem(
                            value: 'profile',
                            child: Text('ดูโปรไฟล์'),
                          ),
                          const PopupMenuItem(
                            value: 'message',
                            child: Text('ส่งข้อความ'),
                          ),
                          const PopupMenuItem(
                            value: 'report',
                            child: Text('รายงานโพสต์'),
                          ),
                        ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (post.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                post.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
            if (post.videoUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PostVideoPlayer(videoUrl: post.videoUrl!),
              ),
            ] else if (post.imageBase64 != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Builder(
                    builder: (context) {
                      try {
                        final bytes = base64Decode(post.imageBase64!);
                        return Image.memory(
                          bytes,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        );
                      } catch (_) {
                        return Container(
                          height: 140,
                          color: const Color(0xFFF0F0F1),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.black26,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // แถวอิโมจิ react (เลือกได้ 1 อิโมจิต่อคนต่อโพสต์ แยกจากปุ่ม
            // ถูกใจ/ไม่ถูกใจด้านล่าง)
            StreamBuilder<String?>(
              stream: _myReactionStream,
              builder: (context, snapshot) {
                final myReaction = snapshot.data;
                return Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: FirestoreService.reactionEmojis.map((emoji) {
                    final count = post.reactionCounts[emoji] ?? 0;
                    final selected = myReaction == emoji;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _handleReaction(emoji),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.12)
                              : const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(16),
                          border: selected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 14)),
                            if (count > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                StreamBuilder<int?>(
                  stream: _voteValueStream,
                  builder: (context, snapshot) {
                    final myVote = snapshot.data;
                    final upColor = myVote == 1
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black54;
                    final downColor = myVote == -1
                        ? Colors.red
                        : Colors.black54;
                    return Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _handleVote(1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  myVote == 1
                                      ? Icons.arrow_circle_up
                                      : Icons.arrow_circle_up_outlined,
                                  size: 20,
                                  color: upColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${post.upvoteCount}',
                                  style: TextStyle(
                                    color: upColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _handleVote(-1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  myVote == -1
                                      ? Icons.arrow_circle_down
                                      : Icons.arrow_circle_down_outlined,
                                  size: 20,
                                  color: downColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${post.downvoteCount}',
                                  style: TextStyle(
                                    color: downColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: widget.inDetailView ? null : _openDetail,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mode_comment_outlined,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.commentCount} ความคิดเห็น',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
