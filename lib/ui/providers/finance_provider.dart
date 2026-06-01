import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import '../../services/sync_service.dart';
import '../../services/notification_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/saving.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/debt_record.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/installment_plan.dart';

class FinanceProvider extends ChangeNotifier {
  static const String _demoUserId = 'user_001';

  FinanceProvider([FinanceRepository? repository])
    : _repository = repository ?? FinanceRepository();

  final FinanceRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  double _totalBalance = 0;
  double _totalIncome = 0;
  double _totalExpense = 0;
  int _transactionCount = 0;

  final List<FinanceSavingItem> _savings = [];
  final List<FinanceInstallmentItem> _installments = [];
  final List<FinanceDebtItem> _debts = [];
  final List<TransactionModel> _recentTransactions = [];
  String _activeUserId = _demoUserId;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get totalBalance => _totalBalance;
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  int get transactionCount => _transactionCount;
  double get cashBalance => _totalIncome - _totalExpense;
  List<TransactionModel> get recentTransactions =>
      List.unmodifiable(_recentTransactions);

  List<FinanceSavingItem> get savings => List.unmodifiable(_savings);
  List<FinanceInstallmentItem> get installments =>
      List.unmodifiable(_installments);
  List<FinanceDebtItem> get debts => List.unmodifiable(_debts);

  int get totalSavingAmount =>
      _savings.fold(0, (sum, item) => sum + item.currentAmount);

  int get totalInstallmentRemaining =>
      _installments.fold(0, (sum, item) => sum + item.remainingAmount);

  int get totalDebtRemaining =>
      _debts.fold(0, (sum, item) => sum + item.remainingAmount);

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('--- [FINANCE PROVIDER] $message');
    }
  }

  Future<void> refreshFinancialSummary(String userId) async {
    _log('refreshFinancialSummary start userId=$userId at ${DateTime.now()}');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Sync local/cloud database before loading summary
      _log('Syncing databases with Firebase at ${DateTime.now()}');
      await _repository.syncWithFirebase(userId);

      _log('Loading transactions from database at ${DateTime.now()}');
      final transactions = await _repository.getAllTransactionsByUserId(userId);
      _log(
        'Primary transactions loaded count=${transactions.length} at ${DateTime.now()}',
      );

      _applyFinancialSummary(transactions);
      _updateFinancialBalance();
      _log('refreshFinancialSummary finished at ${DateTime.now()}');
    } catch (e) {
      _errorMessage = 'Không tải được dữ liệu tài chính: $e';
      debugPrint('Lỗi khi tải dữ liệu thực tế: $e');
      _log('refreshFinancialSummary error=$e at ${DateTime.now()}');
    } finally {
      _isLoading = false;
      notifyListeners();
      _log('refreshFinancialSummary loading=false at ${DateTime.now()}');
    }
  }

  void _applyFinancialSummary(List<TransactionModel> transactions) {
    double income = 0;
    double expense = 0;

    for (final transaction in transactions) {
      if (transaction.type == 'income') {
        income += transaction.amount;
      } else {
        expense += transaction.amount;
      }
    }

    _totalIncome = income;
    _totalExpense = expense;
    _totalBalance = income - expense;
    _transactionCount = transactions.length;
    _recentTransactions
      ..clear()
      ..addAll(transactions.take(20));
  }

  Future<void> loadFinanceData([String? userId]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var effectiveUserId = userId ?? _demoUserId;
      if (effectiveUserId.isEmpty) {
        effectiveUserId = _demoUserId;
      }
      _activeUserId = effectiveUserId;

      var savings = await _repository.getSavingsByUserId(effectiveUserId);
      var installments = await _repository.getInstallmentsByUserId(
        effectiveUserId,
      );
      var debts = await _repository.getDebtsByUserId(effectiveUserId);

      _savings
        ..clear()
        ..addAll(savings);
      _installments
        ..clear()
        ..addAll(installments);
      _debts
        ..clear()
        ..addAll(debts);

      _updateFinancialBalance();

      // Trigger notifications check
      NotificationService.instance.checkAndTriggerNotifications(effectiveUserId);

      // Trigger background sync, and silently reload upon completion
      _repository.syncWithFirebase(effectiveUserId).then((_) {
        _log('Background sync completed. Reloading lists silently...');
        _loadFinanceDataSilently(effectiveUserId);
      });
    } catch (e) {
      _errorMessage = 'Không tải được dữ liệu tài chính: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFinanceDataSilently(String userId) async {
    try {
      var savings = await _repository.getSavingsByUserId(userId);
      var installments = await _repository.getInstallmentsByUserId(userId);
      var debts = await _repository.getDebtsByUserId(userId);

      _savings
        ..clear()
        ..addAll(savings);
      _installments
        ..clear()
        ..addAll(installments);
      _debts
        ..clear()
        ..addAll(debts);

      _updateFinancialBalance();
      notifyListeners();

      // Trigger notifications check
      NotificationService.instance.checkAndTriggerNotifications(userId);
    } catch (e) {
      _log('Silently reloading finance data failed: $e');
    }
  }

  Future<void> addSavingGoal({
    required String title,
    required int targetAmount,
    required DateTime deadline,
    String icon = '🎯',
    Color color = AppColors.financeGreen,
  }) async {
    try {
      await _repository.addSavingGoal(
        userId: _activeUserId,
        title: title,
        targetAmount: targetAmount,
        deadline: deadline,
        icon: icon,
        color: color,
      );
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể lưu mục tiêu tiết kiệm: $e';
      rethrow;
    }
  }

  Future<void> depositToSavingGoal(int id, int amount) async {
    if (amount <= 0) {
      throw Exception('Số tiền phải lớn hơn 0.');
    }

    final index = _savings.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw Exception('Không tìm thấy mục tiêu tiết kiệm.');
    }

    final current = _savings[index];
    final updated = current.copyWith(
      currentAmount: current.currentAmount + amount,
    );

    // Save locally
    _savings[index] = updated;
    _updateFinancialBalance();
    notifyListeners();

    // Push update to repository
    try {
      await _repository.updateSavingGoal(
        SavingGoal(
          id: updated.id.toString(),
          userId: _activeUserId,
          title: updated.title,
          icon: updated.icon,
          currentAmount: updated.currentAmount,
          targetAmount: updated.targetAmount,
          targetDate: updated.deadline.millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          status: 'active',
        ),
      );
      SyncService().triggerImmediateSync();
    } catch (e) {
      _log('Error saving deposit: $e');
    }
  }

  Future<void> withdrawFromSavingGoal(int id, int amount) async {
    if (amount <= 0) {
      throw Exception('Số tiền phải lớn hơn 0.');
    }

    final index = _savings.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw Exception('Không tìm thấy mục tiêu tiết kiệm.');
    }

    final current = _savings[index];
    if (amount > current.currentAmount) {
      throw Exception('Không thể rút vượt số tiền hiện có.');
    }

    final updated = current.copyWith(
      currentAmount: current.currentAmount - amount,
    );

    // Save locally
    _savings[index] = updated;
    _updateFinancialBalance();
    notifyListeners();

    // Push update to repository
    try {
      await _repository.updateSavingGoal(
        SavingGoal(
          id: updated.id.toString(),
          userId: _activeUserId,
          title: updated.title,
          icon: updated.icon,
          currentAmount: updated.currentAmount,
          targetAmount: updated.targetAmount,
          targetDate: updated.deadline.millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          status: 'active',
        ),
      );
      SyncService().triggerImmediateSync();
    } catch (e) {
      _log('Error saving withdrawal: $e');
    }
  }

  Future<void> addInstallmentPlan({
    required String title,
    required int totalAmount,
    required int totalPeriods,
    DateTime? nextDueDate,
    String icon = '🧾',
    Color color = AppColors.blue,
  }) async {
    try {
      await _repository.addInstallmentPlan(
        userId: _activeUserId,
        title: title,
        totalAmount: totalAmount,
        totalPeriods: totalPeriods,
        nextDueDate:
            nextDueDate ?? DateTime.now().add(const Duration(days: 30)),
        icon: icon,
        color: color,
      );
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể lưu kế hoạch trả góp: $e';
      rethrow;
    }
  }

  double calculateMonthlyPayment(
    double principal,
    double annualRate,
    int months,
  ) {
    if (principal <= 0 || months <= 0) return 0;

    final monthlyRate = annualRate / 100 / 12;
    if (monthlyRate == 0) {
      return principal / months;
    }

    final powFactor = math.pow(1 + monthlyRate, months).toDouble();
    return principal * monthlyRate * powFactor / (powFactor - 1);
  }

  Future<void> addInstallment({
    required String name,
    required double amount,
    required String bankName,
    required double interestRate,
    required int months,
    required double monthlyPayment,
  }) async {
    final normalizedMonthlyPayment = monthlyPayment > 0
        ? monthlyPayment
        : kIsWeb
            ? amount / months
            : calculateMonthlyPayment(amount, interestRate, months);
    final totalAmount = amount > 0
        ? amount.round()
        : (normalizedMonthlyPayment * months).round();
    final normalizedTitle = bankName.trim().isEmpty
        ? name
        : '$name - $bankName';

    await addInstallmentPlan(
      title: normalizedTitle,
      totalAmount: totalAmount,
      totalPeriods: months,
      nextDueDate: DateTime.now().add(const Duration(days: 30)),
    );
  }

  Future<void> payInstallment(int id, int amount) async {
    if (amount <= 0) {
      throw Exception('Số tiền thanh toán phải lớn hơn 0.');
    }

    final index = _installments.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw Exception('Không tìm thấy khoản trả góp.');
    }

    final current = _installments[index];
    if (amount > current.remainingAmount) {
      throw Exception('Không thể thanh toán vượt số còn lại.');
    }

    final newPaidAmount = current.paidAmount + amount;
    final newCurrentPeriod = current.currentPeriod < current.totalPeriods
        ? current.currentPeriod + 1
        : current.currentPeriod;

    final updated = current.copyWith(
      paidAmount: newPaidAmount,
      currentPeriod: newCurrentPeriod,
      nextDueDate: current.remainingAmount - amount <= 0
          ? current.nextDueDate
          : current.nextDueDate.add(const Duration(days: 30)),
    );

    // Save locally
    _installments[index] = updated;
    _updateFinancialBalance();
    notifyListeners();

    // Push update to repository
    try {
      await _repository.updateInstallmentPlan(
        InstallmentPlan(
          id: updated.id.toString(),
          userId: _activeUserId,
          title: updated.title,
          icon: updated.icon,
          totalAmount: updated.totalAmount,
          paidAmount: updated.paidAmount,
          monthlyPayment: (updated.totalAmount / updated.totalPeriods).round(),
          paidPeriods: updated.currentPeriod,
          totalPeriods: updated.totalPeriods,
          nextDueDate: updated.nextDueDate.millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          status: updated.remainingAmount <= 0 ? 'completed' : 'active',
        ),
      );
      SyncService().triggerImmediateSync();
    } catch (e) {
      _log('Error saving paid installment: $e');
    }
  }

  Future<void> addDebtRecord({
    required String title,
    required String lender,
    required int totalAmount,
    int monthlyPayment = 0,
    required DateTime dueDate,
    String icon = '💰',
    String interestText = 'Chưa cập nhật lãi suất',
    Color color = AppColors.safe,
  }) async {
    try {
      await _repository.addDebtRecord(
        userId: _activeUserId,
        title: title,
        lender: lender,
        totalAmount: totalAmount,
        monthlyPayment: monthlyPayment,
        dueDate: dueDate,
        interestText: interestText,
        icon: icon,
        color: color,
      );
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể lưu khoản vay: $e';
      rethrow;
    }
  }

  Future<void> payDebt(int id, int amount) async {
    if (amount <= 0) {
      throw Exception('Số tiền thanh toán phải lớn hơn 0.');
    }

    final index = _debts.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw Exception('Không tìm thấy khoản vay.');
    }

    final current = _debts[index];
    if (amount > current.remainingAmount) {
      throw Exception('Không thể thanh toán vượt số nợ còn lại.');
    }

    final updated = current.copyWith(paidAmount: current.paidAmount + amount);

    // Save locally
    _debts[index] = updated;
    _updateFinancialBalance();
    notifyListeners();

    // Push update to repository
    try {
      await _repository.updateDebtRecord(
        DebtRecord(
          id: updated.id.toString(),
          userId: _activeUserId,
          title: updated.title,
          lenderName: updated.lender,
          totalAmount: updated.totalAmount,
          paidAmount: updated.paidAmount,
          monthlyPayment: updated.monthlyPayment,
          interestRate: 0.0,
          nextDueDate: updated.dueDate.millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          status: updated.remainingAmount <= 0 ? 'settled' : 'active',
        ),
      );
      SyncService().triggerImmediateSync();
    } catch (e) {
      _log('Error saving paid debt: $e');
    }
  }

  Future<void> deleteSavingGoal(String id) async {
    try {
      await _repository.deleteSavingGoal(_activeUserId, id);
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể xóa mục tiêu tiết kiệm: $e';
      rethrow;
    }
  }

  Future<void> updateSavingGoal(SavingGoal goal) async {
    try {
      await _repository.updateSavingGoal(goal);
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể cập nhật mục tiêu tiết kiệm: $e';
      rethrow;
    }
  }

  Future<void> addInstallmentPlanDirect(InstallmentPlan plan) async {
    try {
      await _repository.insertInstallmentPlan(plan);
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể lưu kế hoạch trả góp: $e';
      rethrow;
    }
  }

  Future<void> addDebtRecordDirect(DebtRecord debt) async {
    try {
      await _repository.insertDebtRecord(debt);
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể lưu khoản vay: $e';
      rethrow;
    }
  }

  Future<void> deleteInstallment(String id) async {
    try {
      await _repository.deleteInstallmentPlan(_activeUserId, id);
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể xóa khoản trả góp: $e';
      rethrow;
    }
  }

  Future<void> updateInstallmentPlan(InstallmentPlan plan) async {
    try {
      await _repository.updateInstallmentPlan(plan);
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể cập nhật khoản trả góp: $e';
      rethrow;
    }
  }

  Future<void> deleteDebt(String id) async {
    try {
      await _repository.deleteDebtRecord(_activeUserId, id);
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể xóa khoản vay: $e';
      rethrow;
    }
  }

  Future<void> updateDebtRecord(DebtRecord debt) async {
    try {
      await _repository.updateDebtRecord(debt);
      await loadFinanceData(_activeUserId);
      SyncService().triggerImmediateSync();
    } catch (e) {
      _errorMessage = 'Không thể cập nhật khoản vay: $e';
      rethrow;
    }
  }

  void _updateFinancialBalance() {
    _totalBalance =
        totalSavingAmount.toDouble() -
        totalInstallmentRemaining.toDouble() -
        totalDebtRemaining.toDouble();
  }
}

class FinanceSavingItem {
  final int id;
  final String icon;
  final String title;
  final int currentAmount;
  final int targetAmount;
  final DateTime deadline;
  final Color color;

  const FinanceSavingItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.currentAmount,
    required this.targetAmount,
    required this.deadline,
    required this.color,
  });

  int get daysLeft => deadline.difference(DateTime.now()).inDays;

  FinanceSavingItem copyWith({
    int? id,
    String? icon,
    String? title,
    int? currentAmount,
    int? targetAmount,
    DateTime? deadline,
    Color? color,
  }) {
    return FinanceSavingItem(
      id: id ?? this.id,
      icon: icon ?? this.icon,
      title: title ?? this.title,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      deadline: deadline ?? this.deadline,
      color: color ?? this.color,
    );
  }
}

class FinanceInstallmentItem {
  final int id;
  final String icon;
  final String title;
  final int totalAmount;
  final int paidAmount;
  final int currentPeriod;
  final int totalPeriods;
  final DateTime nextDueDate;
  final Color color;

  const FinanceInstallmentItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.currentPeriod,
    required this.totalPeriods,
    required this.nextDueDate,
    required this.color,
  });

  int get remainingAmount => (totalAmount - paidAmount).clamp(0, totalAmount);

  FinanceInstallmentItem copyWith({
    int? id,
    String? icon,
    String? title,
    int? totalAmount,
    int? paidAmount,
    int? currentPeriod,
    int? totalPeriods,
    DateTime? nextDueDate,
    Color? color,
  }) {
    return FinanceInstallmentItem(
      id: id ?? this.id,
      icon: icon ?? this.icon,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      totalPeriods: totalPeriods ?? this.totalPeriods,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      color: color ?? this.color,
    );
  }
}

class FinanceDebtItem {
  final int id;
  final String icon;
  final String title;
  final String lender;
  final int totalAmount;
  final int paidAmount;
  final int monthlyPayment;
  final DateTime dueDate;
  final String interestText;
  final Color color;

  const FinanceDebtItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.lender,
    required this.totalAmount,
    required this.paidAmount,
    required this.monthlyPayment,
    required this.dueDate,
    required this.interestText,
    required this.color,
  });

  int get remainingAmount => (totalAmount - paidAmount).clamp(0, totalAmount);
  int get daysLeft => dueDate.difference(DateTime.now()).inDays;

  FinanceDebtItem copyWith({
    int? id,
    String? icon,
    String? title,
    String? lender,
    int? totalAmount,
    int? paidAmount,
    int? monthlyPayment,
    DateTime? dueDate,
    String? interestText,
    Color? color,
  }) {
    return FinanceDebtItem(
      id: id ?? this.id,
      icon: icon ?? this.icon,
      title: title ?? this.title,
      lender: lender ?? this.lender,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      dueDate: dueDate ?? this.dueDate,
      interestText: interestText ?? this.interestText,
      color: color ?? this.color,
    );
  }
}
