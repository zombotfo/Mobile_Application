import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) return;

    await user.updateDisplayName(username.trim());
    // สร้างเอกสารโปรไฟล์ใน Firestore คู่กับบัญชี Auth ไว้เก็บข้อมูล
    // เพิ่มเติม (username, karma) ที่ Firebase Auth เก็บเองไม่ได้
    await _firestoreService.createUserProfile(
      uid: user.uid,
      username: username.trim(),
      email: email.trim(),
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  /// แปลง error code ของ Firebase เป็นข้อความที่ผู้ใช้เข้าใจ
  static String errorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'user-disabled':
        return 'บัญชีนี้ถูกปิดการใช้งาน';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้สมัครไปแล้ว ลองเข้าสู่ระบบแทน';
      case 'weak-password':
        return 'รหัสผ่านสั้นเกินไป ใช้อย่างน้อย 6 ตัวอักษร';
      case 'too-many-requests':
        return 'ลองหลายครั้งเกินไป รอสักครู่แล้วลองใหม่';
      case 'network-request-failed':
        return 'เชื่อมต่ออินเทอร์เน็ตไม่ได้ ตรวจสอบสัญญาณแล้วลองใหม่';
      default:
        return 'เกิดข้อผิดพลาด (${e.code})';
    }
  }
}
