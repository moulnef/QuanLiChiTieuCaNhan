import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/config/firebase_options.dart';
import 'ui/auth/login_screen.dart';
import 'ui/home/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
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
      // StreamBuilder giúp tự động nhận biết trạng thái đăng nhập
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            final user = snapshot.data;
            if (user != null && user.emailVerified) {
              return const MainScreen(); // Đã xác minh -> Vào App
            } else {
              // Note: Nếu user đã đăng nhập nhưng chưa verify qua Stream này,
              // ta sẽ thực hiện logout để đồng nhất flow chuyển hướng thủ công trong WaitingScreen
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }
          }
          return const LoginPage(); // Nếu chưa đăng nhập -> trang đăng nhập
        },
      ),
    );
  }
}
