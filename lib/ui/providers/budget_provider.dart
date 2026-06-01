
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:flutter/foundation.dart';
import '../../services/sync_service.dart';

class BudgetProvider extends ChangeNotifier {
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

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('--- [BUDGET PROVIDER] $message');
    }
  }

  Future<void> loadMonthlyBudgets(String userId, int month, int year) async {
    _log(
      'loadMonthlyBudgets start userId=$userId month=$month year=$year at ${DateTime.now()}',
    );
    _isLoading = true;
    _errorMessage = null;
    _selectedMonth = month;
    _selectedYear = year;
    notifyListeners();

    try {
      _log('refreshBudgetSpentForPeriod start at ${DateTime.now()}');
      await _repository.refreshBudgetSpentForPeriod(userId, month, year);
      _log('refreshBudgetSpentForPeriod done at ${DateTime.now()}');
      _log('getBudgets primary start at ${DateTime.now()}');
      var baseBudgets = await _repository.getBudgets(userId, month, year);
      _log(
        'getBudgets primary done count=${baseBudgets.length} at ${DateTime.now()}',
      );

      if (baseBudgets.isEmpty) {
        _log(
          'no budgets found, checking latest budget period at ${DateTime.now()}',
        );
        final fallbackPeriod = await _repository.getLatestBudgetPeriod(userId);
        if (fallbackPeriod != null) {
          _selectedMonth = fallbackPeriod.month;
          _selectedYear = fallbackPeriod.year;
          baseBudgets = await _repository.getBudgets(
            userId,
            _selectedMonth,
            _selectedYear,
          );
          _log(
            'fallback period budgets count=${baseBudgets.length} at ${DateTime.now()}',
          );
        }
      }

      _budgets = baseBudgets;
      _log('loadMonthlyBudgets finished at ${DateTime.now()}');
    } catch (e) {
      _errorMessage = 'Không tải được ngân sách: $e';
      _budgets = [];
      debugPrint('Lỗi khi tải ngân sách: $e');
      _log('loadMonthlyBudgets error=$e at ${DateTime.now()}');
    } finally {
      _isLoading = false;
      notifyListeners();
      _log('loadMonthlyBudgets loading=false at ${DateTime.now()}');
    }
  }

  Future<void> addBudget(Budget budget) async {
    _errorMessage = null;
    try {
      await _repository.createBudget(budget);
      SyncService().triggerImmediateSync();
      await loadMonthlyBudgets(budget.userId, budget.month, budget.year);
    } catch (e) {
      _errorMessage = 'Không thể lưu ngân sách: $e';
      rethrow;
    }
  }

  Future<void> updateBudget(Budget budget) async {
    _errorMessage = null;
    try {
      await _repository.upsertBudget(budget);
      SyncService().triggerImmediateSync();
      await loadMonthlyBudgets(budget.userId, budget.month, budget.year);
    } catch (e) {
      _errorMessage = 'Không thể cập nhật ngân sách: $e';
      rethrow;
    }
  }

  Future<void> deleteBudget(String budgetId, String userId) async {
    _errorMessage = null;
    try {
      await _repository.deleteBudget(userId, budgetId);
      SyncService().triggerImmediateSync();
      await loadMonthlyBudgets(userId, _selectedMonth, _selectedYear);
    } catch (e) {
      _errorMessage = 'Không thể xóa ngân sách: $e';
      rethrow;
    }
  }
}
