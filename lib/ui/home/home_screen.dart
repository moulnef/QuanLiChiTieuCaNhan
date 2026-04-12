import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/all_overview_screen.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/ai_chat/chatbot.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_home_section.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/budget_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FinanceRepository _financeRepository = FinanceRepository();
  StreamSubscription<void>? _transactionChangedSubscription;

  // Biến điều khiển việc ẩn/hiện số dư
  bool _isBalanceVisible = false;

  Future<void> _reloadHomeData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'user_001';
    final currentDate = DateTime.now();
    await context.read<FinanceProvider>().refreshFinancialSummary(userId);
    await context.read<BudgetProvider>().loadMonthlyBudgets(
      userId,
      currentDate.month,
      currentDate.year,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadHomeData();

      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'user_001';
      _transactionChangedSubscription = _financeRepository
          .watchTransactions(userId)
          .listen((_) {
        if (mounted) {
          _reloadHomeData();
        }
      });
    });
  }

  @override
  void dispose() {
    _transactionChangedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oCcy = NumberFormat('#,###', 'vi_VN');

    // 👉 ĐOẠN CODE MỚI THÊM ĐỂ LẤY TÊN NGƯỜI DÙNG
    final user = FirebaseAuth.instance.currentUser;
    final String fullName = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : "bạn";
    final String firstName = fullName.split(' ').last;
    // ---------------------------------------------

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF), // Nền xanh nhạt chuẩn Galaxy
      body: Consumer2<FinanceProvider, BudgetProvider>(
        builder: (context, financeProvider, budgetProvider, _) {
          final recentTransactions = financeProvider.recentTransactions.take(5).toList();

          // Định dạng chuỗi hiển thị số tiền dựa trên việc ẩn/hiện
          String displayBalance = _isBalanceVisible
              ? "${oCcy.format(financeProvider.cashBalance)} đ"
              : "****** đ";
          String displayIncome = _isBalanceVisible
              ? "+${oCcy.format(financeProvider.totalIncome)} đ"
              : "****** đ";
          String displayExpense = _isBalanceVisible
              ? "-${oCcy.format(financeProvider.totalExpense)} đ"
              : "****** đ";

          return ListView(
            padding: const EdgeInsets.only(top: 0, bottom: 100),
            physics: const BouncingScrollPhysics(),
            children: [
              // --- 1. KHỐI HEADER GALAXY NÂNG CẤP ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    // Dòng chào hỏi & Robot AI nhỏ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 👉 ĐÃ SỬA CHỖ NÀY THÀNH TÊN ĐỘNG
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Xin chào,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text("$firstName 👋", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.yellowAccent, size: 14),
                              SizedBox(width: 4),
                              Text("Chatbot", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    // KHỐI SỐ DƯ TRUNG TÂM
                    const Text("Tổng số dư trong ví", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayBalance,
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                          child: Icon(
                            _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // KHỐI THU NHẬP & CHI TIÊU (Dạng Glass Card)
                    Row(
                      children: [
                        Expanded(
                          child: _buildGlassStatCard(
                            label: "Thu nhập",
                            value: displayIncome,
                            icon: Icons.arrow_downward_rounded,
                            color: Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildGlassStatCard(
                            label: "Chi tiêu",
                            value: displayExpense,
                            icon: Icons.arrow_upward_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- 2. PHẦN NGÂN SÁCH ---
              if (budgetProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9))),
                )
              else
                BudgetHomeSection(
                  budgets: budgetProvider.budgets,
                  onViewAll: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AllOverviewScreen()));
                  },
                ),

              // --- 3. GIAO DỊCH GẦN ĐÂY ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Giao dịch gần đây', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    TextButton(onPressed: () {}, child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFF1D4ED8)))),
                  ],
                ),
              ),

              if (recentTransactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text("Bạn chưa có giao dịch nào.", style: TextStyle(color: Colors.grey))),
                )
              else
                ...recentTransactions.map((tx) {
                  final isExpense = tx.type == 'expense';
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: isExpense ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                        child: Icon(isExpense ? Icons.remove_rounded : Icons.add_rounded, color: isExpense ? Colors.red : Colors.green),
                      ),
                      title: Text(tx.note.isNotEmpty ? tx.note : tx.categoryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(tx.transactionDate), style: const TextStyle(fontSize: 12)),
                      trailing: Text(
                        "${isExpense ? '-' : '+'}${oCcy.format(tx.amount)} đ",
                        style: TextStyle(color: isExpense ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  );
                }).toList(),
            ],
          );
        },
      ),
    );
  }

  // Widget bổ trợ vẽ thẻ Thu/Chi hiệu ứng kính
  Widget _buildGlassStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}