import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class OtpAuthService {
  // TODO: Thay các thông tin này từ tài khoản EmailJS của bạn
  static const String _serviceId = 'YOUR_SERVICE_ID';
  static const String _templateId = 'YOUR_TEMPLATE_ID';
  static const String _publicKey = 'YOUR_PUBLIC_KEY';

  // 1. Gửi OTP qua EmailJS và lưu vào Firestore để xác thực
  static Future<String> sendOTP(String email) async {
    // Tạo mã OTP 6 số
    final String otp = (100000 + Random().nextInt(900000)).toString();
    final DateTime expiresAt = DateTime.now().add(const Duration(minutes: 5));

    try {
      // Lưu OTP vào Firestore để kiểm tra bảo mật (không thể sửa ở client)
      await FirebaseFirestore.instance.collection('otps').doc(email).set({
        'otp': otp,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Gọi API EmailJS để gửi email thực
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost', // EmailJS yêu cầu origin
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {'to_email': email, 'otp': otp},
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("EmailJS Error: ${response.body}");
        throw Exception('Không thể gửi email OTP. Vui lòng thử lại sau.');
      }

      return otp; // Trả về để màn hình UI biết đã gửi thành công
    } catch (e) {
      debugPrint("sendOTP Error: $e");
      rethrow;
    }
  }

  // 2. Xác thực OTP từ người dùng nhập vào
  static Future<bool> verifyOTP(String email, String inputOtp) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('otps')
          .doc(email)
          .get();

      if (!doc.exists) {
        throw Exception('Mã OTP không tồn tại hoặc đã bị xóa.');
      }

      final data = doc.data()!;
      final String serverOtp = data['otp'];
      final DateTime expiresAt = (data['expiresAt'] as Timestamp).toDate();

      // Kiểm tra hết hạn
      if (DateTime.now().isAfter(expiresAt)) {
        await FirebaseFirestore.instance.collection('otps').doc(email).delete();
        throw Exception('Mã OTP đã hết hạn (sau 5 phút).');
      }

      // Kiểm tra khớp mã
      if (serverOtp != inputOtp) {
        return false;
      }

      // OTP đúng -> Xóa OTP khỏi Firestore để không dùng lại được
      await FirebaseFirestore.instance.collection('otps').doc(email).delete();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // 3. Chính thức tạo tài khoản Firebase SAU KHI OTP đúng
  static Future<UserCredential> registerUser(
    String email,
    String password,
  ) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Lưu thêm thông tin user vào Firestore nếu cần
      if (credential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'email': email,
              'createdAt': FieldValue.serverTimestamp(),
              'emailVerified': true, // Chúng ta coi như đã verified qua OTP
            });
      }

      return credential;
    } catch (e) {
      rethrow;
    }
  }
}
