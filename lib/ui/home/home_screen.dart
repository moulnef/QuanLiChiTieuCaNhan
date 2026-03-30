import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/all_overview_screen.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/database/mock/mock_budgets.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/database/mock/mock_transactions.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/budget_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_home_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    // Tính toán ngân sách từ mock data (tháng 3/2026 như bạn đặt)
    final updatedBudgets = BudgetService.getMonthlyBudgetStatus(
      transactions: MockTransactions.items,
      budgets: MockBudgets.items,
      month: 3,
      year: 2026,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Quản lý chi tiêu AI", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getTransactions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Đã có lỗi xảy ra"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.only(bottom: 100), // Khoảng trống cho FAB
            children: [
              const SizedBox(height: 18),
              // Banner Gradient
              Container(
                height: 160,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2E4BFF), Color(0xFF6A35FF)]),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),

              const SizedBox(height: 18),
              // AI Assistant Banner
              Container(
                height: 92,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B3DFF), Color(0xFFD91CFF)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0x33FFFFFF),
                      child: Text('🤖', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('AI Financial Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          SizedBox(height: 4),
                          Text('Bạn đã chi quá 71% ngân sách ăn uống', style: TextStyle(fontSize: 13, color: Colors.white)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              // Ngân sách tháng này
              BudgetHomeSection(
                budgets: updatedBudgets,
                onViewAll: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AllOverviewScreen()));
                },
              ),

              // Giao dịch gần đây
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giao dịch gần đây', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () {}, child: const Text('Xem tất cả')),
                  ],
                ),
              ),

              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text("Bạn chưa có chi tiêu nào. Hãy thêm ngay!")),
                )
              else
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFF0F2FF), child: Icon(Icons.receipt_long, color: Colors.blue)),
                      title: Text(data['title'] ?? 'Không tên', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text("${data['category']} - ${data['note'] ?? ''}"),
                      trailing: Text("-${data['amount']} VNĐ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      onLongPress: () => _firestoreService.deleteTransaction(doc.id),
                    ),
                  );
                }).toList(),
            ],
          );
        },
      ),
    );
  }
}