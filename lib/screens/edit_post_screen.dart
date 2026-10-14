import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';
import '../services/firestore_service.dart';

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
  bool _saving = false;

  bool get _hasImage =>
      !_removeImage && (_newImageBytes != null || widget.post.imageBase64 != null);

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
      });
    }
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
      );

      // ส่งโพสต์เวอร์ชันใหม่กลับไปให้การ์ดอัปเดตทันที ไม่ต้องรอรอบ poll
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
      );

      if (mounted) Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกไม่สำเร็จ กรุณาลองใหม่อีกครั้ง')),
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
            _buildImageArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    if (!_hasImage) {
      return InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    size: 32, color: Colors.black38),
                SizedBox(height: 6),
                Text(
                  'เพิ่มรูปภาพ (ไม่บังคับ)',
                  style: TextStyle(color: Colors.black45, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
        Positioned(
          top: 8,
          right: 8,
          child: InkWell(
            onTap: () => setState(() {
              _newImageBytes = null;
              _removeImage = true;
            }),
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
        ),
      ],
    );
  }
}