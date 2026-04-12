import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class _OtpEntry {
  _OtpEntry({required this.otp, required this.expiresAt});

  final String otp;
  final DateTime expiresAt;
}

class OtpService {
  static const _serviceId = 'service_7s2qo1q';
  static const _templateId = 'template_n0ka7az';
  static const _publicKey = '9hNTZZ_JrPRmoU2Ne';

  static final Map<String, _OtpEntry> _otpStore = <String, _OtpEntry>{};

  static String _generateOTP() =>
      (100000 + Random().nextInt(900000)).toString();

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  // Gửi OTP qua EmailJS + lưu tạm OTP trong bộ nhớ
  static Future<void> sendOTP(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    final otp = _generateOTP();

    _otpStore[normalizedEmail] = _OtpEntry(
      otp: otp,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

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
        'template_params': {'to_email': normalizedEmail, 'otp': otp},
      }),
    );

    if (response.statusCode != 200) {
      _otpStore.remove(normalizedEmail);
      throw Exception('Gửi OTP thất bại: ${response.body}');
    }
  }

  // Xác minh OTP
  static Future<void> verifyOTP(String email, String inputOTP) async {
    final normalizedEmail = _normalizeEmail(email);
    final entry = _otpStore[normalizedEmail];

    if (entry == null) throw Exception('OTP không tồn tại');

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _otpStore.remove(normalizedEmail);
      throw Exception('OTP đã hết hạn, vui lòng gửi lại');
    }
    if (entry.otp != inputOTP) {
      throw Exception('OTP không đúng');
    }

    // Xóa OTP sau khi xác minh thành công
    _otpStore.remove(normalizedEmail);
  }
}
