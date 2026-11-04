/// หน้าล็อกอินและสมัครบัญชีผู้ใช้ด้วย Firebase Authentication
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _loading = false;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _usernameRegex = RegExp(r'^[A-Za-z0-9_ก-๙]+$');
  static const _orange = Color(0xFFF4511E);

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authService.register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(AuthService.errorMessage(e));
    } catch (_) {
      _showMessage('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      _showMessage('กรอกอีเมลให้ถูกต้องก่อน แล้วลองกดลืมรหัสผ่านอีกครั้ง');
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      _showMessage('ส่งลิงก์ตั้งรหัสผ่านใหม่ไปที่ $email แล้ว');
    } on FirebaseAuthException catch (e) {
      _showMessage(AuthService.errorMessage(e));
    }
  }

  void _toggleMode() {
    setState(() => _isLogin = !_isLogin);
    _confirmPasswordController.clear();
    _formKey.currentState?.reset();
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8A8A8A), size: 21),
        filled: true,
        fillColor: const Color(0xFFF8F7F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEAE7E3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEAE7E3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _orange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD64545)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD64545), width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F4),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 22,
                vertical: compact ? 18 : 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(26, compact ? 22 : 32, 26, 28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF7438), Color(0xFFEC3D08)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: _orange.withValues(alpha: 0.22),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(17),
                                child: Image.asset('assets/branding/app_icon.png'),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Agora',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'พื้นที่ของคุณ สำหรับทุกบทสนทนา',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 22 : 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFF0EAE4)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _isLogin ? 'ยินดีต้อนรับกลับ' : 'เริ่มต้นใช้งาน Agora',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF24211F),
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isLogin
                                    ? 'เข้าสู่ระบบเพื่อกลับไปหาชุมชนของคุณ'
                                    : 'สร้างบัญชี แล้วเข้าร่วมบทสนทนาได้เลย',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (!_isLogin) ...[
                                TextFormField(
                                  controller: _usernameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration('ชื่อผู้ใช้', Icons.alternate_email_rounded),
                                  validator: (value) {
                                    final v = value?.trim() ?? '';
                                    if (v.length < 3 || v.length > 20) {
                                      return 'ใช้ 3–20 ตัวอักษร';
                                    }
                                    if (!_usernameRegex.hasMatch(v)) {
                                      return 'ใช้ภาษาไทย a-z, 0-9 และ _ ได้';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: _inputDecoration('อีเมล', Icons.mail_outline_rounded),
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) return 'กรุณากรอกอีเมล';
                                  if (!_emailRegex.hasMatch(v)) return 'รูปแบบอีเมลไม่ถูกต้อง';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: _isLogin
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                autofillHints: [
                                  _isLogin ? AutofillHints.password : AutofillHints.newPassword,
                                ],
                                onFieldSubmitted: (_) {
                                  if (_loading) return;
                                  if (_isLogin) {
                                    _submit();
                                  } else {
                                    FocusScope.of(context).nextFocus();
                                  }
                                },
                                decoration: _inputDecoration('รหัสผ่าน', Icons.lock_outline_rounded).copyWith(
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: const Color(0xFF77716C),
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                                  if (!_isLogin && value.length < 6) return 'ใช้รหัสผ่านอย่างน้อย 6 ตัวอักษร';
                                  return null;
                                },
                              ),
                              if (!_isLogin) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.newPassword],
                                  onFieldSubmitted: (_) {
                                    if (!_loading) _submit();
                                  },
                                  decoration: _inputDecoration(
                                    'ยืนยันรหัสผ่าน',
                                    Icons.lock_outline_rounded,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'แสดงรหัสผ่าน'
                                          : 'ซ่อนรหัสผ่าน',
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: const Color(0xFF77716C),
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'กรุณายืนยันรหัสผ่าน';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'รหัสผ่านไม่ตรงกัน';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              if (_isLogin)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _loading ? null : _resetPassword,
                                    style: TextButton.styleFrom(foregroundColor: _orange),
                                    child: const Text('ลืมรหัสผ่าน?'),
                                  ),
                                )
                              else
                                const SizedBox(height: 18),
                              const SizedBox(height: 4),
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _orange,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : Text(_isLogin ? 'เข้าสู่ระบบ' : 'สร้างบัญชี'),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _isLogin ? 'ยังไม่มีบัญชี?' : 'มีบัญชีอยู่แล้ว?',
                                      style: TextStyle(color: colors.onSurfaceVariant),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loading ? null : _toggleMode,
                                    style: TextButton.styleFrom(foregroundColor: _orange),
                                    child: Text(_isLogin ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'พูดคุย แบ่งปัน และเติบโตไปด้วยกัน',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
