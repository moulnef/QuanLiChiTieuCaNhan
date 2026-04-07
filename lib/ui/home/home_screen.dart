import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Các import chuyển hướng trang
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/all_overview_screen.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/database/mock/mock_budgets.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/budget_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_home_section.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/ai_chat/chatbot.dart';

// Import Model chuẩn của Thúy
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestoreService = FirestoreService();

  // MẶC ĐỊNH LÀ FALSE: Mới vào sẽ ẩn số dư ngay
  bool _isBalanceVisible = false;

  @override
  Widget build(BuildContext context) {
    // Ngân sách tạm thời lấy từ Mock (Sau này Thúy có thể sửa thành Stream từ Firebase luôn nhé)
    final updatedBudgets = BudgetService.getMonthlyBudgetStatus(
      transactions: [], // Để trống vì mình sẽ dùng dữ liệu thật từ Firebase bên dưới
      budgets: MockBudgets.items,
      month: 3,
      year: 2026,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getTransactions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Đã có lỗi xảy ra"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 1. CHUYỂN ĐỔI DỮ LIỆU TỪ FIREBASE SANG LIST MODEL
          final List<TransactionModel> transactions = snapshot.data?.docs.map((doc) {
            return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList() ?? [];

          // 2. TÍNH TOÁN TỔNG THU / TỔNG CHI / SỐ DƯ
          double totalIncome = 0;
          double totalExpense = 0;

          for (var tx in transactions) {
            if (tx.type == 'income') {
              totalIncome += tx.amount;
            } else {
              totalExpense += tx.amount;
            }
          }

          final balance = totalIncome - totalExpense;
          final oCcy = NumberFormat('#,###', 'en_US');

          // Xử lý chuỗi hiển thị dựa trên trạng thái _isBalanceVisible
          String formattedBalance = _isBalanceVisible ? "${oCcy.format(balance).replaceAll(',', '.')} đ" : "****** đ";
          String formattedIncome = _isBalanceVisible ? "${oCcy.format(totalIncome).replaceAll(',', '.')} đ" : "****** đ";
          String formattedExpense = _isBalanceVisible ? "${oCcy.format(totalExpense).replaceAll(',', '.')} đ" : "****** đ";

          return ListView(
            padding: const EdgeInsets.only(top: 0, bottom: 100),
            physics: const BouncingScrollPhysics(),
            children: [
              // --- 1. KHỐI HEADER XANH ---
              Container(
                padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Xin chào,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Lấy tên User thật từ Firebase Auth nếu có
                                Text(
                                    FirebaseAuth.instance.currentUser?.displayName ?? "Nguyễn Văn An",
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                                ),
                                const SizedBox(width: 8),
                                const Text("👋", style: TextStyle(fontSize: 20)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                              child: const Row(children: [Icon(Icons.wifi, color: Colors.greenAccent, size: 14), SizedBox(width: 4), Text("Online", style: TextStyle(color: Colors.white, fontSize: 12))]),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => FirebaseAuth.instance.signOut(),
                              child: const Icon(Icons.logout, color: Colors.white, size: 24),
                            )
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text("Tổng số dư khả dụng", style: TextStyle(color: Colors.white70, fontSize: 15)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(formattedBalance, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                              _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: Colors.white70,
                              size: 28
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(child: _buildGlassCard("Thu nhập", "+$formattedIncome", Icons.trending_up, Colors.greenAccent)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildGlassCard("Chi tiêu", "-$formattedExpense", Icons.trending_down, Colors.redAccent)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // --- 3. NGÂN SÁCH ---
              BudgetHomeSection(
                budgets: updatedBudgets,
                onViewAll: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AllOverviewScreen()));
                },
              ),

              // --- 4. GIAO DỊCH GẦN ĐÂY ---
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

              if (transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text("Bạn chưa có chi tiêu nào. Hãy thêm ngay!")),
                )
              else
                ...transactions.take(5).map((tx) {
                  final isExpense = tx.type == 'expense';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    color: Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: const Color(0xFFF0F2FF),
                          child: Icon(isExpense ? Icons.receipt_long : Icons.payments, color: Colors.blue)
                      ),
                      title: Text(tx.categoryId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                      subtitle: Text(tx.note),
                      trailing: Text(
                          "${isExpense ? '-' : '+'}${oCcy.format(tx.amount).replaceAll(',', '.')} đ",
                          style: TextStyle(color: isExpense ? Colors.red : Colors.green, fontWeight: FontWeight.bold)
                      ),
                      onLongPress: () => _firestoreService.deleteTransaction(tx.id),
                    ),
                  );
                }).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassCard(String title, String amount, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}