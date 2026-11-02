import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/chat_message_model.dart';
import '../services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUsername,
  });

  final String chatId;
  final String otherUsername;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _chatService = ChatService();
  final _textController = TextEditingController();
  final _myUid = FirebaseAuth.instance.currentUser?.uid;

  // สร้าง stream ครั้งเดียว (late final) เช่นเดียวกับที่แก้ไว้ในฟีดโพสต์
  // กันไม่ให้ subscribe ใหม่ทุกครั้งที่ widget rebuild
  late final Stream<List<ChatMessage>> _messagesStream =
      _chatService.messagesStream(widget.chatId);

  bool _sending = false;
  final _picker = ImagePicker();

  Future<void> _pickMedia({required bool video}) async {
    if (_sending) return;
    final file = video
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await _chatService.sendMedia(
        chatId: widget.chatId,
        file: file,
        mediaType: video ? 'video' : 'image',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งไฟล์ไม่สำเร็จ กรุณาลองอีกครั้ง')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showEmojiPicker() async {
    const emojis = ['😀','😃','😄','😁','😆','😂','🥹','😊','😍','🥰','😘','😎','🤔','😭','😡','👍','👎','👏','🙏','🎉','❤️','🔥','✨','💯','🐱','🌟'];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 7,
          children: [for (final value in emojis) TextButton(onPressed: () => Navigator.pop(context, value), child: Text(value, style: const TextStyle(fontSize: 26)))],
        ),
      ),
    );
    if (emoji == null) return;
    final value = _textController.value;
    final text = value.text;
    final start = value.selection.start < 0 ? text.length : value.selection.start;
    final end = value.selection.end < 0 ? start : value.selection.end;
    final updated = text.replaceRange(start, end, emoji);
    _textController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text;
    if (text.trim().isEmpty || _sending) return;

    setState(() => _sending = true);
    _textController.clear();
    try {
      await _chatService.sendMessage(chatId: widget.chatId, text: text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งข้อความไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('u/${widget.otherUsername}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('โหลดข้อความไม่สำเร็จ'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'เริ่มทักทายกันได้เลย',
                      style: TextStyle(color: Colors.black45),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _myUid;
                    return Align(
                      key: ValueKey(msg.id),
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? colors.primary : const Color(0xFFF0F0F1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (msg.mediaUrl != null && msg.mediaType == 'image')
                              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(msg.mediaUrl!, width: 220, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Text('โหลดรูปไม่สำเร็จ'))),
                            if (msg.mediaUrl != null && msg.mediaType == 'video')
                              _ChatVideo(url: msg.mediaUrl!),
                            if (msg.text.isNotEmpty)
                              Text(msg.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'ส่งรูปภาพ',
                    icon: const Icon(Icons.image_outlined),
                    onPressed: _sending ? null : () => _pickMedia(video: false),
                  ),
                  IconButton(
                    tooltip: 'ส่งวิดีโอ',
                    icon: const Icon(Icons.video_library_outlined),
                    onPressed: _sending ? null : () => _pickMedia(video: true),
                  ),
                  IconButton(
                    tooltip: 'Emoji',
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    onPressed: _showEmojiPicker,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Color(0xFFF0F0F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatVideo extends StatefulWidget {
  const _ChatVideo({required this.url});
  final String url;

  @override
  State<_ChatVideo> createState() => _ChatVideoState();
}

class _ChatVideoState extends State<_ChatVideo> {
  late final VideoPlayerController _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_) { if (mounted) setState(() {}); });

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) return const SizedBox(width: 220, height: 140, child: Center(child: CircularProgressIndicator()));
    return SizedBox(
      width: 220,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(alignment: Alignment.center, children: [
          VideoPlayer(_controller),
          IconButton.filledTonal(
            onPressed: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
            icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
        ]),
      ),
    );
  }
}
