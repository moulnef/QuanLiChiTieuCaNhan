import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/category_data.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/database_helper.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/category_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/saving.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/debt_record.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/installment_plan.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';

class TransactionRepository {
  static const String _demoUserId = 'user_001';

  TransactionRepository([FinanceRepository? repository])
      : _repository = repository ?? FinanceRepository();

  final FinanceRepository _repository;

  Stream<void> watchTransactions([String? userId]) {
    return _repository.watchTransactions(userId ?? _demoUserId);
  }

  Future<List<TransactionModel>> getTransactions([String? userId]) async {
    return _repository.getAllTransactionsByUserId(userId ?? _demoUserId);
  }

  Future<void> addTransaction(TransactionModel tx, [String? userId]) async {
    final effectiveUserId = tx.userId.isNotEmpty
        ? tx.userId
        : (userId ?? _demoUserId);
    final now = DateTime.now();
    final normalized = tx.copyWith(
      id: tx.id.isEmpty ? now.millisecondsSinceEpoch.toString() : tx.id,
      userId: effectiveUserId,
      createdAt: tx.createdAt,
      updatedAt: now,
    );
    await _repository.upsertTransaction(normalized);
  }

  Future<void> deleteTransaction(String id, [String? userId]) async {
    if (id.isEmpty) return;
    await _repository.deleteTransaction(userId ?? _demoUserId, id);
  }
}

class FinanceRepository {
  static const String demoUserId = 'user_001';

  FinanceRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;
  final Map<String, Set<String>> _tableColumnsCache = {};
  static final StreamController<String> _transactionChangeController =
  StreamController<String>.broadcast();

  Stream<void> watchTransactions(String userId) {
    return _transactionChangeController.stream
        .where((changedUserId) => changedUserId == userId)
        .map((_) {});
  }

  void _notifyTransactionChanged(String userId) {
    if (!_transactionChangeController.isClosed) {
      _transactionChangeController.add(userId);
    }
  }

  Future<List<TransactionModel>> getAllTransactionsByUserId(
      String userId,
      ) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'datetime(transactionDate) DESC, datetime(updatedAt) DESC',
    );

    return rows.map(_transactionFromRow).toList();
  }

  Future<TransactionModel?> getTransactionById(String userId, String id) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'transactions',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _transactionFromRow(rows.first);
  }

  Future<void> upsertTransaction(TransactionModel transaction) async {
    if (transaction.userId.isEmpty) return;

    final db = await _databaseHelper.database;
    final oldTransaction = await getTransactionById(
      transaction.userId,
      transaction.id,
    );
    final now = DateTime.now();
    final normalized = transaction.copyWith(
      id: transaction.id.isEmpty
          ? now.millisecondsSinceEpoch.toString()
          : transaction.id,
      updatedAt: now,
      createdAt: oldTransaction?.createdAt ?? transaction.createdAt,
    );

    await db.insert(
      'transactions',
      _transactionToRow(normalized),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _syncBudgetSpentForTransaction(normalized);
    if (oldTransaction != null) {
      await _syncBudgetSpentForTransaction(oldTransaction);
    }

    _notifyTransactionChanged(transaction.userId);
  }

  Future<void> deleteTransaction(String userId, String id) async {
    final db = await _databaseHelper.database;
    final oldTransaction = await getTransactionById(userId, id);
    await db.delete(
      'transactions',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );

    if (oldTransaction != null) {
      await _syncBudgetSpentForTransaction(oldTransaction);
    }
    _notifyTransactionChanged(userId);
  }

  Future<List<Budget>> getBudgets(String userId, int month, int year) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'budgets',
      where: 'userId = ? AND month = ? AND year = ?',
      whereArgs: [userId, month, year],
      orderBy: 'updatedAt DESC, createdAt DESC',
    );

    return rows.map((row) => _budgetFromRow(row, userId)).toList();
  }

  Future<void> upsertBudget(Budget budget) async {
    await createBudget(budget);
  }

  Future<void> createBudget(Budget budget) async {
    final db = await _databaseHelper.database;
    final spent = await getSumExpenseByCategory(
      budget.userId,
      budget.categoryId,
      budget.month,
      budget.year,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalized = budget.copyWith(
      spentAmount: spent.round(),
      updatedAt: now,
      createdAt: budget.createdAt == 0 ? now : budget.createdAt,
      status: _resolveBudgetStatus(spent.round(), budget.limitAmount),
    );

    await db.insert(
      'budgets',
      normalized.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBudget(String budgetId) async {
    final db = await _databaseHelper.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [budgetId]);
  }

  Future<void> refreshBudgetSpentForPeriod(
      String userId,
      int month,
      int year,
      ) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'budgets',
      where: 'userId = ? AND month = ? AND year = ?',
      whereArgs: [userId, month, year],
    );

    for (final row in rows) {
      final budget = _budgetFromRow(row, userId);
      final spent = await getSumExpenseByCategory(
        userId,
        budget.categoryId,
        month,
        year,
      );
      await db.update(
        'budgets',
        {
          'spentAmount': spent.round(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'status': _resolveBudgetStatus(spent.round(), budget.limitAmount),
        },
        where: 'id = ?',
        whereArgs: [budget.id],
      );
    }
  }

  Future<double> getSumExpenseByCategory(
      String userId,
      String catId,
      int month,
      int year,
      ) async {
    final db = await _databaseHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM transactions
      WHERE userId = ? AND categoryId = ? AND type = 'expense'
      AND strftime('%m', transactionDate) = ?
      AND strftime('%Y', transactionDate) = ?
      ''',
      [userId, catId, month.toString().padLeft(2, '0'), year.toString()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> _syncBudgetSpentForTransaction(
      TransactionModel transaction,
      ) async {
    if (transaction.type != 'expense' || transaction.categoryId.isEmpty) {
      return;
    }

    await _syncBudgetSpentByPeriod(
      userId: transaction.userId,
      categoryId: transaction.categoryId,
      month: transaction.transactionDate.month,
      year: transaction.transactionDate.year,
    );
  }

  Future<void> _syncBudgetSpentByPeriod({
    required String userId,
    required String categoryId,
    required int month,
    required int year,
  }) async {
    final db = await _databaseHelper.database;
    final spent = await getSumExpenseByCategory(
      userId,
      categoryId,
      month,
      year,
    );
    final rows = await db.query(
      'budgets',
      where: 'userId = ? AND categoryId = ? AND month = ? AND year = ?',
      whereArgs: [userId, categoryId, month, year],
    );

    for (final row in rows) {
      final limitAmount = _asInt(row['limitAmount']) ?? 0;
      await db.update(
        'budgets',
        {
          'spentAmount': spent.round(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'status': _resolveBudgetStatus(spent.round(), limitAmount),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<DateTime?> getLatestBudgetPeriod(String userId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT month, year
      FROM budgets
      WHERE userId = ?
      ORDER BY year DESC, month DESC
      LIMIT 1
      ''',
      [userId],
    );

    if (result.isEmpty) {
      return null;
    }

    final month = (result.first['month'] as num?)?.toInt();
    final year = (result.first['year'] as num?)?.toInt();
    if (month == null || year == null) {
      return null;
    }

    return DateTime(year, month);
  }

  Future<List<FinanceSavingItem>> getSavingsByUserId(String userId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM savings WHERE COALESCE(userId, user_id) = ? ORDER BY id ASC',
      [userId],
    );

    return rows
        .map(
          (row) => FinanceSavingItem(
        id: _asInt(row['id']) ?? 0,
        icon: row['icon']?.toString() ?? '🎯',
        title: row['title']?.toString() ?? 'Mục tiêu',
        currentAmount:
        _asInt(row['currentAmount'] ?? row['current_amount']) ?? 0,
        targetAmount:
        _asInt(row['targetAmount'] ?? row['target_amount']) ?? 0,
        deadline: _parseDate(row['deadline']),
        color: _parseColor(row['colorValue'] ?? row['color_value']),
      ),
    )
        .toList();
  }

  Future<void> addSavingGoal({
    required String userId,
    required String title,
    required int targetAmount,
    required DateTime deadline,
    required String icon,
    required Color color,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final targetEpoch = deadline.millisecondsSinceEpoch;
    await _insertWithCompatibleColumns(db, 'savings', {
      'id': now,
      'userId': userId,
      'user_id': userId,
      'icon': icon,
      'title': title,
      'currentAmount': 0,
      'current_amount': 0,
      'targetAmount': targetAmount,
      'target_amount': targetAmount,
      'deadline': deadline.toIso8601String(),
      'targetDate': targetEpoch,
      'target_date': targetEpoch,
      'colorValue': color.value,
      'color_value': color.value,
      'createdAt': now,
      'created_at': now,
      'updatedAt': now,
      'updated_at': now,
      'status': 'active',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FinanceInstallmentItem>> getInstallmentsByUserId(
      String userId,
      ) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM installments WHERE COALESCE(userId, user_id) = ? ORDER BY id ASC',
      [userId],
    );

    return rows
        .map(
          (row) => FinanceInstallmentItem(
        id: _asInt(row['id']) ?? 0,
        icon: row['icon']?.toString() ?? '🧾',
        title: row['title']?.toString() ?? 'Kế hoạch',
        totalAmount: _asInt(row['totalAmount'] ?? row['total_amount']) ?? 0,
        paidAmount: _asInt(row['paidAmount'] ?? row['paid_amount']) ?? 0,
        currentPeriod:
        _asInt(row['currentPeriod'] ?? row['current_period']) ?? 0,
        totalPeriods:
        _asInt(row['totalPeriods'] ?? row['total_periods']) ?? 0,
        nextDueDate: _parseDate(row['nextDueDate']),
        color: _parseColor(row['colorValue'] ?? row['color_value']),
      ),
    )
        .toList();
  }

  Future<void> addInstallmentPlan({
    required String userId,
    required String title,
    required int totalAmount,
    required int totalPeriods,
    required DateTime nextDueDate,
    required String icon,
    required Color color,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextDueEpoch = nextDueDate.millisecondsSinceEpoch;
    final paidPeriods = 0;
    final monthlyPayment = totalPeriods > 0
        ? (totalAmount / totalPeriods).round()
        : 0;
    await _insertWithCompatibleColumns(db, 'installments', {
      'id': now,
      'userId': userId,
      'user_id': userId,
      'icon': icon,
      'title': title,
      'totalAmount': totalAmount,
      'total_amount': totalAmount,
      'paidAmount': 0,
      'paid_amount': 0,
      'currentPeriod': paidPeriods,
      'current_period': paidPeriods,
      'paidPeriods': paidPeriods,
      'paid_periods': paidPeriods,
      'totalPeriods': totalPeriods,
      'total_periods': totalPeriods,
      'nextDueDate': nextDueDate.toIso8601String(),
      'next_due_date': nextDueDate.toIso8601String(),
      'nextDueDateEpoch': nextDueEpoch,
      'next_due_date_epoch': nextDueEpoch,
      'monthlyPayment': monthlyPayment,
      'monthly_payment': monthlyPayment,
      'colorValue': color.value,
      'color_value': color.value,
      'createdAt': now,
      'created_at': now,
      'updatedAt': now,
      'updated_at': now,
      'status': 'active',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FinanceDebtItem>> getDebtsByUserId(String userId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM debts WHERE COALESCE(userId, user_id) = ? ORDER BY id ASC',
      [userId],
    );

    return rows
        .map(
          (row) => FinanceDebtItem(
        id: _asInt(row['id']) ?? 0,
        icon: row['icon']?.toString() ?? '💰',
        title: row['title']?.toString() ?? 'Khoản vay',
        lender: row['lender']?.toString() ?? 'Không rõ',
        totalAmount: _asInt(row['totalAmount'] ?? row['total_amount']) ?? 0,
        paidAmount: _asInt(row['paidAmount'] ?? row['paid_amount']) ?? 0,
        monthlyPayment: _asInt(row['monthlyPayment'] ?? row['monthly_payment']) ?? 0,
        dueDate: _parseDate(row['dueDate']),
        interestText: row['interestText']?.toString() ?? 'Chưa cập nhật',
        color: _parseColor(row['colorValue'] ?? row['color_value']),
      ),
    )
        .toList();
  }

  Future<void> addDebtRecord({
    required String userId,
    required String title,
    required String lender,
    required int totalAmount,
    int monthlyPayment = 0,
    required DateTime dueDate,
    required String interestText,
    required String icon,
    required Color color,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextDueEpoch = dueDate.millisecondsSinceEpoch;
    await _insertWithCompatibleColumns(db, 'debts', {
      'id': now,
      'userId': userId,
      'user_id': userId,
      'icon': icon,
      'title': title,
      'lender': lender,
      'lenderName': lender,
      'lender_name': lender,
      'totalAmount': totalAmount,
      'total_amount': totalAmount,
      'paidAmount': 0,
      'paid_amount': 0,
      'monthlyPayment': monthlyPayment,
      'monthly_payment': monthlyPayment,
      'interestRate': 0.0,
      'interest_rate': 0.0,
      'dueDate': dueDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'nextDueDate': nextDueEpoch,
      'next_due_date': nextDueEpoch,
      'interestText': interestText,
      'interest_text': interestText,
      'colorValue': color.value,
      'color_value': color.value,
      'createdAt': now,
      'created_at': now,
      'updatedAt': now,
      'updated_at': now,
      'status': 'active',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ========== HOME PAGE FUNCTIONS ==========

  /// Get financial overview for home page
  /// Returns: {income, expense, balance, recentTransactions}
  Future<Map<String, dynamic>> getHomeOverview(String userId) async {
    final now = DateTime.now();
    final db = await _databaseHelper.database;

    // Get income and expense for current month
    final result = await db.rawQuery(
      '''
      SELECT 
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as totalIncome,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as totalExpense
      FROM transactions
      WHERE userId = ? 
      AND strftime('%m', transactionDate) = ?
      AND strftime('%Y', transactionDate) = ?
      ''',
      [userId, now.month.toString().padLeft(2, '0'), now.year.toString()],
    );

    final totalIncome = (result.first['totalIncome'] as num?)?.toDouble() ?? 0;
    final totalExpense =
        (result.first['totalExpense'] as num?)?.toDouble() ?? 0;
    final balance = totalIncome - totalExpense;

    // Get 5 most recent transactions
    final recentTransactions = await getRecentTransactions(userId, limit: 5);

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': balance,
      'recentTransactions': recentTransactions,
    };
  }

  /// Get the N most recent transactions for a user
  Future<List<TransactionModel>> getRecentTransactions(
      String userId, {
        int limit = 5,
      }) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'datetime(transactionDate) DESC, datetime(updatedAt) DESC',
      limit: limit,
    );

    return rows.map(_transactionFromRow).toList();
  }

  /// Insert a new transaction and update related budget
  /// If transaction is an expense, update the corresponding budget's spentAmount
  Future<void> insertTransaction(TransactionModel transaction) async {
    if (transaction.userId.isEmpty) {
      return;
    }

    // Use upsertTransaction which already handles budget sync
    await upsertTransaction(transaction);
  }

  // ========== SAVING GOAL FUNCTIONS ==========

  /// Get all saving goals for a user
  Future<List<SavingGoal>> getAllSavingGoals(String userId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM savings WHERE COALESCE(userId, user_id) = ? ORDER BY COALESCE(createdAt, created_at, id) DESC',
      [userId],
    );

    return rows.map((row) => _savingGoalFromRow(row, userId)).toList();
  }

  /// Get a specific saving goal
  Future<SavingGoal?> getSavingGoalById(String userId, String goalId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM savings WHERE id = ? AND COALESCE(userId, user_id) = ? LIMIT 1',
      [goalId, userId],
    );

    if (rows.isEmpty) return null;
    return _savingGoalFromRow(rows.first, userId);
  }

  /// Update an existing saving goal
  Future<void> updateSavingGoal(SavingGoal goal) async {
    final db = await _databaseHelper.database;
    await db.update(
      'savings',
      {
        'title': goal.title,
        'icon': goal.icon,
        'currentAmount': goal.currentAmount,
        'current_amount': goal.currentAmount,
        'targetAmount': goal.targetAmount,
        'target_amount': goal.targetAmount,
        'targetDate': goal.targetDate,
        'target_date': goal.targetDate,
        'updatedAt': goal.updatedAt,
        'updated_at': goal.updatedAt,
        'status': goal.status,
      },
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [goal.id, goal.userId],
    );
  }

  /// Delete a saving goal
  Future<void> deleteSavingGoal(String userId, String goalId) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'savings',
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [goalId, userId],
    );
  }

  // ========== DEBT RECORD FUNCTIONS ==========

  /// Get all debt records for a user
  Future<List<DebtRecord>> getAllDebtRecords(String userId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM debts WHERE COALESCE(userId, user_id) = ? ORDER BY COALESCE(createdAt, created_at, id) DESC',
      [userId],
    );

    return rows.map((row) => _debtRecordFromRow(row, userId)).toList();
  }

  /// Get a specific debt record
  Future<DebtRecord?> getDebtRecordById(String userId, String debtId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM debts WHERE id = ? AND COALESCE(userId, user_id) = ? LIMIT 1',
      [debtId, userId],
    );

    if (rows.isEmpty) return null;
    return _debtRecordFromRow(rows.first, userId);
  }

  /// Update an existing debt record
  Future<void> updateDebtRecord(DebtRecord debt) async {
    final db = await _databaseHelper.database;
    await db.update(
      'debts',
      {
        'title': debt.title,
        'lender': debt.lenderName,
        'lenderName': debt.lenderName,
        'lender_name': debt.lenderName,
        'totalAmount': debt.totalAmount,
        'total_amount': debt.totalAmount,
        'paidAmount': debt.paidAmount,
        'paid_amount': debt.paidAmount,
        'monthlyPayment': debt.monthlyPayment,
        'monthly_payment': debt.monthlyPayment,
        'interestRate': debt.interestRate,
        'interest_rate': debt.interestRate,
        'dueDate': DateTime.fromMillisecondsSinceEpoch(
          debt.nextDueDate,
        ).toIso8601String(),
        'due_date': DateTime.fromMillisecondsSinceEpoch(
          debt.nextDueDate,
        ).toIso8601String(),
        'nextDueDate': debt.nextDueDate,
        'next_due_date': debt.nextDueDate,
        'updatedAt': debt.updatedAt,
        'updated_at': debt.updatedAt,
        'status': debt.status,
      },
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [debt.id, debt.userId],
    );
  }

  /// Delete a debt record
  Future<void> deleteDebtRecord(String userId, String debtId) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'debts',
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [debtId, userId],
    );
  }

  // ========== INSTALLMENT PLAN FUNCTIONS ==========

  /// Get all installment plans for a user
  Future<List<InstallmentPlan>> getAllInstallmentPlans(String userId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM installments WHERE COALESCE(userId, user_id) = ? ORDER BY COALESCE(createdAt, created_at, id) DESC',
      [userId],
    );

    return rows.map((row) => _installmentPlanFromRow(row, userId)).toList();
  }

  /// Get a specific installment plan
  Future<InstallmentPlan?> getInstallmentPlanById(
      String userId,
      String planId,
      ) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM installments WHERE id = ? AND COALESCE(userId, user_id) = ? LIMIT 1',
      [planId, userId],
    );

    if (rows.isEmpty) return null;
    return _installmentPlanFromRow(rows.first, userId);
  }

  /// Update an existing installment plan
  Future<void> updateInstallmentPlan(InstallmentPlan plan) async {
    final db = await _databaseHelper.database;
    await db.update(
      'installments',
      {
        'title': plan.title,
        'icon': plan.icon,
        'totalAmount': plan.totalAmount,
        'total_amount': plan.totalAmount,
        'paidAmount': plan.paidAmount,
        'paid_amount': plan.paidAmount,
        'monthlyPayment': plan.monthlyPayment,
        'monthly_payment': plan.monthlyPayment,
        'currentPeriod': plan.paidPeriods,
        'current_period': plan.paidPeriods,
        'paidPeriods': plan.paidPeriods,
        'paid_periods': plan.paidPeriods,
        'totalPeriods': plan.totalPeriods,
        'total_periods': plan.totalPeriods,
        'nextDueDate': DateTime.fromMillisecondsSinceEpoch(
          plan.nextDueDate,
        ).toIso8601String(),
        'next_due_date': DateTime.fromMillisecondsSinceEpoch(
          plan.nextDueDate,
        ).toIso8601String(),
        'nextDueDateEpoch': plan.nextDueDate,
        'next_due_date_epoch': plan.nextDueDate,
        'updatedAt': plan.updatedAt,
        'updated_at': plan.updatedAt,
        'status': plan.status,
      },
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [plan.id, plan.userId],
    );
  }

  /// Delete an installment plan
  Future<void> deleteInstallmentPlan(String userId, String planId) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'installments',
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [planId, userId],
    );
  }

  // ========== BUDGET FUNCTIONS ==========

  /// Update or create a budget with validation
  /// Checks if budget for this category exists in current month
  /// Returns true if new budget was created, false if updated
  Future<bool> upsertBudgetForCategory({
    required String userId,
    required String categoryId,
    required int limitAmount,
    required int month,
    required int year,
  }) async {
    final db = await _databaseHelper.database;
    final category = _findCategory(categoryId);

    // Check if budget already exists
    final existing = await db.query(
      'budgets',
      where: 'userId = ? AND categoryId = ? AND month = ? AND year = ?',
      whereArgs: [userId, categoryId, month, year],
      limit: 1,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    final spent = await getSumExpenseByCategory(
      userId,
      categoryId,
      month,
      year,
    );

    if (existing.isNotEmpty) {
      // Update existing budget
      await db.update(
        'budgets',
        {
          'limitAmount': limitAmount,
          'updatedAt': now,
          'status': _resolveBudgetStatus(spent.round(), limitAmount),
        },
        where: 'userId = ? AND categoryId = ? AND month = ? AND year = ?',
        whereArgs: [userId, categoryId, month, year],
      );
      return false;
    } else {
      // Create new budget
      await db.insert('budgets', {
        'id': '${categoryId}_${userId}_${month}_${year}',
        'userId': userId,
        'categoryId': categoryId,
        'categoryName': category?.name ?? 'Không rõ',
        'icon': category?.icon ?? '🏷️',
        'month': month,
        'year': year,
        'limitAmount': limitAmount,
        'spentAmount': spent.round(),
        'createdAt': now,
        'updatedAt': now,
        'status': _resolveBudgetStatus(spent.round(), limitAmount),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    }
  }

  /// Get budget status for all categories
  Future<Map<String, dynamic>> getBudgetStatus(
      String userId,
      int month,
      int year,
      ) async {
    final budgets = await getBudgets(userId, month, year);
    double totalLimit = 0;
    double totalSpent = 0;

    for (final budget in budgets) {
      totalLimit += budget.limitAmount;
      totalSpent += budget.spentAmount;
    }

    return {
      'totalLimit': totalLimit,
      'totalSpent': totalSpent,
      'remaining': totalLimit - totalSpent,
      'percentUsed': totalLimit > 0
          ? ((totalSpent / totalLimit) * 100).toStringAsFixed(1)
          : '0',
      'budgets': budgets,
    };
  }

  // ========== HELPER FUNCTIONS FOR MODEL CONVERSION ==========

  SavingGoal _savingGoalFromRow(Map<String, Object?> row, String userId) {
    return SavingGoal(
      id: row['id']?.toString() ?? '',
      userId: userId,
      title: row['title']?.toString() ?? 'Mục tiêu',
      icon: row['icon']?.toString() ?? '🎯',
      currentAmount: _asInt(row['currentAmount'] ?? row['current_amount']) ?? 0,
      targetAmount: _asInt(row['targetAmount'] ?? row['target_amount']) ?? 0,
      targetDate:
      _asInt(row['targetDate'] ?? row['target_date']) ??
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      createdAt:
      _asInt(row['createdAt'] ?? row['created_at']) ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
      _asInt(row['updatedAt'] ?? row['updated_at']) ??
          DateTime.now().millisecondsSinceEpoch,
      status: row['status']?.toString() ?? 'active',
    );
  }

  DebtRecord _debtRecordFromRow(Map<String, Object?> row, String userId) {
    return DebtRecord(
      id: row['id']?.toString() ?? '',
      userId: userId,
      title: row['title']?.toString() ?? 'Khoản vay',
      lenderName:
      row['lender']?.toString() ??
          row['lenderName']?.toString() ??
          row['lender_name']?.toString() ??
          'Không rõ',
      totalAmount: _asInt(row['totalAmount'] ?? row['total_amount']) ?? 0,
      paidAmount: _asInt(row['paidAmount'] ?? row['paid_amount']) ?? 0,
      monthlyPayment:
      _asInt(row['monthlyPayment'] ?? row['monthly_payment']) ?? 0,
      interestRate:
      (row['interestRate'] as num?)?.toDouble() ??
          (row['interest_rate'] as num?)?.toDouble() ??
          0.0,
      nextDueDate:
      _asInt(row['nextDueDate'] ?? row['next_due_date']) ??
          _asInt(row['dueDate'] ?? row['due_date']) ??
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      createdAt:
      _asInt(row['createdAt'] ?? row['created_at']) ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
      _asInt(row['updatedAt'] ?? row['updated_at']) ??
          DateTime.now().millisecondsSinceEpoch,
      status: row['status']?.toString() ?? 'active',
    );
  }

  InstallmentPlan _installmentPlanFromRow(
      Map<String, Object?> row,
      String userId,
      ) {
    return InstallmentPlan(
      id: row['id']?.toString() ?? '',
      userId: userId,
      title: row['title']?.toString() ?? 'Kế hoạch trả góp',
      icon: row['icon']?.toString() ?? '🧾',
      totalAmount: _asInt(row['totalAmount'] ?? row['total_amount']) ?? 0,
      paidAmount: _asInt(row['paidAmount'] ?? row['paid_amount']) ?? 0,
      monthlyPayment:
      _asInt(row['monthlyPayment'] ?? row['monthly_payment']) ?? 0,
      paidPeriods:
      _asInt(
        row['currentPeriod'] ??
            row['current_period'] ??
            row['paidPeriods'] ??
            row['paid_periods'],
      ) ??
          0,
      totalPeriods: _asInt(row['totalPeriods'] ?? row['total_periods']) ?? 0,
      nextDueDate:
      _asInt(row['nextDueDateEpoch'] ?? row['next_due_date_epoch']) ??
          _asInt(row['nextDueDate'] ?? row['next_due_date']) ??
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      createdAt:
      _asInt(row['createdAt'] ?? row['created_at']) ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
      _asInt(row['updatedAt'] ?? row['updated_at']) ??
          DateTime.now().millisecondsSinceEpoch,
      status: row['status']?.toString() ?? 'active',
    );
  }

  // ========== AUTH SESSION FUNCTIONS ==========

  Future<Map<String, dynamic>?> getAuthSessionByUserId(String userId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'auth_session',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertAuthSession(Map<String, dynamic> payload) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'auth_session',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getWalletsByUserId(String userId) async {
    final db = await _databaseHelper.database;
    // Use rawQuery with COALESCE to handle both userId and user_id columns for backward compatibility
    final rows = await db.rawQuery(
      'SELECT * FROM wallets WHERE COALESCE(userId, user_id) = ? ORDER BY name ASC',
      [userId],
    );
    return rows;
  }

  Future<double> getTotalWalletBalance(String userId) async {
    final db = await _databaseHelper.database;
    // Use COALESCE to handle both userId and user_id columns for backward compatibility
    final rows = await db.rawQuery(
      'SELECT SUM(balance) AS total FROM wallets WHERE COALESCE(userId, user_id) = ?',
      [userId],
    );

    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> getTransactionCountByUserId(String userId) async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM transactions WHERE userId = ?',
      [userId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Creates default wallets for a user if they don't have any
  /// Seeds them with the user's actual transaction balance
  Future<void> ensureDefaultWalletsForUser(String userId) async {
    final db = await _databaseHelper.database;

    // Check if user already has any wallets
    final walletCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM wallets WHERE COALESCE(userId, user_id) = ?',
            [userId],
          ),
        ) ??
            0;

    // If user has no wallets, create default ones
    if (walletCount == 0) {
      // Calculate user's actual balance from transactions
      final rows = await db.rawQuery(
        '''
        SELECT 
          SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as totalIncome,
          SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as totalExpense
        FROM transactions 
        WHERE COALESCE(userId, user_id) = ?
      ''',
        [userId],
      );

      double totalIncome = (rows.first['totalIncome'] as num?)?.toDouble() ?? 0;
      double totalExpense =
          (rows.first['totalExpense'] as num?)?.toDouble() ?? 0;
      double balance = totalIncome - totalExpense;

      await db.transaction((txn) async {
        await txn.insert('wallets', {
          'id': 'wallet_cash_${userId}',
          'name': 'Ví tiền mặt',
          'balance': balance,
          'userId': userId,
          'user_id': userId, // For backward compatibility
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await txn.insert('wallets', {
          'id': 'wallet_bank_${userId}',
          'name': 'Tài khoản ngân hàng',
          'balance': 0,
          'userId': userId,
          'user_id': userId, // For backward compatibility
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }
  }

  Map<String, Object?> _transactionToRow(TransactionModel transaction) {
    final transactionDateIso = transaction.transactionDate.toIso8601String();
    final createdAtIso = transaction.createdAt.toIso8601String();
    final updatedAtIso = transaction.updatedAt.toIso8601String();

    return {
      'id': transaction.id,
      'userId': transaction.userId,
      'user_id': transaction.userId,
      'walletId': transaction.walletId,
      'wallet_id': transaction.walletId,
      'categoryId': transaction.categoryId,
      'category_id': transaction.categoryId,
      'categoryName': transaction.categoryName,
      'category_name': transaction.categoryName,
      'type': transaction.type,
      'amount': transaction.amount,
      'note': transaction.note,
      'transactionDate': transactionDateIso,
      'transaction_date': transactionDateIso,
      'createdAt': createdAtIso,
      'created_at': createdAtIso,
      'updatedAt': updatedAtIso,
      'updated_at': updatedAtIso,
    };
  }

  TransactionModel _transactionFromRow(Map<String, Object?> row) {
    return TransactionModel(
      id: row['id']?.toString() ?? '',
      userId: row['userId']?.toString() ?? row['user_id']?.toString() ?? '',
      walletId:
      row['walletId']?.toString() ?? row['wallet_id']?.toString() ?? '',
      categoryId:
      row['categoryId']?.toString() ?? row['category_id']?.toString() ?? '',
      categoryName:
      row['categoryName']?.toString() ??
          row['category_name']?.toString() ??
          _resolveCategoryName(row['categoryId'] ?? row['category_id']),
      type: row['type']?.toString() ?? 'expense',
      amount: _asDouble(row['amount']),
      note: row['note']?.toString() ?? '',
      transactionDate: _parseDate(
        row['transactionDate'] ?? row['transaction_date'] ?? row['date'],
      ),
      createdAt: _parseDate(
        row['createdAt'] ??
            row['created_at'] ??
            row['transactionDate'] ??
            row['transaction_date'] ??
            row['date'],
      ),
      updatedAt: _parseDate(
        row['updatedAt'] ??
            row['updated_at'] ??
            row['transactionDate'] ??
            row['transaction_date'] ??
            row['date'],
      ),
    );
  }

  Budget _budgetFromRow(Map<String, Object?> row, String fallbackUserId) {
    final categoryId =
        row['categoryId']?.toString() ?? row['category_id']?.toString() ?? '';
    final category = _findCategory(categoryId);
    final createdAt =
        _asInt(row['createdAt'] ?? row['created_at']) ??
            DateTime.now().millisecondsSinceEpoch;
    final updatedAt =
        _asInt(row['updatedAt'] ?? row['updated_at']) ?? createdAt;
    final spentAmount = _asInt(row['spentAmount'] ?? row['spent_amount']) ?? 0;
    final limitAmount = _asInt(row['limitAmount'] ?? row['limit_amount']) ?? 0;

    return Budget(
      id: row['id']?.toString() ?? '',
      userId:
      (row['userId']?.toString() ?? row['user_id']?.toString() ?? '')
          .isNotEmpty
          ? (row['userId']?.toString() ?? row['user_id']?.toString() ?? '')
          : fallbackUserId,
      categoryId: categoryId,
      categoryName:
      (row['categoryName']?.toString() ??
          row['category_name']?.toString() ??
          '')
          .isNotEmpty
          ? (row['categoryName']?.toString() ??
          row['category_name']?.toString() ??
          '')
          : category?.name ?? 'Không rõ',
      icon: row['icon']?.toString().isNotEmpty == true
          ? row['icon'].toString()
          : category?.icon ?? '🏷️',
      month: _asInt(row['month']) ?? DateTime.now().month,
      year: _asInt(row['year']) ?? DateTime.now().year,
      limitAmount: limitAmount,
      spentAmount: spentAmount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: row['status']?.toString().isNotEmpty == true
          ? row['status'].toString()
          : '',
    );
  }

  String _resolveCategoryName(Object? categoryId) {
    return _findCategory(categoryId?.toString() ?? '')?.name ?? 'Không rõ';
  }

  CategoryModel? _findCategory(String categoryId) {
    if (categoryId.isEmpty) return null;
    for (final category in CategoryData.getAllCategories()) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double _asDouble(Object? value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  DateTime _parseDate(Object? value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Color _parseColor(Object? value) {
    final parsed = _asInt(value);
    if (parsed == null) {
      return const Color(0xFF3B82F6);
    }
    return Color(parsed);
  }

  String _resolveBudgetStatus(int spentAmount, int limitAmount) {
    if (limitAmount <= 0) return 'safe';

    final ratio = spentAmount / limitAmount;
    if (ratio >= 1) return 'danger';
    if (ratio >= 0.8) return 'warning';
    return 'safe';
  }

  Future<void> _insertWithCompatibleColumns(
      Database db,
      String table,
      Map<String, Object?> payload, {
        required ConflictAlgorithm conflictAlgorithm,
      }) async {
    final supportedColumns = await _getTableColumns(db, table);
    final compatiblePayload = <String, Object?>{};
    for (final entry in payload.entries) {
      if (supportedColumns.contains(entry.key)) {
        compatiblePayload[entry.key] = entry.value;
      }
    }

    await db.insert(
      table,
      compatiblePayload,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<Set<String>> _getTableColumns(Database db, String table) async {
    final cached = _tableColumnsCache[table];
    if (cached != null) return cached;

    final result = await db.rawQuery('PRAGMA table_info($table)');
    final columns = result
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    _tableColumnsCache[table] = columns;
    return columns;
  }
}