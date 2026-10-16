import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firestoreService = FirestoreService();

  static final _usernameRegex = RegExp(r'^[A-Za-z0-9_]+$');

  bool _loadingProfile = true;
  String? _existingPhotoBase64;
  Uint8List? _newPhotoBytes;
  bool _removePhoto = false;
  bool _saving = false;

  bool get _hasPhoto =>
      !_removePhoto && (_newPhotoBytes != null || _existingPhotoBase64 != null);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await _firestoreService.fetchOwnProfile();
    if (!mounted) return;
    setState(() {
      _usernameController.text = data?['username'] as String? ?? '';
      _existingPhotoBase64 = data?['photoBase64'] as String?;
      _loadingProfile = false;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    // รูปโปรไฟล์แสดงเล็กๆ จึงใช้ความละเอียดต่ำกว่ารูปโพสต์ได้ ไฟล์จะเล็กลงด้วย
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) {
      setState(() {
        _newPhotoBytes = bytes;
        _removePhoto = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await _firestoreService.updateUsername(
        _usernameController.text,
        photoBytes: _newPhotoBytes,
        removePhoto: _removePhoto,
      );
      if (mounted) Navigator.of(context).pop();
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
        title: const Text('แก้ไขโปรไฟล์'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: (_saving || _loadingProfile) ? null : _save,
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
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(child: _buildPhotoPicker(context)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อผู้ใช้',
                      prefixText: 'u/',
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.length < 3 || v.length > 20) {
                        return 'ใช้ 3–20 ตัวอักษร';
                      }
                      if (!_usernameRegex.hasMatch(v)) {
                        return 'ใช้ได้เฉพาะ a-z, 0-9 และ _';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoPicker(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: CircleAvatar(
            radius: 48,
            backgroundColor: colors.primary,
            backgroundImage: _hasPhoto
                ? MemoryImage(
                    _newPhotoBytes ?? base64Decode(_existingPhotoBase64!),
                  )
                : null,
            child: !_hasPhoto
                ? const Icon(
                    Icons.add_a_photo_outlined,
                    color: Colors.white,
                    size: 28,
                  )
                : null,
          ),
        ),
        if (_hasPhoto)
          Positioned(
            right: 0,
            bottom: 0,
            child: InkWell(
              onTap: () => setState(() {
                _newPhotoBytes = null;
                _removePhoto = true;
              }),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}