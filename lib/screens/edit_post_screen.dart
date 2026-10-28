import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';
import '../services/firestore_service.dart';
import '../widgets/post_video_player.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, required this.post});

  final Post post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.post.title);
  late final _bodyController = TextEditingController(text: widget.post.body);
  final _firestoreService = FirestoreService();

  Uint8List? _newImageBytes; // ผู้ใช้เลือกรูปใหม่มาแทนของเดิม
  bool _removeImage = false; // ผู้ใช้กดเอารูปเดิมออกโดยไม่เลือกรูปใหม่

  Uint8List? _newVideoBytes;
  String? _newVideoFileName;
  bool _removeVideo = false;

  bool _saving = false;

  bool get _hasImage =>
      !_removeImage && (_newImageBytes != null || widget.post.imageBase64 != null);
  bool get _hasExistingVideo => !_removeVideo && widget.post.videoUrl != null;
  bool get _hasNewVideo => _newVideoBytes != null;
  bool get _hasAnyMedia => _hasImage || _hasExistingVideo || _hasNewVideo;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 60,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) {
      setState(() {
        _newImageBytes = bytes;
        _removeImage = false;
        // สลับมาเป็นรูป เลยเอาวิดีโอ (เดิมหรือใหม่) ออก
        _newVideoBytes = null;
        _newVideoFileName = null;
        _removeVideo = true;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) {
      setState(() {
        _newVideoBytes = bytes;
        _newVideoFileName = picked.name;
        _removeVideo = false;
        // สลับมาเป็นวิดีโอ เลยเอารูป (เดิมหรือใหม่) ออก
        _newImageBytes = null;
        _removeImage = true;
      });
    }
  }

  void _removeMedia() {
    setState(() {
      _newImageBytes = null;
      _removeImage = true;
      _newVideoBytes = null;
      _newVideoFileName = null;
      _removeVideo = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await _firestoreService.updatePost(
        postId: widget.post.id,
        title: _titleController.text,
        body: _bodyController.text,
        imageBytes: _newImageBytes,
        removeImage: _removeImage,
        videoBytes: _newVideoBytes,
        removeVideo: _removeVideo,
      );

      // ส่งโพสต์เวอร์ชันใหม่กลับไปให้การ์ดอัปเดตทันที ไม่ต้องรอรอบ poll
      // (videoUrl ใหม่จริงจาก Cloudinary ยังไม่รู้ค่าตรงนี้ ถ้าเพิ่งอัปโหลด
      // วิดีโอใหม่ การ์ดจะเห็นลิงก์จริงหลังรอบ poll ถัดไปแทน)
      final updated = Post(
        id: widget.post.id,
        authorId: widget.post.authorId,
        authorUsername: widget.post.authorUsername,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        createdAt: widget.post.createdAt,
        upvoteCount: widget.post.upvoteCount,
        commentCount: widget.post.commentCount,
        imageBase64: _removeImage
            ? null
            : (_newImageBytes != null
                ? base64Encode(_newImageBytes!)
                : widget.post.imageBase64),
        videoUrl: _removeVideo
            ? null
            : (_newVideoBytes == null ? widget.post.videoUrl : null),
      );

      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไขโพสต์'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'บันทึก',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              maxLength: 300,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'หัวข้อ',
                border: InputBorder.none,
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรอกหัวข้อโพสต์';
                }
                return null;
              },
            ),
            const Divider(),
            TextFormField(
              controller: _bodyController,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'เนื้อหา (ไม่บังคับ)',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            _buildMediaArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaArea() {
    if (!_hasAnyMedia) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('เพิ่มรูปภาพ'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('เพิ่มวิดีโอ'),
            ),
          ),
        ],
      );
    }

    // มีวิดีโอใหม่ที่เพิ่งเลือก (ยังไม่ได้อัปโหลด) — โชว์แค่ชื่อไฟล์
    if (_hasNewVideo) {
      return _mediaContainer(
        child: Row(
          children: [
            const Icon(Icons.videocam, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _newVideoFileName ?? 'วิดีโอใหม่',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    // มีวิดีโอเดิมอยู่แล้ว (ยังไม่ได้แก้) — เล่นดูได้เลยจากลิงก์เดิม
    if (_hasExistingVideo) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PostVideoPlayer(videoUrl: widget.post.videoUrl!),
          ),
          _removeButton(),
        ],
      );
    }

    // เหลือกรณีมีรูปภาพ (เดิมหรือใหม่)
    final bytes = _newImageBytes ?? base64Decode(widget.post.imageBase64!);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        _removeButton(),
      ],
    );
  }

  Widget _mediaContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _removeMedia,
          ),
        ],
      ),
    );
  }

  Widget _removeButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: InkWell(
        onTap: _removeMedia,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}