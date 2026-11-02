import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/community_service.dart';
import '../widgets/community_avatar.dart';

/// สร้างชุมชนใหม่: ชื่อ (เช่น r/games) + รูปไอคอน + รูปแบบการเข้าร่วม
/// สำเร็จแล้วส่ง id ของชุมชนกลับไปให้หน้าก่อนหน้าเปิดหน้าชุมชนต่อ
class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _service = CommunityService();

  Uint8List? _imageBytes;
  String _joinType = 'open';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // ไอคอนแสดงเล็กๆ ใช้ความละเอียดต่ำได้ ไฟล์จะเล็กพอฝังใน Firestore
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      imageQuality: 70,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final id = await _service.createCommunity(
        name: _nameController.text,
        joinType: _joinType,
        imageBytes: _imageBytes,
      );
      if (mounted) Navigator.of(context).pop(id);
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
    final name = _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างชุมชน'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _create,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'สร้าง',
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
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: _imageBytes != null
                        ? CircleAvatar(
                            radius: 44,
                            backgroundImage: MemoryImage(_imageBytes!),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              CommunityAvatar(name: name, radius: 44),
                              const Icon(
                                Icons.add_a_photo_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                            ],
                          ),
                  ),
                  if (_imageBytes != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap: () => setState(() => _imageBytes = null),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'รูปชุมชน (ไม่บังคับ)',
                style: TextStyle(fontSize: 12.5, color: Colors.black45),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              maxLength: 21,
              decoration: const InputDecoration(
                labelText: 'ชื่อชุมชน',
                prefixText: 'r/',
                helperText: 'ใช้ได้เฉพาะ a-z, 0-9 และ _ (3–21 ตัวอักษร) แก้ชื่อทีหลังไม่ได้',
                counterText: '',
              ),
              validator: (value) {
                if (!CommunityService.nameRegex.hasMatch(value?.trim() ?? '')) {
                  return 'ใช้ได้เฉพาะ a-z, 0-9 และ _ (3–21 ตัวอักษร)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'รูปแบบการเข้าร่วม',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'open',
                  icon: Icon(Icons.public),
                  label: Text('ใครเข้าก็ได้'),
                ),
                ButtonSegment(
                  value: 'approval',
                  icon: Icon(Icons.lock_outline),
                  label: Text('ต้องอนุมัติ'),
                ),
              ],
              selected: {_joinType},
              onSelectionChanged: (s) => setState(() => _joinType = s.first),
            ),
            const SizedBox(height: 10),
            Text(
              _joinType == 'open'
                  ? 'ทุกคนกด "เข้าร่วม" แล้วเป็นสมาชิกได้ทันที และดูโพสต์ในชุมชนได้'
                  : 'ต้องส่งคำขอและรอคุณอนุมัติก่อน คนที่ยังไม่เป็นสมาชิกจะไม่เห็นโพสต์ในชุมชน',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
