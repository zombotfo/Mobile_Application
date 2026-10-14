import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../utils/time_ago.dart';
import 'chat_detail_screen.dart';
import 'user_search_screen.dart';

/// รายการห้องแชททั้งหมดของผู้ใช้คนปัจจุบัน กดปุ่ม + เพื่อค้นหาและเริ่มคุย
/// กับใครก็ได้ (ไม่ต้องเป็นเพื่อนกันก่อน)
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  Timer? _pollTimer;
  List<ChatSummary>? _chats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    // ดึงรายการแชทใหม่ทุก 1 นาที เผื่อมีคนทักมาโดยที่เราไม่ได้เปิดแอปอยู่
    _pollTimer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool _hasError = false;

  Future<void> _refresh() async {
    try {
      final chats = await _chatService.fetchChats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _hasError = false;
        _loading = false;
      });
    } catch (_) {
      // เช่น ยังไม่ได้สร้าง Firestore composite index ให้ query นี้
      // กันไว้ไม่ให้ค้างเงียบๆ โดยไม่ขึ้นอะไรให้ผู้ใช้เห็นเลย
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _openUserSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserSearchScreen()),
    );
    _refresh(); // กลับมาจากหน้าค้นหา อาจมีห้องแชทใหม่ที่เพิ่งเริ่มคุย
  }

  Future<void> _openChat(ChatSummary chat) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chat.id,
          otherUsername: chat.otherUsername,
        ),
      ),
    );
    _refresh(); // กลับมาแล้วอัปเดต last message ล่าสุดในลิสต์
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('โหลดรายการแชทไม่สำเร็จ'),
                      const SizedBox(height: 4),
                      const Text(
                        '(อาจต้องสร้าง Firestore index ให้ query นี้ก่อน)',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
              onRefresh: _refresh,
              child: (_chats == null || _chats!.isEmpty)
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(40),
                          child: Text(
                            'ยังไม่มีการสนทนา\nกดปุ่ม + เพื่อเริ่มคุยกับใครก็ได้',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black45),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _chats!.length,
                      itemBuilder: (context, index) {
                        final chat = _chats![index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              chat.otherUsername.isNotEmpty
                                  ? chat.otherUsername[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text('u/${chat.otherUsername}'),
                          subtitle: Text(
                            chat.lastMessage.isEmpty
                                ? 'เริ่มการสนทนา'
                                : chat.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            timeAgo(chat.lastMessageAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                          onTap: () => _openChat(chat),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เริ่มแชทใหม่',
        onPressed: _openUserSearch,
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}