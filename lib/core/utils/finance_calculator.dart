class FinanceCalculator {
  static int calculateBudgetProgress({
    required int spentAmount,
    required int limitAmount,
  }) {
    if (limitAmount <= 0) return 0;
    return ((spentAmount * 100) / limitAmount).floor();
  }

  static int calculateSavingProgress({
    required int currentAmount,
    required int targetAmount,
  }) {
    if (targetAmount <= 0) return 0;
    return ((currentAmount * 100) / targetAmount).floor();
  }

  static int calculateInstallmentProgress({
    required int paidAmount,
    required int totalAmount,
  }) {
    if (totalAmount <= 0) return 0;
    return ((paidAmount * 100) / totalAmount).floor();
  }

  static int calculateDebtProgress({
    required int paidAmount,
    required int totalAmount,
  }) {
    if (totalAmount <= 0) return 0;
    return ((paidAmount * 100) / totalAmount).floor();
  }

  static int calculateRemainingAmount({
    required int totalAmount,
    required int currentAmount,
  }) {
    final result = totalAmount - currentAmount;
    return result < 0 ? 0 : result;
  }

  static int clampProgress(int progressPercent) {
    return progressPercent.clamp(0, 100);
  }

  static String getBudgetStatus({
    required int progressPercent,
  }) {
    if (progressPercent >= 100) return 'danger';
    if (progressPercent >= 80) return 'warning';
    return 'safe';
  }

  static String getBudgetStatusColor({
    required int progressPercent,
  }) {
    if (progressPercent >= 100) return '#EF4444';
    if (progressPercent >= 80) return '#F97316';
    return '#22C55E';
  }

  static String? getBudgetAlertMessage({
    required int progressPercent,
  }) {
    if (progressPercent >= 100) return 'Đã vượt ngân sách!';
    if (progressPercent >= 80) return 'Sắp vượt ngân sách!';
    return null;
  }

  static bool isNearDueDate({
    required int daysLeft,
    int threshold = 7,
  }) {
    return daysLeft >= 0 && daysLeft <= threshold;
  }

  static bool isOverdue({
    required int daysLeft,
  }) {
    return daysLeft < 0;
  }

  static String? getSavingAlertMessage({
    required int daysLeft,
    required int progressPercent,
  }) {
    if (daysLeft < 0 && progressPercent < 100) {
      return 'Mục tiêu đã quá hạn nhưng chưa hoàn thành.';
    }
    if (isNearDueDate(daysLeft: daysLeft) && progressPercent < 100) {
      return 'Mục tiêu sắp đến hạn.';
    }
    return null;
  }

  static String? getDueAlertMessage({
    required int daysLeft,
    required String label,
  }) {
    if (daysLeft < 0) {
      return '$label đã quá hạn ${daysLeft.abs()} ngày.';
    }
    if (isNearDueDate(daysLeft: daysLeft)) {
      return '$label còn $daysLeft ngày tới hạn.';
    }
    return null;
  }
}
