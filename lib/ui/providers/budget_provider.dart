import 'package:flutter/material.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';

class BudgetProvider extends ChangeNotifier {
  static const String _demoUserId = 'user_001';

  BudgetProvider([FinanceRepository? repository])
      : _repository = repository ?? FinanceRepository();

  final FinanceRepository _repository;

  List<Budget> _budgets = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<Budget> get budgets => List.unmodifiable(_budgets);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;

  Future<void> loadMonthlyBudgets(String userId, int month, int year) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedMonth = month;
    _selectedYear = year;
    notifyListeners();

    try {
      var effectiveUserId = userId;
      await _repository.refreshBudgetSpentForPeriod(
        effectiveUserId,
        month,
        year,
      );
      var baseBudgets = await _repository.getBudgets(
        effectiveUserId,
        month,
        year,
      );

      if (baseBudgets.isEmpty && userId != _demoUserId) {
        effectiveUserId = _demoUserId;
        baseBudgets = await _repository.getBudgets(
          effectiveUserId,
          month,
          year,
        );
      }

      if (baseBudgets.isEmpty) {
        final fallbackPeriod = await _repository.getLatestBudgetPeriod(
          effectiveUserId,
        );
        if (fallbackPeriod != null) {
          _selectedMonth = fallbackPeriod.month;
          _selectedYear = fallbackPeriod.year;
          baseBudgets = await _repository.getBudgets(
            effectiveUserId,
            _selectedMonth,
            _selectedYear,
          );
        }
      }

      _budgets = baseBudgets;
    } catch (e) {
      _errorMessage = 'Không tải được ngân sách: $e';
      _budgets = [];
      debugPrint('Lỗi khi tải ngân sách: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBudget(Budget budget) async {
    _errorMessage = null;
    try {
      await _repository.createBudget(budget);
      await loadMonthlyBudgets(budget.userId, budget.month, budget.year);
    } catch (e) {
      _errorMessage = 'Không thể lưu ngân sách: $e';
      rethrow;
    }
  }
}