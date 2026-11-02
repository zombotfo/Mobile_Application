import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _firestoreService = FirestoreService();
  bool _loading = true;
  bool _isPrivate = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _firestoreService.fetchOwnProfile();
    if (mounted) {
      setState(() {
        _isPrivate = profile?['isPrivate'] as bool? ?? false;
        _loading = false;
      });
    }
  }

  Future<void> _setPrivacy(bool value) async {
    final previous = _isPrivate;
    setState(() {
      _isPrivate = value;
      _saving = true;
    });

    try {
      await _firestoreService.updatePrivacy(value);
    } catch (_) {
      if (mounted) {
        setState(() => _isPrivate = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การตั้งค่าบัญชี')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('บัญชีส่วนตัว (Private)'),
                  subtitle: Text(
                    _isPrivate
                        ? 'คนที่ไม่ใช่เพื่อนจะเห็นแค่ว่าบัญชีนี้เป็นส่วนตัว '
                            'ไม่เห็นโพสต์ และส่งข้อความหาคุณไม่ได้'
                        : 'ทุกคนเห็นโปรไฟล์ โพสต์ และส่งข้อความหาคุณได้ตามปกติ',
                  ),
                  value: _isPrivate,
                  onChanged: _saving ? null : _setPrivacy,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text(
                    'หมายเหตุ: ไม่ว่าจะตั้งเป็นส่วนตัวหรือไม่ ใครก็ยังส่งคำขอเป็น'
                    'เพื่อนมาหาคุณได้ตามปกติ',
                    style: TextStyle(fontSize: 12.5, color: Colors.black45),
                  ),
                ),
              ],
            ),
    );
  }
}
