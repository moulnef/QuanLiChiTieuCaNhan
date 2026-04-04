import '../../core/utils/date_helper.dart';
import '../../core/utils/finance_calculator.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';

class BudgetService {
  static List<TransactionModel> getMonthlyExpenseTransactions({
    required List<TransactionModel> transactions,
    required int month,
    required int year,
  }) {
    return transactions.where((tx) {
      return tx.type == 'expense' &&
          DateHelper.isInMonth(
            timestamp: tx.transactionDate.millisecondsSinceEpoch,
            month: month,
            year: year,
          );
    }).toList();
  }

  static Map<String, int> groupExpenseByCategory({
    required List<TransactionModel> transactions,
  }) {
    final Map<String, int> result = {};

    for (final tx in transactions) {
      final current = result[tx.categoryId] ?? 0;
      result[tx.categoryId] = current + tx.amount.toInt();
    }

    return result;
  }

  static List<Budget> getMonthlyBudgetStatus({
    required List<TransactionModel> transactions,
    required List<Budget> budgets,
    required int month,
    required int year,
  }) {
    final monthlyExpenses = getMonthlyExpenseTransactions(
      transactions: transactions,
      month: month,
      year: year,
    );

    final expenseMap = groupExpenseByCategory(transactions: monthlyExpenses);

    final updatedBudgets = budgets.map((budget) {
      final spent = expenseMap[budget.categoryId] ?? 0;
      final progress = FinanceCalculator.calculateBudgetProgress(
        spentAmount: spent,
        limitAmount: budget.limitAmount,
      );

      return budget.copyWith(
        spentAmount: spent,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        status: FinanceCalculator.getBudgetStatus(progressPercent: progress),
      );
    }).toList()
      ..sort((a, b) => b.spentAmount.compareTo(a.spentAmount));

    return updatedBudgets;
  }

  static List<Budget> getHomeBudgetItems({
    required List<Budget> budgets,
    int limit = 3,
  }) {
    final clone = [...budgets]
      ..sort((a, b) {
        final byStatus = b.progressPercent.compareTo(a.progressPercent);
        if (byStatus != 0) return byStatus;
        return b.spentAmount.compareTo(a.spentAmount);
      });

    return clone.take(limit).toList();
  }

  static int getTotalSpent({
    required List<Budget> budgets,
  }) {
    return budgets.fold(0, (sum, item) => sum + item.spentAmount);
  }

  static int getTotalLimit({
    required List<Budget> budgets,
  }) {
    return budgets.fold(0, (sum, item) => sum + item.limitAmount);
  }

  static String? getPrimaryBudgetAlert(List<Budget> budgets) {
    if (budgets.isEmpty) return null;

    final sorted = [...budgets]
      ..sort((a, b) => b.progressPercent.compareTo(a.progressPercent));

    final target = sorted.first;
    if (target.progressPercent >= 100) {
      return 'Bạn đã vượt ngân sách ${target.categoryName.toLowerCase()}.';
    }
    if (target.progressPercent >= 80) {
      return 'Bạn đã dùng ${target.progressPercent}% ngân sách ${target.categoryName.toLowerCase()}.';
    }
    return null;
  }
}
