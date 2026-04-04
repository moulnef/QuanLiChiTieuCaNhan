import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';

class FinanceProvider extends ChangeNotifier {
  FinanceProvider({
    TransactionRepository? transactionRepository,
  }) : _transactionRepository =
      transactionRepository ?? TransactionRepository();

  final TransactionRepository _transactionRepository;

  bool _isLoading = false;
  bool _isSeeded = false;
  bool _isDisposed = false;
  String? _errorMessage;

  final List<FinanceSavingItem> _savings = [];
  final List<FinanceInstallmentItem> _installments = [];
  final List<FinanceDebtItem> _debts = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  String? get primaryAlertMessage {
    final savingAlert = _nearestSavingAlert();
    if (savingAlert != null) return savingAlert;

    final installmentAlert = _nearestInstallmentAlert();
    if (installmentAlert != null) return installmentAlert;

    final debtAlert = _nearestDebtAlert();
    if (debtAlert != null) return debtAlert;

    return null;
  }

  Future<void> loadFinanceData() async {
    if (_isLoading || _isSeeded) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!_isSeeded) {
        _seedMockData();
        _isSeeded = true;
      }
    } catch (e) {
      _errorMessage = 'Không tải được dữ liệu tài chính: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _seedMockData() {
    _savings
      ..clear()
      ..addAll([
        FinanceSavingItem(
          id: 1,
          icon: '🏍️',
          title: 'Mua xe máy mới',
          currentAmount: 18500000,
          targetAmount: 35000000,
          deadline: DateTime.now().add(const Duration(days: 281)),
          color: AppColors.blue,
        ),
        FinanceSavingItem(
          id: 2,
          icon: '🗾',
          title: 'Du lịch Nhật Bản',
          currentAmount: 8000000,
          targetAmount: 25000000,
          deadline: DateTime.now().add(const Duration(days: 433)),
          color: AppColors.purple,
        ),
        FinanceSavingItem(
          id: 3,
          icon: '🛡️',
          title: 'Quỹ khẩn cấp',
          currentAmount: 32000000,
          targetAmount: 50000000,
          deadline: DateTime.now().add(const Duration(days: 97)),
          color: AppColors.teal,
        ),
      ]);

    _installments
      ..clear()
      ..addAll([
        FinanceInstallmentItem(
          id: 1,
          icon: '📱',
          title: 'Điện thoại iPhone 15',
          totalAmount: 27500000,
          paidAmount: 9000000,
          currentPeriod: 4,
          totalPeriods: 12,
          monthlyPayment: 2291666,
          nextDueDate: DateTime.now().add(const Duration(days: 8)),
          color: AppColors.blue,
        ),
        FinanceInstallmentItem(
          id: 2,
          icon: '💻',
          title: 'Máy tính xách tay',
          totalAmount: 19260000,
          paidAmount: 14260000,
          currentPeriod: 11,
          totalPeriods: 12,
          monthlyPayment: 1596666,
          nextDueDate: DateTime.now().add(const Duration(days: 13)),
          color: AppColors.purple,
        ),
      ]);

    _debts
      ..clear()
      ..addAll([
        FinanceDebtItem(
          id: 1,
          icon: '💳',
          title: 'Vay mua xe đạp điện',
          lender: 'Ngân hàng ACB',
          totalAmount: 12000000,
          paidAmount: 4500000,
          monthlyPayment: 550000,
          dueDate: DateTime.now().add(const Duration(days: 4)),
          interestText: '8.5%/năm',
          color: AppColors.warning,
        ),
      ]);
  }

  Future<void> addSavingGoal({
    required String title,
    required int targetAmount,
    required DateTime deadline,
    String icon = '🎯',
    Color color = AppColors.financeGreen,
  }) async {
    final item = FinanceSavingItem(
      id: DateTime.now().millisecondsSinceEpoch,
      icon: icon,
      title: title,
      currentAmount: 0,
      targetAmount: targetAmount,
      deadline: deadline,
      color: color,
    );

    _savings.insert(0, item);
    notifyListeners();
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
    _savings[index] = current.copyWith(
      currentAmount: current.currentAmount + amount,
    );

    notifyListeners();

    try {
      await _recordTransaction(
        amount: amount.toDouble(),
        type: 'expense',
        categoryId: 'e47',
        categoryName: 'Nạp tiết kiệm',
        note: 'Nạp vào mục tiêu "${current.title}"',
      );
    } catch (e) {
      debugPrint('Lỗi ghi transaction khi nạp tiết kiệm: $e');
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

    _savings[index] = current.copyWith(
      currentAmount: current.currentAmount - amount,
    );

    notifyListeners();

    try {
      await _recordTransaction(
        amount: amount.toDouble(),
        type: 'income',
        categoryId: 'i8',
        categoryName: 'Rút tiết kiệm',
        note: 'Rút từ mục tiêu "${current.title}"',
      );
    } catch (e) {
      debugPrint('Lỗi ghi transaction khi rút tiết kiệm: $e');
    }
  }

  Future<void> addInstallmentPlan({
    required String title,
    required int totalAmount,
    required int totalPeriods,
    required int monthlyPayment,
    DateTime? nextDueDate,
    String icon = '🧾',
    Color color = AppColors.blue,
  }) async {
    final newItem = FinanceInstallmentItem(
      id: DateTime.now().millisecondsSinceEpoch,
      icon: icon,
      title: title,
      totalAmount: totalAmount,
      paidAmount: 0,
      currentPeriod: 0,
      totalPeriods: totalPeriods,
      monthlyPayment: monthlyPayment,
      nextDueDate: nextDueDate ?? DateTime.now().add(const Duration(days: 30)),
      color: color,
    );

    _installments.insert(0, newItem);
    notifyListeners();
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
    final isCompleted = newPaidAmount >= current.totalAmount;
    final newCurrentPeriod = isCompleted
        ? current.totalPeriods
        : (current.currentPeriod + 1).clamp(0, current.totalPeriods);

    _installments[index] = current.copyWith(
      paidAmount: newPaidAmount,
      currentPeriod: newCurrentPeriod,
      nextDueDate: isCompleted
          ? current.nextDueDate
          : current.nextDueDate.add(const Duration(days: 30)),
    );

    notifyListeners();

    try {
      await _recordTransaction(
        amount: amount.toDouble(),
        type: 'expense',
        categoryId: 'e48',
        categoryName: 'Thanh toán trả góp',
        note: 'Thanh toán trả góp "${current.title}"',
      );
    } catch (e) {
      debugPrint('Lỗi ghi transaction khi thanh toán trả góp: $e');
    }
  }

  Future<void> addDebtRecord({
    required String title,
    required String lender,
    required int totalAmount,
    required int monthlyPayment,
    required DateTime dueDate,
    String icon = '💰',
    String interestText = 'Chưa cập nhật lãi suất',
    Color color = AppColors.warning,
  }) async {
    final item = FinanceDebtItem(
      id: DateTime.now().millisecondsSinceEpoch,
      icon: icon,
      title: title,
      lender: lender,
      totalAmount: totalAmount,
      paidAmount: 0,
      monthlyPayment: monthlyPayment,
      dueDate: dueDate,
      interestText: interestText,
      color: color,
    );

    _debts.insert(0, item);
    notifyListeners();
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

    _debts[index] = current.copyWith(
      paidAmount: current.paidAmount + amount,
    );

    notifyListeners();

    try {
      await _recordTransaction(
        amount: amount.toDouble(),
        type: 'expense',
        categoryId: 'e49',
        categoryName: 'Trả nợ',
        note: 'Thanh toán khoản vay "${current.title}"',
      );
    } catch (e) {
      debugPrint('Lỗi ghi transaction khi trả nợ: $e');
    }
  }

  String? _nearestSavingAlert() {
    final candidates = _savings.where((item) {
      final days = item.daysLeft;
      return days <= 7 && days >= 0 && item.progressPercent < 100;
    }).toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    if (candidates.isEmpty) return null;
    final item = candidates.first;
    return 'Mục tiêu "${item.title}" còn ${item.daysLeft} ngày nhưng mới đạt ${item.progressPercent}%.';
  }

  String? _nearestInstallmentAlert() {
    final candidates = _installments.where((item) {
      final days = item.daysLeft;
      return days <= 7 && days >= 0 && item.progressPercent < 100;
    }).toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    if (candidates.isEmpty) return null;
    final item = candidates.first;
    return 'Khoản trả góp "${item.title}" sắp đến hạn sau ${item.daysLeft} ngày.';
  }

  String? _nearestDebtAlert() {
    final candidates = _debts.where((item) {
      final days = item.daysLeft;
      return days <= 7 && item.progressPercent < 100;
    }).toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    if (candidates.isEmpty) return null;
    final item = candidates.first;

    if (item.daysLeft < 0) {
      return 'Khoản vay "${item.title}" đã quá hạn ${item.daysLeft.abs()} ngày.';
    }

    return 'Khoản vay "${item.title}" còn ${item.daysLeft} ngày tới kỳ hạn.';
  }

  Future<void> _recordTransaction({
    required double amount,
    required String type,
    required String categoryId,
    required String categoryName,
    required String note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    await _transactionRepository.addTransaction(
      TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user?.uid ?? '',
        categoryId: categoryId,
        categoryName: categoryName,
        type: type,
        amount: amount,
        note: note,
        transactionDate: DateTime.now(),
      ),
    );
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

  int get remainingAmount =>
      (targetAmount - currentAmount).clamp(0, targetAmount);

  int get progressPercent =>
      targetAmount <= 0 ? 0 : ((currentAmount * 100) / targetAmount).floor();

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(deadline.year, deadline.month, deadline.day);
    return end.difference(today).inDays;
  }

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
  final int monthlyPayment;
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
    required this.monthlyPayment,
    required this.nextDueDate,
    required this.color,
  });

  int get remainingAmount =>
      (totalAmount - paidAmount).clamp(0, totalAmount);

  int get progressPercent =>
      totalAmount <= 0 ? 0 : ((paidAmount * 100) / totalAmount).floor();

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return end.difference(today).inDays;
  }

  FinanceInstallmentItem copyWith({
    int? id,
    String? icon,
    String? title,
    int? totalAmount,
    int? paidAmount,
    int? currentPeriod,
    int? totalPeriods,
    int? monthlyPayment,
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
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
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

  int get remainingAmount =>
      (totalAmount - paidAmount).clamp(0, totalAmount);

  int get progressPercent =>
      totalAmount <= 0 ? 0 : ((paidAmount * 100) / totalAmount).floor();

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return end.difference(today).inDays;
  }

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
