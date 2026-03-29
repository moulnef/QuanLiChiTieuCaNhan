import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Quan trọng: Để hiểu User và FirebaseAuth
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import các file cấu hình và giao diện của bạn
import 'core/config/firebase_options.dart';
import 'ui/auth/login_screen.dart';      // Đường dẫn tới trang Login
import 'ui/home/main_screen.dart';      // Đường dẫn tới trang Main (có thanh điều hướng)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // ProviderScope phải bao bọc toàn bộ App để dùng được Riverpod
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Chi Tiêu AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),

      // LOGIC KIỂM TRA ĐĂNG NHẬP REALTIME
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Trong lúc chờ Firebase phản hồi trạng thái
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 2. Nếu đã đăng nhập (Token còn hạn hoặc vừa Login xong)
          if (snapshot.hasData) {
            return const MainScreen();
          }

          // 3. Nếu chưa đăng nhập hoặc đã Logout
          return const LoginPage();
        },
      ),
    );
  }
}