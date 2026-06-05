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
    _log('Báº¯t Ä‘áº§u Ä‘Äƒng kÃ½ tÃ i khoáº£n cho email: $email');

    // 1. Táº¡o tÃ i khoáº£n Firebase Auth
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    // 2. Táº¡o document users/{userId}/profile/user_profile
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

    // NgoÃ i ra, Ä‘á»ƒ tÆ°Æ¡ng thÃ­ch ngÆ°á»£c vá»›i code cÅ© mong muá»‘n document táº¡i users/{userId} chá»©a thÃ´ng tin nÃ y:
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'displayName': email.split('@')[0],
      'photoURL': '',
      'emailVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
      'role': 'user',
    }, SetOptions(merge: true));

    // 3. Táº¡o default settings cho users/{userId}/settings/app_settings
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

    // 4. Táº¡o default wallet (Tiá»n máº·t, balance = 0)
    final cashWallet = WalletModel(
      id: 'wallet_cash_$uid',
      userId: uid,
      name: 'Tiá»n máº·t',
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

    // 5. Táº¡o default categories (Äƒn uá»‘ng, di chuyá»ƒn, mua sáº¯m...)
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
    _log('Khá»Ÿi táº¡o dá»¯ liá»‡u ngÆ°á»i dÃ¹ng má»›i thÃ nh cÃ´ng cho $uid');
  }

  Future<String?> login(String email, String password) async {
    try {
      _log('1. Báº¯t Ä‘áº§u signInWithEmailAndPassword: ${DateTime.now()}');
      final credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      _log('2. Firebase Auth pháº£n há»“i: ${DateTime.now()}');

      return credential.user == null
          ? 'KhÃ´ng thá»ƒ xÃ¡c thá»±c ngÆ°á»i dÃ¹ng.'
          : null;
    } on FirebaseAuthException catch (e) {
      _log(
        'Lá»—i Firebase Auth: ${e.code} - ${e.message ?? 'no-message'} vÃ o lÃºc ${DateTime.now()}',
      );
      if (e.code == 'user-not-found') {
        return 'KhÃ´ng tÃ¬m tháº¥y tÃ i khoáº£n nÃ y.';
      }
      if (e.code == 'wrong-password') {
        return 'Máº­t kháº©u khÃ´ng chÃ­nh xÃ¡c.';
      }
      return e.message ?? 'ÄÃ£ cÃ³ lá»—i xáº£y ra';
    } on TimeoutException {
      _log('Timeout Ä‘Äƒng nháº­p Firebase Auth táº¡i ${DateTime.now()}');
      return 'ÄÄƒng nháº­p quÃ¡ thá»i gian chá». Vui lÃ²ng kiá»ƒm tra máº¡ng vÃ  thá»­ láº¡i.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> getUserRole(String uid) async {
    try {
      _log('3. Báº¯t Ä‘áº§u láº¥y role tá»« Firestore: ${DateTime.now()}');
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      _log('4. Firestore tráº£ vá» role snapshot: ${DateTime.now()}');

      if (!snapshot.exists) {
        // Dá»± phÃ²ng láº¥y tá»« subcollection profile
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
          '5. Role há»£p lá»‡ = ${role.trim().toLowerCase()} táº¡i ${DateTime.now()}',
        );
        return role.trim().toLowerCase();
      }

      _log(
        '5. Role rá»—ng hoáº·c khÃ´ng há»£p lá»‡, fallback user táº¡i ${DateTime.now()}',
      );
      return 'user';
    } catch (_) {
      _log(
        'Lá»—i/timeout khi láº¥y role, fallback theo email táº¡i ${DateTime.now()}',
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
