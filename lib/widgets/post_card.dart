import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../screens/chat_detail_screen.dart';
import '../screens/edit_post_screen.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../services/friend_service.dart';
import '../utils/time_ago.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onUpdated,
    this.onDeleted,
  });

  final Post post;

  /// เรียกตอนแก้ไขโพสต์สำเร็จ ส่งโพสต์เวอร์ชันใหม่กลับไป ให้ฟีดอัปเดต
  /// การ์ดนี้ทันทีโดยไม่ต้องรอรอบ poll ถัดไป
  final ValueChanged<Post>? onUpdated;

  /// เรียกตอนลบโพสต์สำเร็จ ให้ฟีดเอาการ์ดนี้ออกจากจอทันที
  final VoidCallback? onDeleted;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _firestoreService = FirestoreService();
  final _friendService = FriendService();
  final _chatService = ChatService();

  // สร้าง stream เช็คสถานะโหวตแค่ครั้งเดียวตอนการ์ดถูกสร้าง (late final)
  // ไม่ใช่ทุกครั้งที่ build() — ถ้าสร้างใหม่ทุกครั้งที่ list rebuild (เช่น
  // ตอนโพสต์อื่นถูกโหวต ทำให้ทั้ง list สร้างใหม่) ไอคอนโหวตของทุกการ์ดจะ
  // กระพริบ reset ไปพร้อมกันหมด แม้จะไม่ได้โหวตโพสต์นั้นก็ตาม
  late final Stream<bool> _hasUpvotedStream =
      _firestoreService.hasUpvotedStream(widget.post.id);

  // สถานะเพื่อน เก็บเป็น field ธรรมดา (ไม่ใช่ StreamBuilder) เพราะต้องใช้
  // ตอนสร้างรายการเมนู "..." ซึ่งเป็นฟังก์ชัน sync ไม่สามารถ await ได้
  bool _isFriend = false;
  StreamSubscription<bool>? _friendSub;

  bool get _isOwner =>
      widget.post.authorId == FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (!_isOwner) {
      _friendSub = _friendService
          .isFriendStream(widget.post.authorId)
          .listen((value) {
        if (mounted) setState(() => _isFriend = value);
      });
    }
  }

  @override
  void dispose() {
    _friendSub?.cancel();
    super.dispose();
  }

  Future<void> _handleUpvote() async {
    try {
      await _firestoreService.toggleUpvote(widget.post.id);
    } catch (_) {
      // เช่น rules ปฏิเสธ หรือเน็ตหลุด กันไม่ให้ error เงียบๆ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('โหวตไม่สำเร็จ ลองใหม่อีกครั้ง')),
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

  Future<void> _toggleFriend(bool isFriend) async {
    try {
      if (isFriend) {
        await _friendService.removeFriend(widget.post.authorId);
      } else {
        await _friendService.addFriend(
          friendUid: widget.post.authorId,
          friendUsername: widget.post.authorUsername,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFriend ? 'ลบออกจากเพื่อนแล้ว' : 'เพิ่มเป็นเพื่อนแล้ว'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
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
                CircleAvatar(
                  radius: 11,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    post.authorUsername.isNotEmpty
                        ? post.authorUsername[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'u/${post.authorUsername} · ${timeAgo(post.createdAt)}',
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
                      case 'friend_add':
                        _toggleFriend(false);
                        break;
                      case 'friend_remove':
                        _toggleFriend(true);
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
                            value: 'message',
                            child: Text('ส่งข้อความ'),
                          ),
                          PopupMenuItem(
                            value: _isFriend ? 'friend_remove' : 'friend_add',
                            child: Text(_isFriend ? 'ลบเพื่อน' : 'เพิ่มเพื่อน'),
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
            if (post.imageBase64 != null) ...[
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
            Row(
              children: [
                StreamBuilder<bool>(
                  stream: _hasUpvotedStream,
                  builder: (context, snapshot) {
                    final hasUpvoted = snapshot.data ?? false;
                    final color = hasUpvoted
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black54;
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _handleUpvote,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasUpvoted
                                  ? Icons.arrow_circle_up
                                  : Icons.arrow_circle_up_outlined,
                              size: 20,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.upvoteCount}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
