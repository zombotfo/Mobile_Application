import 'package:flutter/material.dart';

import '../models/friendship_model.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import 'chat_detail_screen.dart';
import 'profile_screen.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final _friendService = FriendService();
  final _chatService = ChatService();
  List<Friendship>? _friends;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final friends = await _friendService.fetchFriends();
    if (mounted) setState(() => _friends = friends);
  }

  Future<void> _removeFriend(Friendship friend) async {
    await _friendService.removeFriendship(friend.otherUid);
    _load();
  }

  Future<void> _openChat(Friendship friend) async {
    try {
      final chatId = await _chatService.startChat(
        otherUid: friend.otherUid,
        otherUsername: friend.otherUsername,
      );
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatId: chatId,
              otherUsername: friend.otherUsername,
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
      appBar: AppBar(title: const Text('เพื่อนของฉัน')),
      body: _friends == null
          ? const Center(child: CircularProgressIndicator())
          : _friends!.isEmpty
              ? const Center(
                  child: Text(
                    'ยังไม่มีเพื่อน\nลองค้นหาและส่งคำขอเป็นเพื่อนจากหน้าแชทดูสิ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45),
                  ),
                )
              : ListView.builder(
                  itemCount: _friends!.length,
                  itemBuilder: (context, index) {
                    final friend = _friends![index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          friend.otherUsername.isNotEmpty
                              ? friend.otherUsername[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text('u/${friend.otherUsername}'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(uid: friend.otherUid),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'ส่งข้อความ',
                            icon: const Icon(Icons.chat_bubble_outline),
                            onPressed: () => _openChat(friend),
                          ),
                          IconButton(
                            tooltip: 'เลิกเป็นเพื่อน',
                            icon: const Icon(
                              Icons.person_remove_outlined,
                              color: Colors.red,
                            ),
                            onPressed: () => _removeFriend(friend),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}