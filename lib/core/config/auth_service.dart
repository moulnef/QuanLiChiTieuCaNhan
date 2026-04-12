import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // Tạo account Firebase SAU KHI OTP đúng
  static Future<void> registerAfterOTP(String email, String password) async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    final uid = credential.user!.uid;

    // Lưu thông tin user vào Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'email': email,
      'displayName': email.split('@')[0], // Lấy phần trước @ làm tên hiển thị mặc định
      'photoURL': '',
      'emailVerified': true,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
    });
  }
}