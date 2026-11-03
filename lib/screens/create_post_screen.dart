import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/community_model.dart';
import '../services/community_service.dart';
import '../services/firestore_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.initialCommunity});

  /// ชุมชนที่เลือกไว้ล่วงหน้า (เมื่อเปิดจากปุ่ม "โพสต์ในชุมชนนี้")
  final Community? initialCommunity;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _communityService = CommunityService();

  // ชุมชนที่โพสต์ลงได้ (เฉพาะที่เราเป็นสมาชิก) '' = โพสต์ทั่วไป ไม่ระบุชุมชน
  List<Community> _myCommunities = [];
  String _selectedCommunityId = '';

  Uint8List? _imageBytes;
  Uint8List? _videoBytes;
  String? _videoFileName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCommunity;
    if (initial != null) {
      _myCommunities = [initial];
      _selectedCommunityId = initial.id;
    }
    _loadMyCommunities();
  }

  Future<void> _loadMyCommunities() async {
    try {
      final list = await _communityService.fetchMyCommunities();
      if (!mounted) return;
      setState(() {
        _myCommunities = list;
        final initial = widget.initialCommunity;
        if (initial != null && !list.any((c) => c.id == initial.id)) {
          _myCommunities = [initial, ...list];
        }
      });
    } catch (_) {
      // โหลดรายการชุมชนไม่ได้ก็ยังโพสต์ทั่วไปได้ตามปกติ
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Resize ก่อนอัปโหลด เพื่อให้ส่งขึ้น Cloudinary ได้รวดเร็วขึ้น
    // ฝังในเอกสาร Firestore โดยตรง (จำกัดขนาดเอกสารไม่เกิน ~1MB)
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 60,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        // มีได้แค่รูปหรือวิดีโออย่างใดอย่างหนึ่งต่อโพสต์
        _videoBytes = null;
        _videoFileName = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    // จำกัดความยาวคลิปไว้ที่ 30 วินาที กันไฟล์ใหญ่/อัปโหลดนานเกินไป
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) {
      setState(() {
        _videoBytes = bytes;
        _videoFileName = picked.name;
        _imageBytes = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      await _firestoreService.createPost(
        title: _titleController.text,
        body: _bodyController.text,
        imageBytes: _imageBytes,
        videoBytes: _videoBytes,
        communityId: _selectedCommunityId.isEmpty ? null : _selectedCommunityId,
        communityName: _selectedCommunityId.isEmpty
            ? null
            : _myCommunities.firstWhere((c) => c.id == _selectedCommunityId).name,
      );
      // ส่งค่า true กลับไปบอก HomeScreen ว่าสร้างโพสต์สำเร็จ
      // จะได้สั่งรีเฟรชฟีดให้เห็นผลทันที ไม่ต้องรอรอบ poll 1 นาที
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างโพสต์'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'โพสต์',
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
            // เลือกชุมชนที่จะโพสต์ลง (โชว์เฉพาะเมื่อเราเข้าร่วมชุมชนอย่างน้อย 1 แห่ง)
            if (_myCommunities.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _selectedCommunityId,
                decoration: const InputDecoration(
                  labelText: 'โพสต์ไปที่',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('ทั่วไป (ไม่ระบุชุมชน)'),
                  ),
                  ..._myCommunities.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('r/${c.name}'),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedCommunityId = value ?? ''),
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              controller: _titleController,
              maxLength: 300,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
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
            _MediaPickerArea(
              imageBytes: _imageBytes,
              videoFileName: _videoFileName,
              onPickImage: _pickImage,
              onPickVideo: _pickVideo,
              onRemove: () => setState(() {
                _imageBytes = null;
                _videoBytes = null;
                _videoFileName = null;
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// เลือกได้แค่รูปหรือวิดีโออย่างใดอย่างหนึ่ง ไม่ใช่ทั้งคู่พร้อมกัน
class _MediaPickerArea extends StatelessWidget {
  const _MediaPickerArea({
    required this.imageBytes,
    required this.videoFileName,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onRemove,
  });

  final Uint8List? imageBytes;
  final String? videoFileName;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null && videoFileName == null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('เพิ่มรูปภาพ'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickVideo,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('เพิ่มวิดีโอ'),
            ),
          ),
        ],
      );
    }

    if (videoFileName != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.videocam, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                videoFileName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            imageBytes!,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: InkWell(
            onTap: onRemove,
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
