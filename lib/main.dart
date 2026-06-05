import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/config/firebase_options.dart';
import 'data/repository/finance_repository.dart';
import 'services/translation_service.dart';
import 'ui/auth/splash_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/home/main_screen.dart';
import 'ui/providers/auth_provider.dart';
import 'ui/providers/budget_provider.dart';
import 'ui/providers/finance_provider.dart';
import 'ui/providers/sync_provider.dart';
import 'ui/providers/notification_provider.dart';
import 'ui/providers/split_provider.dart';

void main() async {
  // 1. Khởi tạo binding cho Flutter
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Giữ status bar + navigation bar hiển thị theo kiểu edge-to-edge,
  // tránh bị vùng đen ở đáy trên một số thiết bị Android.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // 2. Khởi tạo Firebase với cấu hình chuẩn
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Khởi tạo thư viện đa ngôn ngữ
  await EasyLocalization.ensureInitialized();

  runApp(
    // Bọc ProviderScope NGOÀI CÙNG để kích hoạt Riverpod cho toàn bộ app
    ProviderScope(
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(),
          ),
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
          provider.ChangeNotifierProvider<SyncProvider>(
            create: (_) => SyncProvider(),
          ),
          provider.ChangeNotifierProvider<NotificationProvider>(
            create: (_) => NotificationProvider(),
          ),
          provider.ChangeNotifierProvider<SplitProvider>(
            create: (context) => SplitProvider(
              context.read<FinanceRepository>(),
              context.read<AuthProvider>(),
            ),
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
    return AnimatedBuilder(
      animation: TranslationService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Quản Lý Chi Tiêu AI',
          debugShowCheckedModeBanner: false,

          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
            useMaterial3: true,
          ),

          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Bắt đầu đếm ngược 3 giây để đảm bảo hiển thị đủ nội dung intro.gif
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = provider.Provider.of<AuthProvider>(context);

    Widget activeWidget;
    if (_showSplash || authProvider.isLoading) {
      activeWidget = const SplashScreen(key: ValueKey('splash'));
    } else if (authProvider.isAuthenticated) {
      activeWidget = const MainScreen(key: ValueKey('main'));
    } else {
      activeWidget = const LoginPage(key: ValueKey('login'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: activeWidget,
    );
  }
}
