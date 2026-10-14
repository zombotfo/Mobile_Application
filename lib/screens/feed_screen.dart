import 'dart:async';

import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../services/firestore_service.dart';
import '../widgets/post_card.dart';

/// รายการโพสต์ทั้งหมด กรองด้วย [searchQuery] (ค้นจากหัวข้อโพสต์) ถ้ามีการพิมพ์ค้นหา
///
/// ไม่ใช้ real-time listener แล้ว — ดึงข้อมูลใหม่ทุก 1 นาทีแทน (poll)
/// ส่วนคนที่เพิ่งทำรายการเอง (เช่นสร้างโพสต์ใหม่) จะถูกสั่งรีเฟรชทันที
/// ผ่าน GlobalKey<FeedScreenState> จากภายนอก (ดู home_screen.dart)
/// ผู้ใช้คนอื่นที่ไม่ได้ทำอะไร จะเห็นการเปลี่ยนแปลงเมื่อครบรอบ 1 นาที
/// หรือลากหน้าจอลงเพื่อรีเฟรชเองก่อนก็ได้ (pull-to-refresh)
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  final _firestoreService = FirestoreService();
  Timer? _pollTimer;

  List<Post>? _posts;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final posts = await _firestoreService.fetchPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _hasError = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  /// เรียกจากภายนอกผ่าน GlobalKey ได้ เช่นตอนสร้างโพสต์ใหม่สำเร็จ
  /// อยากเห็นผลทันทีโดยไม่ต้องรอครบ 1 นาที
  Future<void> refreshNow() => _refresh();

  /// อัปเดต/ลบโพสต์ในลิสต์ที่ถืออยู่ทันที (ไม่ต้องรอ fetch ใหม่ทั้งหมด)
  /// ใช้ตอนผู้ใช้คนนี้เองแก้ไขหรือลบโพสต์ของตัวเองสำเร็จ
  void replacePostLocally(Post updated) {
    setState(() {
      _posts = _posts?.map((p) => p.id == updated.id ? updated : p).toList();
    });
  }

  void removePostLocally(String postId) {
    setState(() {
      _posts = _posts?.where((p) => p.id != postId).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('โหลดโพสต์ไม่สำเร็จ'),
            TextButton(onPressed: _refresh, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    var posts = _posts ?? [];
    final query = widget.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      posts =
          posts.where((p) => p.title.toLowerCase().contains(query)).toList();
    }

    if (posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                query.isNotEmpty
                    ? 'ไม่พบโพสต์ที่ตรงกับ "${widget.searchQuery}"'
                    : 'ยังไม่มีโพสต์ในชุมชนนี้\nเป็นคนแรกที่โพสต์เลยสิ!\n\n(ลากลงเพื่อรีเฟรช)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        key: const PageStorageKey('feed-list'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return PostCard(
            key: ValueKey(post.id),
            post: post,
            onUpdated: replacePostLocally,
            onDeleted: () => removePostLocally(post.id),
          );
        },
      ),
    );
  }
}