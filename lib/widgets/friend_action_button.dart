import 'package:flutter/material.dart';

import '../models/friendship_model.dart';
import '../services/friend_service.dart';

/// ปุ่มเพื่อน ที่เปลี่ยนข้อความ/การกระทำไปตามสถานะความสัมพันธ์ปัจจุบัน
/// (เพิ่มเพื่อน → ยกเลิกคำขอ → ยอมรับคำขอ → เพื่อนกันแล้ว)
class FriendActionButton extends StatefulWidget {
  const FriendActionButton({
    super.key,
    required this.uid,
    required this.username,
  });

  final String uid;
  final String username;

  @override
  State<FriendActionButton> createState() => _FriendActionButtonState();
}

class _FriendActionButtonState extends State<FriendActionButton> {
  final _friendService = FriendService();
  late final Stream<FriendshipStatus> _statusStream =
      _friendService.friendshipStatusStream(widget.uid);
  bool _working = false;

  Future<void> _handle(FriendshipStatus status) async {
    if (status == FriendshipStatus.friends) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('เลิกเป็นเพื่อน'),
          content: Text('ต้องการเลิกเป็นเพื่อนกับ u/${widget.username} หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('เลิกเป็นเพื่อน', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _working = true);
    try {
      switch (status) {
        case FriendshipStatus.none:
          await _friendService.sendFriendRequest(
            targetUid: widget.uid,
            targetUsername: widget.username,
          );
          break;
        case FriendshipStatus.requestSent:
        case FriendshipStatus.friends:
          await _friendService.removeFriendship(widget.uid);
          break;
        case FriendshipStatus.requestReceived:
          await _friendService.acceptFriendRequest(widget.uid);
          break;
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
    return StreamBuilder<FriendshipStatus>(
      stream: _statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? FriendshipStatus.none;
        final label = switch (status) {
          FriendshipStatus.none => 'เพิ่มเพื่อน',
          FriendshipStatus.requestSent => 'ยกเลิกคำขอ',
          FriendshipStatus.requestReceived => 'ยอมรับคำขอ',
          FriendshipStatus.friends => 'เพื่อนกันแล้ว',
        };
        final isPrimary = status == FriendshipStatus.none ||
            status == FriendshipStatus.requestReceived;

        return isPrimary
            ? FilledButton(
                onPressed: _working ? null : () => _handle(status),
                child: Text(label),
              )
            : OutlinedButton(
                onPressed: _working ? null : () => _handle(status),
                child: Text(label),
              );
      },
    );
  }
}
