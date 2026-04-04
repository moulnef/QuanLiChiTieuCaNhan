import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/finance_calculator.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/budget_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/budget_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/add_budget_form_sheet.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_item_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_summary_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_vs_actual_chart.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  void _openAddBudgetForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AddBudgetFormSheet(
          userId: 'user_001',
          onSubmit: (newBudget) {
            context.read<BudgetProvider>().addBudget(newBudget);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã thêm ngân sách cho ${newBudget.categoryName}')),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, budgetProvider, child) {
        final budgets = budgetProvider.budgets;
        final totalSpent = BudgetService.getTotalSpent(budgets: budgets);
        final totalLimit = BudgetService.getTotalLimit(budgets: budgets);
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
                    BudgetVsActualChart(budgets: budgets),
                    const SizedBox(height: 18),
                    ...budgets.map((budget) => BudgetItemCard(budget: budget)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _openAddBudgetForm,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 58),
                        side: const BorderSide(color: Color(0xFFF6B34F), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text(
                        '+  Thêm ngân sách mới',
                        style: TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BudgetHeader extends StatelessWidget {
  const _BudgetHeader({
    required this.totalSpent,
    required this.totalLimit,
    required this.totalProgress,
  });

  final int totalSpent;
  final int totalLimit;
  final int totalProgress;

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
              const Expanded(
                child: Text(
                  'Ngân Sách',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
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
