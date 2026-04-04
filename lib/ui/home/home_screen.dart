import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/all_overview_screen.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/budget_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/budget_provider.dart';
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
      body: Consumer<BudgetProvider>(
        builder: (context, budgetProvider, _) {
          return StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getTransactions(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Đã có lỗi xảy ra"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data?.docs ?? [];

              return ListView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 150,
                ),
                children: [
                  const SizedBox(height: 18),
                  // Banner Gradient
                  Container(
                    height: 160,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2E4BFF), Color(0xFF6A35FF)]),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E4BFF).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Tổng chi tiêu tháng này', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(docs.fold(0.0, (sum, doc) => sum + (doc['amount'] as num))),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  // AI Assistant Banner
                  _buildAiBanner(budgetProvider),

                  const SizedBox(height: 18),
                  // Ngân sách tháng này (Dữ liệu từ Provider)
                  BudgetHomeSection(
                    budgets: budgetProvider.budgets,
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
                    ...docs.take(10).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Color(0xFFF0F2FF), child: Icon(Icons.receipt_long, color: Colors.blue)),
                          title: Text(data['title'] ?? 'Không tên', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text("${data['category']} - ${data['note'] ?? ''}"),
                          trailing: Text("-${NumberFormat("#,###").format(data['amount'])} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          onLongPress: () => _firestoreService.deleteTransaction(doc.id),
                        ),
                      );
                    }).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAiBanner(BudgetProvider provider) {
    // Lấy cảnh báo từ BudgetService
    final alert = BudgetService.getPrimaryBudgetAlert(provider.budgets);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
              children: [
                const Text('AI Financial Assistant', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  alert ?? 'Bạn đang quản lý chi tiêu rất tốt!',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white, size: 24),
        ],
      ),
    );
  }
}
