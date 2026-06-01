import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/finance_calculator.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/budget_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_item_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_summary_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_vs_actual_chart.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/add_budget_form_sheet.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/budget_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'user_001';

  void _openAddBudgetForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AddBudgetFormSheet(
          userId: _currentUserId,
          onSubmit: (newBudget) async {
            try {
              await context.read<BudgetProvider>().addBudget(newBudget);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã thêm ngân sách cho ${newBudget.categoryName}',
                  ),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
              );
            }
          },
        );
      },
    );
  }

  void _openEditBudgetForm(Budget budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AddBudgetFormSheet(
          userId: _currentUserId,
          budget: budget,
          onSubmit: (updatedBudget) async {
            try {
              await context.read<BudgetProvider>().updateBudget(updatedBudget);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã cập nhật ngân sách cho ${updatedBudget.categoryName}',
                  ),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
              );
            }
          },
        );
      },
    );
  }

  Future<bool?> _confirmDelete(Budget budget) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Xác nhận xóa',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa ngân sách cho danh mục "${budget.categoryName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<FinanceRepository>();
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<Budget>>(
        stream: repository.streamBudgets(_currentUserId, now.month, now.year),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final budgets = snapshot.data ?? [];
          final totalSpent = BudgetService.getTotalSpent(budgets: budgets);
          final totalLimit = BudgetService.getTotalLimit(budgets: budgets);
          final totalProgress = FinanceCalculator.calculateBudgetProgress(
            spentAmount: totalSpent,
            limitAmount: totalLimit,
          );

          return Column(
            children: [
              _BudgetHeader(
                totalSpent: totalSpent,
                totalLimit: totalLimit,
                totalProgress: totalProgress,
              ),
              Expanded(
                child: budgets.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                        children: [
                          BudgetVsActualChart(budgets: budgets),
                          const SizedBox(height: 18),
                          ...budgets.map((budget) {
                            return Dismissible(
                              key: Key(budget.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) =>
                                  _confirmDelete(budget),
                              onDismissed: (direction) async {
                                try {
                                  await context
                                      .read<BudgetProvider>()
                                      .deleteBudget(budget.id, _currentUserId);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã xóa ngân sách của ${budget.categoryName}',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Không thể xóa: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () => _openEditBudgetForm(budget),
                                child: BudgetItemCard(budget: budget),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _openAddBudgetForm,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 58),
                              side: const BorderSide(
                                color: Color(0xFFF6B34F),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                            child: const Text(
                              '+  Thêm ngân sách mới',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _FakeBottomNav(
        currentIndex: 3,
        onTap: (index) {
          Navigator.pop(context);
        },
      ),
      floatingActionButton: Container(
        width: 68,
        height: 68,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.blue,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          onPressed: _openAddBudgetForm,
          icon: const Icon(Icons.add, color: Colors.white, size: 34),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 68,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có ngân sách nào cho tháng này.\nHãy thiết lập để kiểm soát chi tiêu tốt hơn!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openAddBudgetForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Thiết lập ngân sách ngay'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetHeader extends StatelessWidget {
  final int totalSpent;
  final int totalLimit;
  final int totalProgress;

  const _BudgetHeader({
    required this.totalSpent,
    required this.totalLimit,
    required this.totalProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
      decoration: const BoxDecoration(color: Color(0xFFFF8500)),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Ngân Sách',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          BudgetSummaryCard(
            totalSpent: totalSpent,
            totalLimit: totalLimit,
            progressPercent: totalProgress,
          ),
        ],
      ),
    );
  }
}

class _FakeBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FakeBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      child: SizedBox(
        height: 74,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Trang chủ',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.swap_horiz_rounded,
              label: 'Giao dịch',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            const SizedBox(width: 32),
            _NavItem(
              icon: Icons.show_chart_rounded,
              label: 'Tài chính',
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Thống kê',
              selected: currentIndex == 4,
              onTap: () => onTap(4),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              label: 'Hồ sơ',
              selected: currentIndex == 5,
              onTap: () => onTap(5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.blue : const Color(0xFF9CA3AF);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
