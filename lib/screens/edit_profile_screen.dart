import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.currentUsername});

  final String currentUsername;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _usernameController =
      TextEditingController(text: widget.currentUsername);
  final _firestoreService = FirestoreService();
  bool _saving = false;

  static final _usernameRegex = RegExp(r'^[A-Za-z0-9_]+$');

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await _firestoreService.updateUsername(_usernameController.text);
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'ชื่อผู้ใช้',
              prefixText: 'u/',
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.length < 3 || v.length > 20) return 'ใช้ 3–20 ตัวอักษร';
              if (!_usernameRegex.hasMatch(v)) {
                return 'ใช้ได้เฉพาะ a-z, 0-9 และ _';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}
