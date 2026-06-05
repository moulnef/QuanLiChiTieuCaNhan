import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      // Màu nền Galaxy nhạt đồng bộ với các màn hình Auth khác
      backgroundColor: const Color(0xFFF0F5FF),
      body: SafeArea(
        child: Stack(
          children: [
            // Nội dung chính nằm ở trung tâm
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Khung chứa file GIF được căn chỉnh tỉ lệ đều và giới hạn kích thước
                  Container(
                    width: size.width * 0.7,
                    constraints: const BoxConstraints(
                      maxWidth: 300,
                      maxHeight: 300,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Image.asset(
                      'lib/assets/intro.gif',
                      fit: BoxFit.contain,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    duration: 800.ms,
                    curve: Curves.easeOutBack,
                  ),
                  
                  const SizedBox(height: 36),
                  
                  // Tên ứng dụng với kiểu chữ Premium và hiệu ứng chuyển màu chữ
                  Text(
                    'QUẢN LÝ CHI TIÊU AI',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                        ).createShader(
                          const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0),
                        ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms),
                  
                  const SizedBox(height: 12),
                  
                  // Khẩu hiệu phụ
                  const Text(
                    'Thông minh • Bảo mật • Tiết kiệm',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms),
                ],
              ),
            ),
            
            // Một thanh tải thanh lịch nằm ở dưới cùng màn hình
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: SizedBox(
                  width: 120,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(
                      backgroundColor: Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6D28D9)),
                    ),
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(delay: 600.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
