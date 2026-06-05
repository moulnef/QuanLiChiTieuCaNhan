import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/local/category_data.dart';
import '../../domain/model/wallet_model.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const String _sampleAdminEmail = 'admin123@gmail.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('--- [AUTH SERVICE DEBUG] $message');
    }
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Vui lòng nhập email hợp lệ.',
      );
    }

    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  Future<void> registerAfterOTP(String email, String password) async {
    _log('Bắt đầu đăng ký tài khoản cho email: $email');

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    await _initializeUserData(
      uid: uid,
      email: email,
      displayName: email.split('@')[0],
      photoURL: '',
      markNeedsTutorial: true,
    );
    _log('Khởi tạo dữ liệu người dùng mới thành công cho $uid');
  }

  Future<String?> signInWithGoogle() async {
    try {
      UserCredential result;
      String fallbackEmail = '';
      String fallbackName = '';
      String fallbackPhoto = '';

      if (kIsWeb) {
        result = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return 'Đã hủy đăng nhập Google.';
        }

        fallbackEmail = googleUser.email;
        fallbackName = googleUser.displayName ?? googleUser.email;
        fallbackPhoto = googleUser.photoUrl ?? '';

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        result = await _auth.signInWithCredential(credential);
      }

      final user = result.user;
      if (user == null) {
        return 'Không thể xác thực tài khoản Google.';
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final isNewUser = result.additionalUserInfo?.isNewUser == true;
      if (isNewUser || !userDoc.exists) {
        await _initializeUserData(
          uid: user.uid,
          email: user.email ?? fallbackEmail,
          displayName: user.displayName ?? fallbackName,
          photoURL: user.photoURL ?? fallbackPhoto,
          markNeedsTutorial: isNewUser,
        );
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Không thể đăng nhập bằng Google.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _initializeUserData({
    required String uid,
    required String email,
    required String displayName,
    required String photoURL,
    required bool markNeedsTutorial,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('user_profile')
        .set({
          'email': email,
          'displayName': displayName,
          'photoURL': photoURL,
          'emailVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': uid,
          'role': 'user',
          'needsTutorial': markNeedsTutorial,
        }, SetOptions(merge: true));

    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'emailVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
      'role': 'user',
      'needsTutorial': markNeedsTutorial,
    }, SetOptions(merge: true));

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
  }

  Future<String?> login(String email, String password) async {
    try {
      _log('1. Bắt đầu signInWithEmailAndPassword: ${DateTime.now()}');
      final credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
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
