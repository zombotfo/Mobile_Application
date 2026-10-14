import 'package:flutter/material.dart';

import '../models/app_user_model.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import 'chat_detail_screen.dart';

/// ค้นหาผู้ใช้คนไหนก็ได้ในระบบ — เริ่มแชทได้ทันทีโดยไม่ต้องเป็นเพื่อนกันก่อน
/// และเพิ่ม/ลบเพื่อนได้จากหน้านี้เลย
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _friendService = FriendService();
  final _chatService = ChatService();
  final _controller = TextEditingController();

  List<AppUser> _results = [];
  bool _loading = false;
  bool _searchedOnce = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final results = await _friendService.searchUsers(query);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
        _searchedOnce = true;
      });
    }
  }

  Future<void> _openChat(AppUser otherUser) async {
    try {
      final chatId = await _chatService.startChat(
        otherUid: otherUser.uid,
        otherUsername: otherUser.username,
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatId: chatId,
              otherUsername: otherUser.username,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'ค้นหาชื่อผู้ใช้...',
            border: InputBorder.none,
          ),
          onChanged: _search,
          onSubmitted: _search,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Text(
                    !_searchedOnce
                        ? 'พิมพ์ชื่อผู้ใช้เพื่อค้นหา'
                        : 'ไม่พบผู้ใช้ที่ตรงกับ "${_controller.text}"',
                    style: const TextStyle(color: Colors.black45),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final u = _results[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          u.username.isNotEmpty
                              ? u.username[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text('u/${u.username}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FriendToggleButton(
                            friendUid: u.uid,
                            friendUsername: u.username,
                          ),
                          IconButton(
                            tooltip: 'ส่งข้อความ',
                            icon: const Icon(Icons.chat_bubble_outline),
                            onPressed: () => _openChat(u),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _FriendToggleButton extends StatefulWidget {
  const _FriendToggleButton({
    required this.friendUid,
    required this.friendUsername,
  });

  final String friendUid;
  final String friendUsername;

  @override
  State<_FriendToggleButton> createState() => _FriendToggleButtonState();
}

class _FriendToggleButtonState extends State<_FriendToggleButton> {
  final _friendService = FriendService();
  late final Stream<bool> _isFriendStream =
      _friendService.isFriendStream(widget.friendUid);
  bool _working = false;

  Future<void> _toggle(bool isFriend) async {
    setState(() => _working = true);
    try {
      if (isFriend) {
        await _friendService.removeFriend(widget.friendUid);
      } else {
        await _friendService.addFriend(
          friendUid: widget.friendUid,
          friendUsername: widget.friendUsername,
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
      stream: _isFriendStream,
      builder: (context, snapshot) {
        final isFriend = snapshot.data ?? false;
        return TextButton(
          onPressed: _working ? null : () => _toggle(isFriend),
          child: Text(isFriend ? 'ลบเพื่อน' : 'เพิ่มเพื่อน'),
        );
      },
    );
  }
}
