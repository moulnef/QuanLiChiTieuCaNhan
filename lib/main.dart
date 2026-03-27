import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ui/auth/login_screen.dart';
import 'ui/home/main_screen.dart';

void main() async {
  // Cực kỳ quan trọng: Khởi tạo binding cho Flutter và các dịch vụ nền
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase (vì bạn có dùng FirebaseAuth bên dưới)
  await Firebase.initializeApp();

  // Khởi tạo thư viện đa ngôn ngữ
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      // Dựa trên cấu trúc folder trong ảnh của bạn: lib/assets/translations
      supportedLocales: const [Locale('vi'), Locale('en')],
      path: 'lib/assets/translations',
      fallbackLocale: const Locale('vi'),
      child: const MyApp(),
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

      // --- PHẦN BỔ SUNG BẮT BUỘC CHO EASY_LOCALIZATION ---
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      // --------------------------------------------------

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),

      // LOGIC CỦA BẠN: StreamBuilder tự động nhận biết trạng thái đăng nhập
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // NẾU CÓ DỮ LIỆU USER ĐĂNG NHẬP -> VÀO THẲNG MAIN SCREEN
          if (snapshot.hasData) {
            return const MainScreen();
          }

          // NẾU CHƯA ĐĂNG NHẬP HOẶC ĐÃ ĐĂNG XUẤT -> VỀ TRANG LOGIN
          return const LoginPage();
        },
      ),
    );
  }
}