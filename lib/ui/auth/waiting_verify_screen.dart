import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../home/main_screen.dart';

class WaitingVerifyScreen extends StatefulWidget {
  final String email;
  final String password;
  const WaitingVerifyScreen({
    required this.email,
    required this.password,
    super.key,
  });

  @override
  State<WaitingVerifyScreen> createState() => _WaitingVerifyScreenState();
}

class _WaitingVerifyScreenState extends State<WaitingVerifyScreen> {
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Cứ 3 giây kiểm tra 1 lần xem user đã xác minh chưa
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerified(),
    );
  }

  Future<void> _checkVerified() async {
    try {
      // Đăng nhập lại để kiểm tra trạng thái mới nhất
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          );

      await userCredential.user?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        _timer?.cancel();
        if (mounted) {
          // Đã xác minh thành công -> Vào app!
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      } else {
        // Nếu chưa xác minh, đăng xuất ngay để giữ trạng thái sạch
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      // Bỏ qua lỗi login liên tục nếu server chưa cập nhật kịp
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          );
      await userCredential.user?.sendEmailVerification();
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã gửi lại email xác minh!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon email
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EAF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 64,
                  color: Color(0xFF1a237e),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Kiểm tra hộp thư!",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "Chúng tôi đã gửi link xác minh đến\n${widget.email}\n\nSau khi click link, app sẽ tự động chuyển trang.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              // Loading indicator — đang chờ xác minh
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1a237e),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isResending ? "Đang gửi lại..." : "Đang chờ xác minh...",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Nút gửi lại
              OutlinedButton.icon(
                onPressed: _isResending ? null : _resendEmail,
                icon: const Icon(Icons.send, size: 18),
                label: const Text("Gửi lại email"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1a237e),
                  side: const BorderSide(color: Color(0xFF1a237e)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Quay lại màn hình đăng ký",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
