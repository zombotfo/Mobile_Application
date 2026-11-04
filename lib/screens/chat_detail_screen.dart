/// แสดงบทสนทนาและช่องส่งข้อความของห้องแชท
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../widgets/post_video_player.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUsername,
  });

  final String chatId;
  final String otherUserId;
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
  late Stream<List<ChatMessage>> _messagesStream;
  late final Stream<Map<String, dynamic>?> _otherProfileStream =
      _chatService.userProfileStream(widget.otherUserId);
  Timer? _messageLoadTimer;
  bool _messageLoadTimedOut = false;
  bool _receivedMessageSnapshot = false;

  bool _sending = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.messagesStream(widget.chatId);
    _startMessageLoadTimer();
  }

  void _startMessageLoadTimer() {
    _messageLoadTimer?.cancel();
    _messageLoadTimedOut = false;
    _receivedMessageSnapshot = false;
    _messageLoadTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _receivedMessageSnapshot) return;
      setState(() => _messageLoadTimedOut = true);
    });
  }

  void _retryMessages() {
    setState(() {
      _messagesStream = _chatService.messagesStream(widget.chatId);
      _messageLoadTimedOut = false;
      _receivedMessageSnapshot = false;
    });
    _startMessageLoadTimer();
  }

  String _messageTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return time;
    }
    return '${local.day}/${local.month} $time';
  }

  Future<void> _pickImage() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 55,
      );
      if (file == null || !mounted) return;
      await _chatService.sendImage(
        chatId: widget.chatId,
        file: file,
      );
    } on FirebaseException catch (e) {
      debugPrint('Chat image send failed (${e.code}): ${e.message}');
      if (mounted) {
        final message = e.code == 'permission-denied'
            ? 'ไม่มีสิทธิ์ส่งรูปในห้องแชทนี้'
            : 'ส่งรูปไม่สำเร็จ (${e.code}) ${e.message ?? ''}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      debugPrint('Chat image selection or send failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      await _chatService.sendVideo(chatId: widget.chatId, file: file);
    } on FirebaseException catch (e) {
      debugPrint('Chat video message failed (${e.code}): ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งวิดีโอไม่สำเร็จ: ${e.message ?? e.code}')),
        );
      }
    } catch (error) {
      debugPrint('Chat video selection or upload failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
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
    _messageLoadTimer?.cancel();
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
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<Map<String, dynamic>?>(
          stream: _otherProfileStream,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final username = profile?['username'] as String? ?? widget.otherUsername;
            final encodedPhoto = profile?['photoBase64'] as String?;
            ImageProvider<Object>? photo;
            if (encodedPhoto != null && encodedPhoto.isNotEmpty) {
              try {
                photo = MemoryImage(base64Decode(encodedPhoto));
              } on FormatException {
                photo = null;
              }
            }
            return Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundImage: photo,
                  child: photo == null
                      ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?')
                      : null,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('โหลดข้อความไม่สำเร็จ'),
                        TextButton(
                          onPressed: _retryMessages,
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  if (_messageLoadTimedOut) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('หมดเวลารอการเชื่อมต่อ'),
                          TextButton(
                            onPressed: _retryMessages,
                            child: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                _receivedMessageSnapshot = true;
                _messageLoadTimer?.cancel();
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
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _myUid;
                    final isMediaOnly = msg.text.isEmpty &&
                        (msg.mediaBase64 != null || msg.mediaUrl != null);
                    return Align(
                      key: ValueKey(msg.id),
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: isMediaOnly
                            ? EdgeInsets.zero
                            : const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: isMediaOnly
                              ? Colors.transparent
                              : isMe
                                  ? colors.primary
                                  : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 5),
                            bottomRight: Radius.circular(isMe ? 5 : 18),
                          ),
                          boxShadow: isMediaOnly
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.045),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (msg.mediaBase64 != null && msg.mediaType == 'image')
                              Image.memory(
                                base64Decode(msg.mediaBase64!),
                                width: MediaQuery.of(context).size.width * 0.7,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Text('เปิดรูปไม่สำเร็จ'),
                              )
                            else if (msg.mediaUrl != null && msg.mediaType == 'image')
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  msg.mediaUrl!,
                                  width: MediaQuery.of(context).size.width * 0.7,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint('Chat image load failed: $error');
                                    return const Text('โหลดรูปไม่สำเร็จ');
                                  },
                                ),
                              ),
                            if (msg.mediaUrl != null && msg.mediaType == 'video')
                              PostVideoPlayer(
                                videoUrl: msg.mediaUrl!,
                                width: MediaQuery.of(context).size.width * 0.7,
                              ),
                            if (msg.text.isNotEmpty)
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: isMe ? colors.onPrimary : colors.onSurface,
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.only(
                                top: isMediaOnly ? 5 : 4,
                                left: isMediaOnly ? 0 : 2,
                                right: isMediaOnly ? 0 : 2,
                                bottom: isMediaOnly ? 2 : 0,
                              ),
                              child: Text(
                                _messageTime(msg.sentAt),
                                style: TextStyle(
                                  color: isMediaOnly
                                      ? colors.onSurfaceVariant
                                      : isMe
                                          ? colors.onPrimary.withValues(alpha: 0.75)
                                          : colors.onSurfaceVariant,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
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
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'ส่งรูปภาพ',
                    icon: const Icon(Icons.image_outlined),
                    onPressed: _sending ? null : _pickImage,
                  ),
                  IconButton(
                    tooltip: 'ส่งวิดีโอ',
                    icon: const Icon(Icons.video_library_outlined),
                    onPressed: _sending ? null : _pickVideo,
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
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'ส่งข้อความ',
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 19),
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
