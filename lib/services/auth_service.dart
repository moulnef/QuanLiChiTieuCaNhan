import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const String _sampleAdminEmail = 'admin123@gmail.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('--- [AUTH DEBUG] $message');
    }
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signOut() => _auth.signOut();

  Future<void> registerAfterOTP(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'displayName': email.split('@')[0],
      'photoURL': '',
      'emailVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
      'role': 'user',
    }, SetOptions(merge: true));
  }

  Future<String?> login(String email, String password) async {
    try {
      _log('1. Bắt đầu signInWithEmailAndPassword: ${DateTime.now()}');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 15));
      _log('2. Firebase Auth phản hồi: ${DateTime.now()}');

      return credential.user == null ? 'Không thể xác thực người dùng.' : null;
    } on FirebaseAuthException catch (e) {
      _log(
        'Lỗi Firebase Auth: ${e.code} - ${e.message ?? 'no-message'} vào lúc ${DateTime.now()}',
      );
      if (e.code == 'user-not-found') {
        return 'Không tìm thấy tài khoản này.';
      }
      if (e.code == 'wrong-password') {
        return 'Mật khẩu không chính xác.';
      }
      return e.message ?? 'Đã có lỗi xảy ra';
    } on TimeoutException {
      _log('Timeout đăng nhập Firebase Auth tại ${DateTime.now()}');
      return 'Đăng nhập quá thời gian chờ. Vui lòng kiểm tra mạng và thử lại.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> getUserRole(String uid) async {
    try {
      _log('3. Bắt đầu lấy role từ Firestore: ${DateTime.now()}');
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      _log('4. Firestore trả về role snapshot: ${DateTime.now()}');

      if (!snapshot.exists) {
        return _auth.currentUser?.email?.toLowerCase() == _sampleAdminEmail
            ? 'admin'
            : 'user';
      }

      final data = snapshot.data();
      final role = data?['role'];

      if (role is String && role.trim().isNotEmpty) {
        _log(
          '5. Role hợp lệ = ${role.trim().toLowerCase()} tại ${DateTime.now()}',
        );
        return role.trim().toLowerCase();
      }

      _log(
        '5. Role rỗng hoặc không hợp lệ, fallback user tại ${DateTime.now()}',
      );
      return 'user';
    } catch (_) {
      _log(
        'Lỗi/timeout khi lấy role, fallback theo email tại ${DateTime.now()}',
      );
      return _auth.currentUser?.email?.toLowerCase() == _sampleAdminEmail
          ? 'admin'
          : 'user';
    }
  }

  Future<bool> isAdmin(String uid) async {
    return (await getUserRole(uid)) == 'admin';
  }
}
