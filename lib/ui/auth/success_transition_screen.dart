import 'package:flutter/material.dart';
import 'dart:async';
import '../home/main_screen.dart'; // Nhớ kiểm tra lại đường dẫn import MainScreen của bạn nhé

class SuccessTransitionScreen extends StatefulWidget {
  const SuccessTransitionScreen({super.key});

  @override
  State<SuccessTransitionScreen> createState() => _SuccessTransitionScreenState();
}

class _SuccessTransitionScreenState extends State<SuccessTransitionScreen> {
  @override
  void initState() {
    super.initState();
    // Đếm ngược 5 giây sau đó tự động chuyển sang MainScreen
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false, // Xóa toàn bộ lịch sử trang trước đó (không cho back lại màn GIF)
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Giữ màu nền đồng bộ với app (màu Galaxy nhạt) để file GIF (đã tách nền) hòa vào mượt mà
      backgroundColor: const Color(0xFFF0F5FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Chèn file GIF đã khai báo trong pubspec.yaml
            Image.asset(
              'lib/ui/ai_chat/hello.gif',
              width: 200, // Tùy chỉnh kích thước cho phù hợp
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}