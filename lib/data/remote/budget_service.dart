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

    final expenseMap = groupExpenseByCategory(
      transactions: monthlyExpenses,
    );

    final updatedBudgets = budgets.map((budget) {
      final spent = expenseMap[budget.categoryId] ?? 0;
      final progress = FinanceCalculator.calculateBudgetProgress(
        spentAmount: spent,
        limitAmount: budget.limitAmount,
      );

      return budget.copyWith(
        spentAmount: spent.toDouble(),
        updatedAt: DateTime.now(),
        status: FinanceCalculator.getBudgetStatus(
          progressPercent: progress,
        ),
      );
    }).toList();

    updatedBudgets.sort((a, b) => b.spentAmount.compareTo(a.spentAmount));

    return updatedBudgets;
  }

  static int getTotalSpent({
    required List<Budget> budgets,
  }) {
    return budgets.fold<double>(0.0, (sum, item) => sum + item.spentAmount).toInt();
  }

  static int getTotalLimit({
    required List<Budget> budgets,
  }) {
    return budgets.fold<double>(0.0, (sum, item) => sum + item.limitAmount).toInt();
  }
}