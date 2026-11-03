import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/friendship_model.dart';
import '../services/chat_service.dart';
import '../services/friend_service.dart';
import 'chat_detail_screen.dart';
import 'profile_screen.dart';
import 'user_search_screen.dart';

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
              otherUserId: friend.otherUid,
              otherUsername: friend.otherUsername,
            ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพื่อนของฉัน'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserSearchScreen()),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('เพิ่มเพื่อน'),
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                    return StreamBuilder<Map<String, dynamic>?>(
                      stream: _chatService.userProfileStream(friend.otherUid),
                      builder: (context, snapshot) {
                        final profile = snapshot.data;
                        final username = profile?['username'] as String? ??
                            friend.otherUsername;
                        final encodedPhoto = profile?['photoBase64'] as String?;
                        ImageProvider<Object>? photo;
                        if (encodedPhoto != null && encodedPhoto.isNotEmpty) {
                          try {
                            photo = MemoryImage(base64Decode(encodedPhoto));
                          } on FormatException {
                            // Fall back to the user's initial for invalid photo data.
                          }
                        }
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: photo,
                            child: photo == null
                                ? Text(username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?')
                                : null,
                          ),
                          title: Text('u/$username'),
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
                    );
                  },
                ),
    );
  }
}
