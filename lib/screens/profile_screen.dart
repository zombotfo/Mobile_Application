import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/friendship_model.dart';
import '../models/post_model.dart';
import '../services/chat_service.dart';
import '../services/community_service.dart';
import '../services/firestore_service.dart';
import '../services/follow_service.dart';
import '../services/friend_service.dart';
import '../widgets/follow_action_button.dart';
import '../widgets/friend_action_button.dart';
import '../widgets/post_card.dart';
import 'chat_detail_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestoreService = FirestoreService();
  final _followService = FollowService();
  final _friendService = FriendService();
  final _chatService = ChatService();

  bool get _isMe => widget.uid == FirebaseAuth.instance.currentUser?.uid;

  // เห็นเนื้อหา (โพสต์/สถิติ) ได้เมื่อ: เป็นโปรไฟล์ตัวเอง, หรือบัญชีนั้น
  // ไม่ได้ตั้งเป็นส่วนตัว, หรือเราเป็นเพื่อนกับเจ้าของบัญชีแล้ว
  bool get _canViewContent => _isMe || !_isPrivate || _isFriend;

  bool _loading = true;
  bool _hasError = false;
  String _username = '';
  String? _photoBase64;
  bool _isPrivate = false;
  bool _isFriend = false;
  List<Post> _posts = [];
  int _totalUpvotes = 0;
  int _totalDownvotes = 0;
  int _followerCount = 0;
  int _friendCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final profileResults = await Future.wait([
        _firestoreService.fetchUserProfile(widget.uid),
        _followService.fetchFollowerCount(widget.uid),
        _isMe
            ? Future.value(FriendshipStatus.none)
            : _friendService.friendshipStatusStream(widget.uid).first,
      ]);

      final profile = profileResults[0] as Map<String, dynamic>?;
      final followerCount = profileResults[1] as int;
      final friendshipStatus = profileResults[2] as FriendshipStatus;

      final isPrivate = profile?['isPrivate'] as bool? ?? false;
      final isFriend = friendshipStatus == FriendshipStatus.friends;
      final canView = _isMe || !isPrivate || isFriend;

      // ไม่ดึงโพสต์เลยถ้าดูเนื้อหาไม่ได้ (บัญชี private ที่ไม่ใช่เพื่อน)
      // ลดการอ่านข้อมูลที่ใช้งานไม่ได้อยู่ดี
      var posts =
          canView ? await _firestoreService.fetchPostsByAuthor(widget.uid) : <Post>[];

      // โพสต์ในชุมชนที่เราไม่ได้เป็นสมาชิก ไม่โชว์ในโปรไฟล์คนอื่นด้วย
      // (โปรไฟล์ตัวเองเห็นครบ เพราะ filterVisible ยกเว้นโพสต์ของตัวเองให้)
      if (canView && !_isMe && posts.any((p) => p.communityId != null)) {
        Set<String> myCommunityIds;
        try {
          myCommunityIds = await CommunityService().fetchMyActiveCommunityIds();
        } catch (_) {
          myCommunityIds = <String>{};
        }
        posts = CommunityService.filterVisible(posts, myCommunityIds);
      }

      if (!mounted) return;
      setState(() {
        _username = profile?['username'] as String? ?? 'unknown';
        _photoBase64 = profile?['photoBase64'] as String?;
        _isPrivate = isPrivate;
        _isFriend = isFriend;
        _posts = posts;
        _totalUpvotes = posts.fold<int>(0, (sum, p) => sum + p.upvoteCount);
        _totalDownvotes = posts.fold<int>(0, (sum, p) => sum + p.downvoteCount);
        _followerCount = followerCount;
        // friendCount เก็บเป็นตัวเลขสะสมในโปรไฟล์โดยตรง (ไม่ query friendships
        // สดแบบ follower เพราะอ่านเอกสารมิตรภาพของคนอื่นที่เราไม่ใช่คู่สัญญา
        // ไม่ได้ตาม rules — อัปเดตค่านี้ตอนยอมรับ/เลิกเป็นเพื่อนใน friend_service.dart)
        _friendCount = profile?['friendCount'] as int? ?? 0;
        _loading = false;
      });
    } catch (e) {
      // ชั่วคราว: พิมพ์ error จริงออกมาดูใน Debug Console ก่อน ว่าสาเหตุคืออะไร
      // (ลบบรรทัด print นี้ทิ้งได้หลังจากหาสาเหตุเจอแล้ว)
      debugPrint('ProfileScreen._load error: $e');
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    _load();
  }

  Future<void> _openChat() async {
    try {
      final chatId = await _chatService.startChat(
        otherUid: widget.uid,
        otherUsername: _username,
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ChatDetailScreen(chatId: chatId, otherUsername: _username),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('โหลดโปรไฟล์ไม่สำเร็จ'),
              const SizedBox(height: 4),
              const Text(
                '(อาจต้องสร้าง Firestore index ให้ query นี้ก่อน)',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
              TextButton(onPressed: _load, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('u/$_username')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            if (!_canViewContent)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 40, color: Colors.black26),
                      SizedBox(height: 10),
                      Text(
                        'บัญชีนี้เป็นส่วนตัว',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'เป็นเพื่อนกันก่อนถึงจะเห็นโพสต์ของบัญชีนี้ได้',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  'โพสต์ (${_posts.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'ยังไม่มีโพสต์',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ),
                )
              else
                ..._posts.map((post) => PostCard(key: ValueKey(post.id), post: post)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: colors.primary,
            backgroundImage:
                _photoBase64 != null ? MemoryImage(base64Decode(_photoBase64!)) : null,
            child: _photoBase64 == null
                ? Text(
                    _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'u/$_username',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (_isPrivate && !_isMe) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock_outline, size: 16, color: Colors.black45),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (_canViewContent)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(label: 'ถูกใจ', value: _totalUpvotes),
                _StatItem(label: 'ไม่ถูกใจ', value: _totalDownvotes),
                _StatItem(label: 'ผู้ติดตาม', value: _followerCount),
                _StatItem(label: 'เพื่อน', value: _friendCount),
              ],
            ),
          const SizedBox(height: 16),
          if (_isMe)
            OutlinedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('แก้ไขโปรไฟล์'),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FriendActionButton(uid: widget.uid, username: _username),
                FollowActionButton(uid: widget.uid, username: _username),
                // บัญชี private ที่ยังไม่ใช่เพื่อนกัน ซ่อนปุ่มแชทไปเลย
                // (ยังกดส่งคำขอเป็นเพื่อนได้ตามปกติ แค่แชทไม่ได้จนกว่าจะรับคำขอ)
                if (!_isPrivate || _isFriend)
                  OutlinedButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('แชท'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}