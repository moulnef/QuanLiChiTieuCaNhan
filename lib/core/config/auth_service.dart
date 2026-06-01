import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/local/category_data.dart';
import '../../domain/model/wallet_model.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const String _sampleAdminEmail = 'admin123@gmail.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('--- [AUTH SERVICE DEBUG] $message');
    }
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signOut() => _auth.signOut();

  Future<void> registerAfterOTP(String email, String password) async {
    _log('Bắt đầu đăng ký tài khoản cho email: $email');
    
    // 1. Tạo tài khoản Firebase Auth
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    // 2. Tạo document users/{userId}/profile/user_profile
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('user_profile')
        .set({
      'email': email,
      'displayName': email.split('@')[0],
      'photoURL': '',
      'emailVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
      'role': 'user',
    }, SetOptions(merge: true));

    // Ngoài ra, để tương thích ngược với code cũ mong muốn document tại users/{userId} chứa thông tin này:
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'displayName': email.split('@')[0],
      'photoURL': '',
      'emailVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
      'role': 'user',
    }, SetOptions(merge: true));

    // 3. Tạo default settings cho users/{userId}/settings/app_settings
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('app_settings')
        .set({
      'userId': uid,
      'language': 'vi',
      'currency': 'VND',
      'theme': 'system',
      'notificationsEnabled': true,
      'budgetAlertPercent': 80,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4. Tạo default wallet (Tiền mặt, balance = 0)
    final cashWallet = WalletModel(
      id: 'wallet_cash_$uid',
      userId: uid,
      name: 'Tiền mặt',
      balance: 0,
      type: 'cash',
      color: Colors.green.value,
      icon: 'cash',
      isDefault: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('wallets')
        .doc(cashWallet.id)
        .set(cashWallet.toMap());

    // 5. Tạo default categories (ăn uống, di chuyển, mua sắm...)
    final defaultCategories = CategoryData.getAllCategories();
    final batch = _firestore.batch();
    
    for (final cat in defaultCategories) {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('categories')
          .doc(cat.id);
      
      batch.set(docRef, cat.copyWith(userId: uid).toMap());
    }
    
    await batch.commit();
    _log('Khởi tạo dữ liệu người dùng mới thành công cho $uid');
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
        // Dự phòng lấy từ subcollection profile
        final profileSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('user_profile')
            .get()
            .timeout(const Duration(seconds: 5));
        
        if (profileSnapshot.exists) {
          final data = profileSnapshot.data();
          final role = data?['role'];
          if (role is String && role.trim().isNotEmpty) {
            return role.trim().toLowerCase();
          }
        }

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
