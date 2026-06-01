class FinanceCalculator {
  static int calculateBudgetProgress({
    required num spentAmount,
    required num limitAmount,
  }) {
    if (limitAmount <= 0) return 0;
    return ((spentAmount * 100) / limitAmount).floor();
  }

  static double calculateRemainingAmount({
    required num totalAmount,
    required num currentAmount,
  }) {
    final result = totalAmount - currentAmount;
    return result < 0 ? 0.0 : result.toDouble();
  }

  static String getBudgetStatus({
    required int progressPercent,
  }) {
    if (progressPercent >= 100) return 'danger';
    if (progressPercent >= 70) return 'warning';
    return 'safe';
  }

  static String getBudgetStatusColor({
    required int progressPercent,
  }) {
    if (progressPercent >= 100) return '#EF4444';
    if (progressPercent >= 80) return '#EF97316';
    return '#22C55E';
  }

  static String? getBudgetAlertMessage({
    required int progressPercent,
  }) {
    if (progressPercent >= 100) return 'Đã vượt ngân sách!';
    if (progressPercent >= 80) return 'Sắp vượt ngân sách!';
    return null;
  }
}