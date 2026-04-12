import 'package:flutter/material.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/finance_calculator.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/database/mock/mock_budgets.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/database/mock/mock_transactions.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/budget_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_item_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_summary_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_vs_actual_chart.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/add_budget_form_sheet.dart';
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late List<Budget> _budgets;

  @override
  void initState() {
    super.initState();
    _budgets = BudgetService.getMonthlyBudgetStatus(
      transactions: MockTransactions.items,
      budgets: MockBudgets.items,
      month: 3,
      year: 2026,
    );
  }

  void _openAddBudgetForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AddBudgetFormSheet(
          userId: 'user_001',
          onSubmit: (newBudget) {
            setState(() {
              _budgets = [..._budgets, newBudget];
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đã thêm ngân sách cho ${newBudget.categoryName}',
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSpent = BudgetService.getTotalSpent(budgets: _budgets);
    final totalLimit = BudgetService.getTotalLimit(budgets: _budgets);
    final totalProgress = FinanceCalculator.calculateBudgetProgress(
      spentAmount: totalSpent,
      limitAmount: totalLimit,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _BudgetHeader(
            totalSpent: totalSpent,
            totalLimit: totalLimit,
            totalProgress: totalProgress,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                BudgetVsActualChart(
                  budgets: _budgets,
                ),
                const SizedBox(height: 18),
                ..._budgets.map((budget) => BudgetItemCard(budget: budget)),
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
          onPressed: () {},
          icon: const Icon(Icons.add, color: Colors.white, size: 34),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
      decoration: const BoxDecoration(
        color: Color(0xFFFF8500),
      ),
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

  const _FakeBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

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
