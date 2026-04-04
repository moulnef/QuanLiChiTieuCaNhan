import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpService {
  static const _serviceId  = 'service_7s2qo1q';
  static const _templateId = 'template_n0ka7az';
  static const _publicKey  = '9hNTZZ_JrPRmoU2Ne';

  static String _generateOTP() =>
      (100000 + Random().nextInt(900000)).toString();

  // Gửi OTP qua EmailJS + lưu Firestore
  static Future<void> sendOTP(String email) async {
    final otp = _generateOTP();

    // Lưu OTP vào Firestore
    await FirebaseFirestore.instance.collection('otps').doc(email).set({
      'otp': otp,
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 5)),
      ),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Gửi email qua EmailJS
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'Content-Type': 'application/json',
        'origin': 'http://localhost',
      },
      body: jsonEncode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {'to_email': email, 'otp': otp},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gửi OTP thất bại: ${response.body}');
    }
  }

  // Xác minh OTP
  static Future<void> verifyOTP(String email, String inputOTP) async {
    final doc = await FirebaseFirestore.instance
        .collection('otps')
        .doc(email)
        .get();

    if (!doc.exists) throw Exception('OTP không tồn tại');

    final data = doc.data()!;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();

    if (DateTime.now().isAfter(expiresAt)) {
      throw Exception('OTP đã hết hạn, vui lòng gửi lại');
    }
    if (data['otp'] != inputOTP) {
      throw Exception('OTP không đúng');
    }

    // Xóa OTP sau khi xác minh thành công
    await FirebaseFirestore.instance.collection('otps').doc(email).delete();
  }
}