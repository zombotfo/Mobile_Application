import 'package:flutter/material.dart';

import '../services/follow_service.dart';

class FollowActionButton extends StatefulWidget {
  const FollowActionButton({
    super.key,
    required this.uid,
    required this.username,
  });

  final String uid;
  final String username;

  @override
  State<FollowActionButton> createState() => _FollowActionButtonState();
}

class _FollowActionButtonState extends State<FollowActionButton> {
  final _followService = FollowService();
  late final Stream<bool> _isFollowingStream =
      _followService.isFollowingStream(widget.uid);
  bool _working = false;

  Future<void> _toggle(bool isFollowing) async {
    setState(() => _working = true);
    try {
      if (isFollowing) {
        await _followService.unfollowUser(widget.uid);
      } else {
        await _followService.followUser(
          targetUid: widget.uid,
          targetUsername: widget.username,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _isFollowingStream,
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;
        return following
            ? OutlinedButton(
                onPressed: _working ? null : () => _toggle(true),
                child: const Text('กำลังติดตาม'),
              )
            : FilledButton(
                onPressed: _working ? null : () => _toggle(false),
                child: const Text('ติดตาม'),
              );
      },
    );
  }
}
