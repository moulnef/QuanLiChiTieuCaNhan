import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const String _sampleAdminEmail = 'admin123@gmail.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return 'Không thể xác thực người dùng.';
      }

      return getUserRole(user.uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'Không tìm thấy tài khoản này.';
      }
      if (e.code == 'wrong-password') {
        return 'Mật khẩu không chính xác.';
      }
      return e.message ?? 'Đã có lỗi xảy ra';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> getUserRole(String uid) async {
    await _seedSampleAdminIfNeeded();

    final snapshot = await _firestore.collection('users').doc(uid).get();

    if (!snapshot.exists) {
      return _auth.currentUser?.email?.toLowerCase() == _sampleAdminEmail
          ? 'admin'
          : 'user';
    }

    final data = snapshot.data();
    final role = data?['role'];

    if (role is String && role.trim().isNotEmpty) {
      return role.trim().toLowerCase();
    }

    return 'user';
  }

  Future<bool> isAdmin(String uid) async {
    return (await getUserRole(uid)) == 'admin';
  }

  Future<void> _seedSampleAdminIfNeeded() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase();

    if (user == null || email != _sampleAdminEmail) {
      return;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': user.email?.split('@').first ?? 'admin',
      'photoURL': user.photoURL ?? '',
      'emailVerified': user.emailVerified,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': user.uid,
      'role': 'admin',
      'seededAsAdmin': true,
    }, SetOptions(merge: true));
  }
}
