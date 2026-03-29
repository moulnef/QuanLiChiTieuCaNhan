import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text("Trang chủ", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      // ĐỂ TRỐNG HOÀN TOÀN, KHÔNG HIỂN THỊ BẤT CỨ DỮ LIỆU GIAO DỊCH NÀO
      body: const Center(
        child: Text(
          "Trang chủ trống",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }
}