import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/chat_model.dart';
import '../services/block_service.dart';
import '../services/chat_service.dart';
import '../utils/time_ago.dart';
import 'chat_detail_screen.dart';

/// รายการห้องแชททั้งหมดของผู้ใช้คนปัจจุบัน กดปุ่ม + เพื่อค้นหาและเริ่มคุย
/// กับใครก็ได้ (ไม่ต้องเป็นเพื่อนกันก่อน)
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  final _blockService = BlockService();
  StreamSubscription<List<ChatSummary>>? _chatsSubscription;
  StreamSubscription<Set<String>>? _blocksSubscription;
  Timer? _initialLoadTimer;
  List<ChatSummary>? _chats;
  Set<String> _blockedIds = <String>{};
  Set<String>? _matchingChatIds;
  bool _loading = true;
  bool _searchFiltering = false;
  int _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    _blocksSubscription = _blockService.blockedUserIdsStream().listen((ids) {
      if (!mounted) return;
      setState(() => _blockedIds = ids);
      _filterChats();
    }, onError: (Object error) {
      // Keep the chat list usable if block lookup is unavailable.
      debugPrint('ChatListScreen: block stream failed: $error');
    });
    _listenToChats();
  }

  @override
  void dispose() {
    _searchRequest++;
    _initialLoadTimer?.cancel();
    _chatsSubscription?.cancel();
    _blocksSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) _filterChats();
  }

  bool _hasError = false;

  void _listenToChats() {
    _chatsSubscription?.cancel();
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _chats != null) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    });
    _chatsSubscription = _chatService.chatsStream().listen(
      (chats) {
        if (!mounted) return;
        _initialLoadTimer?.cancel();
        setState(() {
          _chats = chats;
          _hasError = false;
          _loading = false;
        });
        _filterChats();
      },
      onError: (Object error) {
        _initialLoadTimer?.cancel();
        debugPrint('ChatListScreen: chat stream failed: $error');
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _loading = false;
        });
      },
    );
  }

  Future<void> _filterChats() async {
    final request = ++_searchRequest;
    final query = widget.searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _matchingChatIds = null;
          _searchFiltering = false;
        });
      }
      return;
    }

    final chats = _chats;
    if (chats == null) return;
    setState(() => _searchFiltering = true);

    final matchingIds = <String>{};
    await Future.wait(chats.map((chat) async {
      if (_blockedIds.contains(chat.otherUserId)) return;
      Map<String, dynamic>? profile;
      try {
        profile = await _chatService
            .fetchUserProfile(chat.otherUserId)
            .timeout(const Duration(seconds: 6));
      } catch (error) {
        debugPrint('Chat search profile lookup failed: $error');
      }
      final username = profile?['username'] as String? ?? chat.otherUsername;
      if (username.toLowerCase().contains(query) ||
          chat.lastMessage.toLowerCase().contains(query)) {
        matchingIds.add(chat.id);
      }
    }));

    if (!mounted || request != _searchRequest) return;
    setState(() {
      _matchingChatIds = matchingIds;
      _searchFiltering = false;
    });
  }

  Future<void> _refresh() async {
    try {
      final chats = await _chatService
          .fetchChats()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      _initialLoadTimer?.cancel();
      setState(() {
        _chats = chats;
        _hasError = false;
        _loading = false;
      });
      _filterChats();
    } catch (error) {
      debugPrint('ChatListScreen: refresh failed: $error');
      // เช่น ยังไม่ได้สร้าง Firestore composite index ให้ query นี้
      // กันไว้ไม่ให้ค้างเงียบๆ โดยไม่ขึ้นอะไรให้ผู้ใช้เห็นเลย
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _openChat(ChatSummary chat) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chat.id,
          otherUserId: chat.otherUserId,
          otherUsername: chat.otherUsername,
        ),
      ),
    );
    _refresh(); // กลับมาแล้วอัปเดต last message ล่าสุดในลิสต์
  }

  Widget _chatTile(ChatSummary chat) {
    final initial = chat.otherUsername.isNotEmpty
        ? chat.otherUsername[0].toUpperCase()
        : '?';

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _chatService.userProfileStream(chat.otherUserId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final username = profile?['username'] as String? ?? chat.otherUsername;
        final encodedPhoto = profile?['photoBase64'] as String?;
        ImageProvider<Object>? photo;
        if (encodedPhoto != null && encodedPhoto.isNotEmpty) {
          try {
            photo = MemoryImage(base64Decode(encodedPhoto));
          } on FormatException {
            // Keep showing the initials when a stored photo is invalid.
          }
        }
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: photo,
            child: photo == null
                ? Text(username.isNotEmpty ? username[0].toUpperCase() : initial)
                : null,
          ),
          title: Text('u/$username'),
          subtitle: Text(
            chat.lastMessage.isEmpty ? 'เริ่มการสนทนา' : chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            timeAgo(chat.lastMessageAt),
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          onTap: () => _openChat(chat),
        );
      },
    );
  }

  List<ChatSummary> get _visibleChats => (_chats ?? const <ChatSummary>[])
      .where((chat) => !_blockedIds.contains(chat.otherUserId))
      .where((chat) =>
          _matchingChatIds == null || _matchingChatIds!.contains(chat.id))
      .toList();

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
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _loading = true;
                          });
                          _listenToChats();
                          _refresh();
                        },
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
              onRefresh: _refresh,
              child: _searchFiltering
                  ? const Center(child: CircularProgressIndicator())
                  : (_visibleChats.isEmpty && widget.searchQuery.trim().isEmpty)
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
                  : widget.searchQuery.trim().isNotEmpty &&
                          (_matchingChatIds?.isEmpty ?? false)
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('ไม่พบแชทที่ค้นหา')),
                            ),
                          ],
                        )
                      : ListView.builder(
                      itemCount: _visibleChats.length,
                      itemBuilder: (context, index) {
                        final chat = _visibleChats[index];
                        return _chatTile(chat);
                      },
                    ),
            ),
    );
  }
}
