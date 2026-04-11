import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'core/config/firebase_options.dart';
import 'data/repository/finance_repository.dart';
import 'ui/auth/login_screen.dart';
import 'ui/home/main_screen.dart';
import 'ui/providers/budget_provider.dart';
import 'ui/providers/finance_provider.dart';

void main() async {
  // 1. Khởi tạo binding cho Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Khởi tạo Firebase với cấu hình chuẩn
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Khởi tạo thư viện đa ngôn ngữ
  await EasyLocalization.ensureInitialized();

  runApp(
    // Bọc ProviderScope NGOÀI CÙNG để kích hoạt Riverpod cho toàn bộ app
    ProviderScope(
      child: provider.MultiProvider(
        providers: [
          provider.Provider<FinanceRepository>(
            create: (_) => FinanceRepository(),
          ),
          provider.ChangeNotifierProvider<FinanceProvider>(
            create: (context) =>
                FinanceProvider(context.read<FinanceRepository>()),
          ),
          provider.ChangeNotifierProvider<BudgetProvider>(
            create: (context) =>
                BudgetProvider(context.read<FinanceRepository>()),
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('vi'), Locale('en')],
          path:
              'lib/assets/translations', // Đường dẫn folder chứa file json của bạn
          fallbackLocale: const Locale('vi'),
          child: const MyApp(),
        ),
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

      // --- CẤU HÌNH ĐA NGÔN NGỮ (BẮT BUỘC) ---
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),

      // LOGIC KIỂM TRA ĐĂNG NHẬP REALTIME
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Trong lúc chờ Firebase phản hồi
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Nếu đã đăng nhập thành công -> Vào thẳng MainScreen
          if (snapshot.hasData) {
            return const MainScreen();
          }

          // Nếu chưa đăng nhập hoặc đã Logout -> Về trang Login
          return const LoginPage();
        },
      ),
    );
  }
}
