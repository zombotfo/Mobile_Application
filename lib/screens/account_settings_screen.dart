import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen>
    with WidgetsBindingObserver {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _newEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  bool _loading = true;
  bool _isPrivate = false;
  bool _saving = false;
  bool _securityBusy = false;
  String? _accountEmail;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accountEmail = FirebaseAuth.instance.currentUser?.email;
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccountEmail();
  }

  Future<void> _refreshAccountEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      final email = refreshedUser?.email;
      if (email == null || email == _accountEmail) return;
      await _firestoreService.updateAccountEmail(email);
      if (mounted) setState(() => _accountEmail = email);
      _showMessage('ยืนยันและเปลี่ยนอีเมลเป็น $email แล้ว');
    } catch (_) {
      // A failed profile sync can be retried the next time the app resumes.
    }
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showMessage('ไม่พบอีเมลในบัญชีนี้');
      return;
    }
    setState(() => _securityBusy = true);
    try {
      await _authService.sendPasswordReset(email);
      _showMessage('ส่งลิงก์ตั้งรหัสผ่านใหม่ไปที่ $email แล้ว');
    } on FirebaseAuthException catch (e) {
      _showMessage(AuthService.errorMessage(e));
    } catch (_) {
      _showMessage('ส่งอีเมลไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _securityBusy = false);
    }
  }

  Future<void> _requestEmailChange() async {
    final email = _newEmailController.text.trim();
    final password = _currentPasswordController.text;
    if (!_emailRegex.hasMatch(email)) {
      _showMessage('กรุณากรอกอีเมลใหม่ให้ถูกต้อง');
      return;
    }
    if (password.isEmpty) {
      _showMessage('กรุณากรอกรหัสผ่านปัจจุบันเพื่อยืนยันตัวตน');
      return;
    }

    setState(() => _securityBusy = true);
    try {
      await _authService.requestEmailChange(
        newEmail: email,
        currentPassword: password,
      );
      _newEmailController.clear();
      _currentPasswordController.clear();
      _showMessage('ส่งลิงก์ยืนยันไปที่ $email แล้ว กดลิงก์เพื่อเปลี่ยนอีเมล');
    } on FirebaseAuthException catch (e) {
      _showMessage(AuthService.errorMessage(e));
    } catch (_) {
      _showMessage('ส่งคำขอเปลี่ยนอีเมลไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _securityBusy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newEmailController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การตั้งค่าบัญชี')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const ListTile(
                  title: Text('ธีมสี'),
                  subtitle: Text('เลือกสีที่ใช้ในแอป'),
                ),
                ValueListenableBuilder<AppThemeChoice>(
                  valueListenable: AppTheme.choice,
                  builder: (context, selected, _) => Column(
                    children: [
                      _themeOption(AppThemeChoice.red, selected, 'แดง',
                          const Color(0xFFED4245)),
                      _themeOption(AppThemeChoice.green, selected, 'เขียว',
                          const Color(0xFF3BA55C)),
                    ],
                  ),
                ),
                const Divider(),
                const ListTile(
                  title: Text('ความปลอดภัย'),
                  subtitle: Text('จัดการอีเมลและรหัสผ่านของบัญชี'),
                ),
                ListTile(
                  title: Text('อีเมลปัจจุบัน'),
                  subtitle: Text(
                    _accountEmail ?? 'ไม่มีอีเมล',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.newUsername],
                    decoration: const InputDecoration(
                      labelText: 'อีเมลใหม่',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'รหัสผ่านปัจจุบัน (ยืนยันการเปลี่ยนอีเมล)',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _securityBusy ? null : _requestEmailChange,
                      child: const Text('ส่งลิงก์ยืนยันเปลี่ยนอีเมล'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _securityBusy ? null : _sendPasswordReset,
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('ส่งลิงก์ตั้งรหัสผ่านใหม่'),
                    ),
                  ),
                ),
                const Divider(),
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
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text(
                    'หมายเหตุ: ไม่ว่าจะตั้งเป็นส่วนตัวหรือไม่ ใครก็ยังส่งคำขอเป็น'
                    'เพื่อนมาหาคุณได้ตามปกติ',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _themeOption(
    AppThemeChoice choice,
    AppThemeChoice selected,
    String label,
    Color color,
  ) => RadioListTile<AppThemeChoice>(
        value: choice,
        groupValue: selected,
        onChanged: (value) {
          if (value != null) AppTheme.choice.value = value;
        },
        title: Text(label),
        secondary: CircleAvatar(radius: 12, backgroundColor: color),
      );
}
