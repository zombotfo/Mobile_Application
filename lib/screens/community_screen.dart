import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/community_model.dart';
import '../models/post_model.dart';
import '../services/block_service.dart';
import '../services/community_service.dart';
import '../widgets/community_avatar.dart';
import '../widgets/notification_dot.dart';
import '../widgets/post_card.dart';
import 'community_requests_screen.dart';
import 'community_members_screen.dart';
import 'create_post_screen.dart';

/// หน้าชุมชน: ข้อมูลชุมชน ปุ่มเข้าร่วม/ออก และโพสต์ในชุมชน
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, required this.communityId});

  final String communityId;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _service = CommunityService();
  final _blockService = BlockService();
  late final Stream<int> _pendingRequestCountStream =
      _service.pendingRequestsCountStream(widget.communityId);

  bool _loading = true;
  bool _hasError = false;
  bool _working = false;
  Community? _community;
  MembershipStatus _status = MembershipStatus.none;
  List<Post> _posts = [];

  bool get _isOwner =>
      _community?.ownerId == FirebaseAuth.instance.currentUser?.uid;

  // ชุมชนแบบเปิด ใครก็ดูโพสต์ได้ / ชุมชนแบบต้องอนุมัติ ดูได้เฉพาะสมาชิก
  bool get _canViewPosts =>
      _community != null &&
      (!_community!.requiresApproval || _status == MembershipStatus.active);

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
      final community = await _service.fetchCommunity(widget.communityId);
      if (community == null) {
        if (mounted) setState(() { _community = null; _loading = false; });
        return;
      }
      final status = await _service.fetchMembershipStatus(widget.communityId);
      final canView =
          !community.requiresApproval || status == MembershipStatus.active;
      var posts = canView
          ? await _service.fetchCommunityPosts(widget.communityId)
          : <Post>[];
      if (canView) {
        final blockedIds = await _blockService.fetchBlockedUserIds();
        posts = posts
            .where((post) => !blockedIds.contains(post.authorId))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _community = community;
        _status = status;
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      debugPrint('CommunityScreen._load error: $e');
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากชุมชน'),
        content: Text('ต้องการออกจาก r/${_community!.name} หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออก', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _run(
      () => _service.leaveCommunity(
        widget.communityId,
        wasActive: _status == MembershipStatus.active,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบชุมชนนี้?'),
        content: Text(
          'คุณกำลังจะลบ r/${_community!.name} รวมถึงโพสต์และสมาชิกทั้งหมด การลบนี้ย้อนกลับไม่ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบชุมชน', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      await _service.deleteCommunity(widget.communityId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบชุมชนไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(initialCommunity: _community),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityRequestsScreen(communityId: widget.communityId),
      ),
    );
    _load(); // อนุมัติแล้วจำนวนสมาชิกเปลี่ยน
  }

  void _openMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityMembersScreen(communityId: widget.communityId),
      ),
    );
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
              const Text('โหลดชุมชนไม่สำเร็จ'),
              TextButton(onPressed: _load, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }
    final community = _community;
    if (community == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('ไม่พบชุมชนนี้')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('r/${community.name}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            _buildHeader(community),
            const Divider(height: 1),
            if (!_canViewPosts)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 40, color: Colors.black26),
                      SizedBox(height: 10),
                      Text(
                        'ชุมชนนี้ต้องได้รับอนุมัติ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'เข้าร่วมชุมชนก่อนถึงจะเห็นโพสต์ได้',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
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
                      'ยังไม่มีโพสต์ในชุมชนนี้',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ),
                )
              else
                ..._posts.map(
                  (post) => PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onUpdated: (updated) => setState(() {
                      _posts = _posts
                          .map((p) => p.id == updated.id ? updated : p)
                          .toList();
                    }),
                    onDeleted: () => setState(() {
                      _posts = _posts.where((p) => p.id != post.id).toList();
                    }),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Community community) {
    final isActive = _status == MembershipStatus.active;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          CommunityAvatar(
            name: community.name,
            imageBase64: community.imageBase64,
            radius: 40,
          ),
          const SizedBox(height: 10),
          Text(
            'r/${community.name}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              InkWell(
                onTap: !community.requiresApproval || isActive
                    ? _openMembers
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${community.memberCount} สมาชิก · ดูรายชื่อ',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const Text('·', style: TextStyle(color: Colors.black38)),
              Icon(
                community.requiresApproval ? Icons.lock_outline : Icons.public,
                size: 14,
                color: Colors.black54,
              ),
              Text(
                community.requiresApproval ? 'ต้องได้รับอนุมัติ' : 'ใครเข้าก็ได้',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
          Text(
            'สร้างโดย u/${community.ownerUsername}',
            style: const TextStyle(color: Colors.black38, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isActive)
                FilledButton.icon(
                  onPressed: _openCreatePost,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('โพสต์ในชุมชนนี้'),
                ),
              if (_isOwner && community.requiresApproval)
                OutlinedButton.icon(
                  onPressed: _openRequests,
                  icon: StreamBuilder<int>(
                    stream: _pendingRequestCountStream,
                    builder: (context, snapshot) => NotificationDot(
                      show: (snapshot.data ?? 0) > 0,
                      child: const Icon(Icons.how_to_reg_outlined, size: 18),
                    ),
                  ),
                  label: const Text('คำขอเข้าร่วม'),
                ),
              if (_isOwner)
                OutlinedButton.icon(
                  onPressed: _working ? null : _confirmDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('ลบชุมชน'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              // เจ้าของชุมชนออกจากชุมชนตัวเองไม่ได้
              if (isActive && !_isOwner)
                OutlinedButton(
                  onPressed: _working ? null : _confirmLeave,
                  child: const Text('ออกจากชุมชน'),
                ),
              if (_status == MembershipStatus.pending)
                OutlinedButton(
                  onPressed: _working ? null : _confirmLeave,
                  child: const Text('ยกเลิกคำขอ'),
                ),
              if (_status == MembershipStatus.none)
                FilledButton(
                  onPressed:
                      _working ? null : () => _run(() => _service.joinCommunity(community)),
                  child: Text(community.requiresApproval ? 'ขอเข้าร่วม' : 'เข้าร่วม'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
