import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/config/otp_auth_service.dart'; // Import service mới
import '../home/main_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final String password;

  const OTPVerificationScreen({
    required this.email,
    required this.password,
    super.key,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String _errorText = '';

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyAndSignUp() async {
    String enteredOtp = _controllers.map((c) => c.text).join();
    
    if (enteredOtp.length < 6) {
      setState(() => _errorText = 'Vui lòng nhập đủ 6 chữ số');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      // 1. Xác thực OTP từ Firestore
      final isOtpValid = await OtpAuthService.verifyOTP(widget.email, enteredOtp);

      if (!isOtpValid) {
        setState(() => _errorText = 'Mã OTP không chính xác. Vui lòng thử lại.');
        return;
      }

      // 2. CHỈ KHI OTP ĐÚNG -> MỚI TẠO ACCOUNT FIREBASE
      final userCredential = await OtpAuthService.registerUser(widget.email, widget.password);

      if (userCredential.user != null) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() => _errorText = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Nút gửi lại OTP mới
  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      await OtpAuthService.sendOTP(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi lại mã OTP mới!')),
        );
      }
    } catch (e) {
      setState(() => _errorText = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 24),
            Text(
              'Nhập mã OTP đã được gửi đến\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _focusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                      if (enteredOtpComplete()) {
                        _verifyAndSignUp();
                      }
                    },
                  ),
                );
              }),
            ),
            if (_errorText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_errorText, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _verifyAndSignUp,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('XÁC NHẬN & ĐĂNG KÝ'),
                  ),
          ],
        ),
      ),
    );
  }

  bool enteredOtpComplete() {
    return _controllers.every((c) => c.text.isNotEmpty);
  }
}
