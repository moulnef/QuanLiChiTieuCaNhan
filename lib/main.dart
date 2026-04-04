import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 💡 KIỂM TRA ĐƯỜNG DẪN: Đảm bảo file này tồn tại trong core/config/
import 'core/config/firebase_options.dart';
import 'ui/auth/login_screen.dart';
import 'ui/home/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Khởi tạo đa ngôn ngữ
  await EasyLocalization.ensureInitialized();

  runApp(
    ProviderScope(
      child: // Trong main.dart
      EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'lib/assets/translations', // 💡 BẮT BUỘC phải có 'lib/' ở đầu
        fallbackLocale: const Locale('vi'),
        child: const MyApp(),
      ),
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

      // Cấu hình đa ngôn ngữ
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (snapshot.hasData) {
            return const MainScreen();
          }

          // 💡 LƯU Ý: Kiểm tra xem class trong login_screen.dart
          // là LoginPage hay LoginScreen để gọi cho đúng
          return const LoginPage();
        },
      ),
    );
  }
}