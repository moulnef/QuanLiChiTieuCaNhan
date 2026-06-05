import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/category_data.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/database_helper.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/category_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/saving.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/debt_record.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/installment_plan.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/wallet_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/app_feedback.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';

class FinanceRepository {
  static const String demoUserId = 'user_001';

  FinanceRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;
  final FirestoreService _firestoreService = FirestoreService();
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

  // Cross-platform connectivity helper
  Future<bool> _isOnline() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ==================== STREAM EXPOSURE FOR UI ====================

  Stream<List<TransactionModel>> streamTransactions(String userId) {
    if (kIsWeb) {
      return _firestoreService.streamTransactions();
    }
    final controller = StreamController<List<TransactionModel>>.broadcast();

    Future<void> load() async {
      try {
        final list = await getAllTransactionsByUserId(userId);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    load();

    final subscription = watchTransactions(userId).listen((_) => load());

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Stream<List<Budget>> streamBudgets(String userId, int month, int year) {
    if (kIsWeb) {
      return _firestoreService.streamBudgets().map((list) {
        return list.where((b) => b.month == month && b.year == year).toList();
      });
    }
    final controller = StreamController<List<Budget>>.broadcast();

    Future<void> load() async {
      try {
        final list = await getBudgets(userId, month, year);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    load();

    final subscription = watchTransactions(userId).listen((_) => load());

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Stream<List<SavingGoal>> streamSavings(String userId) {
    if (kIsWeb) {
      return _firestoreService.streamSavings().map((list) {
        return list.where((s) => s.userId == userId).toList();
      });
    }
    final controller = StreamController<List<SavingGoal>>.broadcast();

    Future<void> load() async {
      try {
        final list = await getAllSavingGoals(userId);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    load();

    final subscription = watchTransactions(userId).listen((_) => load());

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Stream<List<InstallmentPlan>> streamInstallments(String userId) {
    if (kIsWeb) {
      return _firestoreService.streamInstallments().map((list) {
        return list.where((i) => i.userId == userId).toList();
      });
    }
    final controller = StreamController<List<InstallmentPlan>>.broadcast();

    Future<void> load() async {
      try {
        final list = await getAllInstallmentPlans(userId);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    load();

    final subscription = watchTransactions(userId).listen((_) => load());

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Stream<List<DebtRecord>> streamDebts(String userId) {
    if (kIsWeb) {
      return _firestoreService.streamDebts().map((list) {
        return list.where((d) => d.userId == userId).toList();
      });
    }
    final controller = StreamController<List<DebtRecord>>.broadcast();

    Future<void> load() async {
      try {
        final list = await getAllDebtRecords(userId);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    load();

    final subscription = watchTransactions(userId).listen((_) => load());

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ==================== STATISTICS & DATE QUERIES ====================

  Future<List<TransactionModel>> getTransactionsByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    if (kIsWeb) {
      final list = await _firestoreService.getTransactions();
      return list
          .where(
            (t) =>
                (t.userId.isEmpty || t.userId == userId) &&
                t.transactionDate.isAfter(
                  start.subtract(const Duration(seconds: 1)),
                ) &&
                t.transactionDate.isBefore(end.add(const Duration(seconds: 1))),
          )
          .toList();
    }
    final db = await _databaseHelper.database;
    final userExpression = await _transactionUserExpression(db);
    final dateColumn = await _transactionDateColumn(db);
    final rows = await db.rawQuery(
      'SELECT * FROM transactions WHERE $userExpression = ? AND (isDeleted = 0 OR isDeleted IS NULL) '
      'AND datetime($dateColumn) >= datetime(?) AND datetime($dateColumn) <= datetime(?) '
      'ORDER BY datetime($dateColumn) DESC',
      [userId, start.toIso8601String(), end.toIso8601String()],
    );
    return rows.map(_transactionFromRow).toList();
  }

  Future<Map<String, double>> getMonthlyStats(
    String userId,
    int month,
    int year,
  ) async {
    if (kIsWeb) {
      final list = await _firestoreService.getTransactions();
      final monthly = list
          .where(
            (t) =>
                (t.userId.isEmpty || t.userId == userId) &&
                t.transactionDate.month == month &&
                t.transactionDate.year == year,
          )
          .toList();
      double income = 0;
      double expense = 0;
      for (final t in monthly) {
        if (t.type == 'income') {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      return {
        'income': income,
        'expense': expense,
        'balance': income - expense,
      };
    }
    final db = await _databaseHelper.database;
    final userExpression = await _transactionUserExpression(db);
    final dateColumn = await _transactionDateColumn(db);

    final monthStr = month.toString().padLeft(2, '0');
    final yearStr = year.toString();

    final result = await db.rawQuery(
      '''
      SELECT 
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as totalIncome,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as totalExpense
      FROM transactions
      WHERE $userExpression = ? AND (isDeleted = 0 OR isDeleted IS NULL)
      AND strftime('%m', $dateColumn) = ?
      AND strftime('%Y', $dateColumn) = ?
      ''',
      [userId, monthStr, yearStr],
    );

    final totalIncome =
        (result.first['totalIncome'] as num?)?.toDouble() ?? 0.0;
    final totalExpense =
        (result.first['totalExpense'] as num?)?.toDouble() ?? 0.0;

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  Future<List<Map<String, dynamic>>> getCategoryStats(
    String userId,
    int month,
    int year,
  ) async {
    if (kIsWeb) {
      final list = await _firestoreService.getTransactions();
      final filtered = list
          .where(
            (t) =>
                !t.isDeleted &&
                (t.userId.isEmpty || t.userId == userId) &&
                t.transactionDate.month == month &&
                t.transactionDate.year == year,
          )
          .toList();

      final groups = <String, Map<String, dynamic>>{};
      for (final t in filtered) {
        final key = '${t.categoryId}_${t.type}';
        if (groups.containsKey(key)) {
          groups[key]!['totalAmount'] =
              (groups[key]!['totalAmount'] as double) + t.amount;
        } else {
          groups[key] = {
            'categoryId': t.categoryId,
            'categoryName': t.categoryName,
            'totalAmount': t.amount,
            'type': t.type,
          };
        }
      }
      final resultList = groups.values.toList();
      resultList.sort(
        (a, b) =>
            (b['totalAmount'] as double).compareTo(a['totalAmount'] as double),
      );
      return resultList;
    }
    final db = await _databaseHelper.database;
    final userExpression = await _transactionUserExpression(db);
    final dateColumn = await _transactionDateColumn(db);

    final monthStr = month.toString().padLeft(2, '0');
    final yearStr = year.toString();

    final result = await db.rawQuery(
      '''
      SELECT 
        categoryId,
        categoryName,
        SUM(amount) as totalAmount,
        type
      FROM transactions
      WHERE $userExpression = ? AND (isDeleted = 0 OR isDeleted IS NULL)
      AND strftime('%m', $dateColumn) = ?
      AND strftime('%Y', $dateColumn) = ?
      GROUP BY categoryId, categoryName, type
      ORDER BY totalAmount DESC
      ''',
      [userId, monthStr, yearStr],
    );

    return result
        .map(
          (row) => {
            'categoryId': row['categoryId']?.toString() ?? '',
            'categoryName': row['categoryName']?.toString() ?? '',
            'totalAmount': (row['totalAmount'] as num?)?.toDouble() ?? 0.0,
            'type': row['type']?.toString() ?? 'expense',
          },
        )
        .toList();
  }

  // ==================== BASIC CRUD MIRRORED ====================
  // ==================== BASIC CRUD MIRRORED ====================

  Future<List<TransactionModel>> getAllTransactionsByUserId(
    String userId,
  ) async {
    if (kIsWeb) {
      final list = await _firestoreService.getTransactions();
      return list.where((t) => t.userId.isEmpty || t.userId == userId).toList();
    }
    final db = await _databaseHelper.database;
    final userExpression = await _transactionUserExpression(db);
    final dateColumn = await _transactionDateColumn(db);
    final updatedColumn = await _transactionUpdatedColumn(db);
    final rows = await db.rawQuery(
      'SELECT * FROM transactions WHERE $userExpression = ? AND (isDeleted = 0 OR isDeleted IS NULL) '
      'ORDER BY datetime($dateColumn) DESC, datetime($updatedColumn) DESC',
      [userId],
    );

    return rows.map(_transactionFromRow).toList();
  }

  Future<TransactionModel?> getTransactionById(String userId, String id) async {
    if (kIsWeb) {
      final list = await _firestoreService.getTransactions();
      final matched = list
          .where((t) => t.id == id && (t.userId.isEmpty || t.userId == userId))
          .toList();
      return matched.isNotEmpty ? matched.first : null;
    }
    final db = await _databaseHelper.database;
    final userExpression = await _transactionUserExpression(db);
    final rows = await db.query(
      'transactions',
      where: 'id = ? AND $userExpression = ?',
      whereArgs: [id, userId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _transactionFromRow(rows.first);
  }

  Future<void> upsertTransaction(TransactionModel transaction) async {
    if (transaction.userId.isEmpty) return;

    final oldTransaction = transaction.id.isEmpty
        ? null
        : await getTransactionById(transaction.userId, transaction.id);
    final now = DateTime.now();
    final resolvedWalletId = await _resolveTransactionWalletId(
      transaction.userId,
      transaction.walletId,
    );
    final normalized = transaction.copyWith(
      id: transaction.id.isEmpty
          ? now.millisecondsSinceEpoch.toString()
          : transaction.id,
      walletId: resolvedWalletId,
      updatedAt: now,
      createdAt:
          oldTransaction?.createdAt ??
          (transaction.createdAt.year < 2000 ? now : transaction.createdAt),
    );

    if (kIsWeb) {
      if (transaction.id.isEmpty) {
        await _firestoreService.addTransaction(normalized);
      } else {
        try {
          await _firestoreService.updateTransaction(normalized);
        } catch (_) {
          await _firestoreService.addTransaction(normalized);
        }
      }
      if (oldTransaction != null) {
        await _applyWalletImpact(oldTransaction, reverse: true);
      }
      await _applyWalletImpact(normalized);
      await _syncBudgetSpentForTransaction(normalized);
      if (oldTransaction != null) {
        await _syncBudgetSpentForTransaction(oldTransaction);
      }
      _notifyTransactionChanged(transaction.userId);
      return;
    }

    final db = await _databaseHelper.database;

    await db.insert(
      'transactions',
      _transactionToRow(normalized),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (oldTransaction != null) {
      await _applyWalletImpact(oldTransaction, reverse: true);
    }
    await _applyWalletImpact(normalized);
    await _syncBudgetSpentForTransaction(normalized);
    if (oldTransaction != null) {
      await _syncBudgetSpentForTransaction(oldTransaction);
    }

    _notifyTransactionChanged(transaction.userId);

    // Online write
    try {
      if (transaction.userId != demoUserId && await _isOnline()) {
        await _firestoreService.addTransaction(normalized);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ thÃƒÂªm giao dÃ¡Â»â€¹ch Firestore: $e",
      );
    }
  }

  Future<void> deleteTransaction(String userId, String id) async {
    final oldTransaction = await getTransactionById(userId, id);

    if (kIsWeb) {
      await _firestoreService.deleteTransaction(id);
      if (oldTransaction != null) {
        await _applyWalletImpact(oldTransaction, reverse: true);
        await _syncBudgetSpentForTransaction(oldTransaction);
      }
      _notifyTransactionChanged(userId);
      return;
    }

    final db = await _databaseHelper.database;
    final userExpression = await _transactionUserExpression(db);

    // Soft delete locally
    await db.update(
      'transactions',
      {
        'isDeleted': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
      },
      where: 'id = ? AND $userExpression = ?',
      whereArgs: [id, userId],
    );

    if (oldTransaction != null) {
      await _applyWalletImpact(oldTransaction, reverse: true);
      await _syncBudgetSpentForTransaction(oldTransaction);
    }
    _notifyTransactionChanged(userId);

    // Online soft delete
    try {
      if (userId != demoUserId && await _isOnline()) {
        await _firestoreService.deleteTransaction(id);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ xÃƒÂ³a giao dÃ¡Â»â€¹ch Firestore: $e",
      );
    }
  }

  Future<List<Budget>> getBudgets(String userId, int month, int year) async {
    if (kIsWeb) {
      final list = await _firestoreService.getBudgets();
      return list
          .where(
            (b) => b.userId == userId && b.month == month && b.year == year,
          )
          .toList();
    }
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
    if (kIsWeb) {
      final spent = await getSumExpenseByCategory(
        budget.userId,
        budget.categoryId,
        budget.month,
        budget.year,
      );
      final now = DateTime.now();
      final normalized = budget.copyWith(
        spentAmount: spent,
        updatedAt: now,
        createdAt: budget.createdAt.year < 2000 ? now : budget.createdAt,
        status: _resolveBudgetStatus(spent.round(), budget.limitAmount.round()),
      );
      if (budget.id.isEmpty) {
        await _firestoreService.addBudget(normalized);
      } else {
        try {
          await _firestoreService.updateBudget(normalized);
        } catch (_) {
          await _firestoreService.addBudget(normalized);
        }
      }
      _notifyTransactionChanged(budget.userId);
      return;
    }

    final db = await _databaseHelper.database;
    final spent = await getSumExpenseByCategory(
      budget.userId,
      budget.categoryId,
      budget.month,
      budget.year,
    );
    final now = DateTime.now();
    final normalized = budget.copyWith(
      spentAmount: spent,
      updatedAt: now,
      createdAt: budget.createdAt.year < 2000 ? now : budget.createdAt,
      status: _resolveBudgetStatus(spent.round(), budget.limitAmount.round()),
    );

    await db.insert(
      'budgets',
      normalized.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      if (budget.userId != demoUserId && await _isOnline()) {
        await _firestoreService.addBudget(normalized);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ thÃƒÂªm ngÃƒÂ¢n sÃƒÂ¡ch Firestore: $e",
      );
    }
    _notifyTransactionChanged(budget.userId);
  }

  Future<void> deleteBudget(String userId, String budgetId) async {
    if (kIsWeb) {
      await _firestoreService.deleteBudget(budgetId);
      _notifyTransactionChanged(userId);
      return;
    }

    final db = await _databaseHelper.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [budgetId]);

    try {
      if (await _isOnline()) {
        await _firestoreService.deleteBudget(budgetId);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ xÃƒÂ³a ngÃƒÂ¢n sÃƒÂ¡ch Firestore: $e",
      );
    }
    _notifyTransactionChanged(userId);
  }

  Future<void> refreshBudgetSpentForPeriod(
    String userId,
    int month,
    int year,
  ) async {
    if (kIsWeb) {
      final list = await _firestoreService.getBudgets();
      final filtered = list
          .where(
            (b) => b.userId == userId && b.month == month && b.year == year,
          )
          .toList();
      for (final budget in filtered) {
        final spent = await getSumExpenseByCategory(
          userId,
          budget.categoryId,
          month,
          year,
        );
        final updated = budget.copyWith(
          spentAmount: spent,
          updatedAt: DateTime.now(),
          status: _resolveBudgetStatus(
            spent.round(),
            budget.limitAmount.round(),
          ),
        );
        await _firestoreService.updateBudget(updated);
      }
      return;
    }

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
          'status': _resolveBudgetStatus(
            spent.round(),
            budget.limitAmount.round(),
          ),
          'isSynced': 0,
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
    if (kIsWeb) {
      final list = await _firestoreService.getTransactions();
      final filtered = list.where(
        (t) =>
            t.categoryId == catId &&
            t.type == 'expense' &&
            !t.isDeleted &&
            t.transactionDate.month == month &&
            t.transactionDate.year == year,
      );
      double total = 0.0;
      for (final t in filtered) {
        total += t.amount;
      }
      return total;
    }

    final db = await _databaseHelper.database;
    final userColumn = await _transactionUserColumn(db);
    final categoryColumn = await _transactionCategoryColumn(db);
    final dateColumn = await _transactionDateColumn(db);

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM transactions
      WHERE $userColumn = ? AND $categoryColumn = ? AND type = 'expense'
      AND (isDeleted = 0 OR isDeleted IS NULL)
      AND strftime('%m', $dateColumn) = ?
      AND strftime('%Y', $dateColumn) = ?
      ''',
      [userId, catId, month.toString().padLeft(2, '0'), year.toString()],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> _syncBudgetSpentForTransaction(
    TransactionModel transaction,
  ) async {
    if (kIsWeb) return;
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
    if (kIsWeb) return;
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
          'isSynced': 0,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<DateTime?> getLatestBudgetPeriod(String userId) async {
    if (kIsWeb) {
      final list = await _firestoreService.getBudgets();
      final filtered = list.where((b) => b.userId == userId).toList();
      if (filtered.isEmpty) return null;
      filtered.sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });
      return DateTime(filtered.first.year, filtered.first.month);
    }

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
    if (kIsWeb) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('savings')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return FinanceSavingItem(
          id: _asInt(data['id']) ?? 0,
          icon: data['icon']?.toString() ?? 'Ã°Å¸Å½Â¯',
          title: data['title']?.toString() ?? 'MÃ¡Â»Â¥c tiÃƒÂªu',
          currentAmount:
              _asInt(data['currentAmount'] ?? data['current_amount']) ?? 0,
          targetAmount:
              _asInt(data['targetAmount'] ?? data['target_amount']) ?? 0,
          deadline: _parseDate(
            data['deadline'] ?? data['targetDate'] ?? data['target_date'],
          ),
          color: _parseColor(data['colorValue'] ?? data['color_value']),
        );
      }).toList();
    }
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM savings WHERE COALESCE(userId, user_id) = ? ORDER BY id ASC',
      [userId],
    );

    return rows
        .map(
          (row) => FinanceSavingItem(
            id: _asInt(row['id']) ?? 0,
            icon: row['icon']?.toString() ?? 'Ã°Å¸Å½Â¯',
            title: row['title']?.toString() ?? 'MÃ¡Â»Â¥c tiÃƒÂªu',
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
    if (kIsWeb) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final targetEpoch = deadline.millisecondsSinceEpoch;
      final goal = SavingGoal(
        id: now.toString(),
        userId: userId,
        icon: icon,
        title: title,
        currentAmount: 0,
        targetAmount: targetAmount,
        targetDate: targetEpoch,
        createdAt: now,
        updatedAt: now,
        status: 'active',
        colorValue: color.value,
      );
      await _firestoreService.addSaving(goal);
      return;
    }
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final targetEpoch = deadline.millisecondsSinceEpoch;
    final payload = {
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
    };
    await _insertWithCompatibleColumns(
      db,
      'savings',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      if (userId != demoUserId && await _isOnline()) {
        final goal = _savingGoalFromRow(payload, userId);
        await _firestoreService.addSaving(goal);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ thÃƒÂªm tiÃ¡ÂºÂ¿t kiÃ¡Â»â€¡m Firestore: $e",
      );
    }
  }

  Future<List<FinanceInstallmentItem>> getInstallmentsByUserId(
    String userId,
  ) async {
    if (kIsWeb) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('installments')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return FinanceInstallmentItem(
          id: _asInt(data['id']) ?? 0,
          icon: data['icon']?.toString() ?? 'Ã°Å¸Â§Â¾',
          title: data['title']?.toString() ?? 'KÃ¡ÂºÂ¿ hoÃ¡ÂºÂ¡ch',
          totalAmount: _asInt(data['totalAmount'] ?? data['total_amount']) ?? 0,
          paidAmount: _asInt(data['paidAmount'] ?? data['paid_amount']) ?? 0,
          currentPeriod:
              _asInt(
                data['currentPeriod'] ??
                    data['current_period'] ??
                    data['paidPeriods'] ??
                    data['paid_periods'],
              ) ??
              0,
          totalPeriods:
              _asInt(data['totalPeriods'] ?? data['total_periods']) ?? 0,
          nextDueDate: _parseDate(
            data['nextDueDate'] ??
                data['nextDueDateEpoch'] ??
                data['next_due_date_epoch'],
          ),
          color: _parseColor(data['colorValue'] ?? data['color_value']),
        );
      }).toList();
    }
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM installments WHERE COALESCE(userId, user_id) = ? ORDER BY id ASC',
      [userId],
    );

    return rows
        .map(
          (row) => FinanceInstallmentItem(
            id: _asInt(row['id']) ?? 0,
            icon: row['icon']?.toString() ?? 'Ã°Å¸Â§Â¾',
            title: row['title']?.toString() ?? 'KÃ¡ÂºÂ¿ hoÃ¡ÂºÂ¡ch',
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
    if (kIsWeb) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final plan = InstallmentPlan(
        id: now.toString(),
        userId: userId,
        icon: icon,
        title: title,
        totalAmount: totalAmount,
        paidAmount: 0,
        monthlyPayment: totalPeriods > 0
            ? (totalAmount / totalPeriods).round()
            : 0,
        paidPeriods: 0,
        totalPeriods: totalPeriods,
        nextDueDate: nextDueDate.millisecondsSinceEpoch,
        createdAt: now,
        updatedAt: now,
        status: 'active',
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('installments')
          .doc(now.toString())
          .set({
            ...plan.toMap(),
            'colorValue': color.value,
            'color_value': color.value,
          });
      return;
    }
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextDueEpoch = nextDueDate.millisecondsSinceEpoch;
    final paidPeriods = 0;
    final monthlyPayment = totalPeriods > 0
        ? (totalAmount / totalPeriods).round()
        : 0;
    final payload = {
      'id': now,
      'userId': userId,
      'user_id': userId,
      'icon': icon,
      'title': title,
      'totalAmount': totalAmount,
      'total_amount': totalAmount,
      'paidAmount': 0,
      'paid_amount': 0,
      'monthlyPayment': monthlyPayment,
      'monthly_payment': monthlyPayment,
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
      'colorValue': color.value,
      'color_value': color.value,
      'createdAt': now,
      'created_at': now,
      'updatedAt': now,
      'updated_at': now,
      'status': 'active',
    };
    await _insertWithCompatibleColumns(
      db,
      'installments',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      if (userId != demoUserId && await _isOnline()) {
        final plan = _installmentPlanFromRow(payload, userId);
        await _firestoreService.addInstallment(plan);
      }
    } catch (e) {
      print("LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ trÃ¡ÂºÂ£ gÃƒÂ³p Firestore: $e");
    }
  }

  Future<List<FinanceDebtItem>> getDebtsByUserId(String userId) async {
    if (kIsWeb) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('debts')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return FinanceDebtItem(
          id: _asInt(data['id']) ?? 0,
          icon: data['icon']?.toString() ?? 'Ã°Å¸â€™Â°',
          title: data['title']?.toString() ?? 'KhoÃ¡ÂºÂ£n vay',
          lender:
              data['lender']?.toString() ??
              data['lenderName']?.toString() ??
              data['lender_name']?.toString() ??
              'KhÃƒÂ´ng rÃƒÂµ',
          totalAmount: _asInt(data['totalAmount'] ?? data['total_amount']) ?? 0,
          paidAmount: _asInt(data['paidAmount'] ?? data['paid_amount']) ?? 0,
          monthlyPayment:
              _asInt(data['monthlyPayment'] ?? data['monthly_payment']) ?? 0,
          dueDate: _parseDate(
            data['dueDate'] ??
                data['due_date'] ??
                data['nextDueDate'] ??
                data['next_due_date'],
          ),
          interestText:
              data['interestText']?.toString() ?? 'ChÃ†Â°a cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t',
          color: _parseColor(data['colorValue'] ?? data['color_value']),
        );
      }).toList();
    }
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM debts WHERE COALESCE(userId, user_id) = ? ORDER BY id ASC',
      [userId],
    );

    return rows
        .map(
          (row) => FinanceDebtItem(
            id: _asInt(row['id']) ?? 0,
            icon: row['icon']?.toString() ?? 'Ã°Å¸â€™Â°',
            title: row['title']?.toString() ?? 'KhoÃ¡ÂºÂ£n vay',
            lender: row['lender']?.toString() ?? 'KhÃƒÂ´ng rÃƒÂµ',
            totalAmount: _asInt(row['totalAmount'] ?? row['total_amount']) ?? 0,
            paidAmount: _asInt(row['paidAmount'] ?? row['paid_amount']) ?? 0,
            monthlyPayment:
                _asInt(row['monthlyPayment'] ?? row['monthly_payment']) ?? 0,
            dueDate: _parseDate(row['dueDate']),
            interestText:
                row['interestText']?.toString() ?? 'ChÃ†Â°a cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t',
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
    if (kIsWeb) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'id': now.toString(),
        'userId': userId,
        'icon': icon,
        'title': title,
        'lenderName': lender,
        'totalAmount': totalAmount,
        'paidAmount': 0,
        'monthlyPayment': monthlyPayment,
        'interestRate': 0.0,
        'nextDueDate': dueDate.millisecondsSinceEpoch,
        'createdAt': now,
        'updatedAt': now,
        'status': 'active',
        'interestText': interestText,
        'colorValue': color.value,
        'color_value': color.value,
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('debts')
          .doc(now.toString())
          .set(payload);
      return;
    }
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextDueEpoch = dueDate.millisecondsSinceEpoch;
    final payload = {
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
    };
    await _insertWithCompatibleColumns(
      db,
      'debts',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      if (userId != demoUserId && await _isOnline()) {
        final debt = _debtRecordFromRow(payload, userId);
        await _firestoreService.addDebt(debt);
      }
    } catch (e) {
      print("LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ vay nÃ¡Â»Â£ Firestore: $e");
    }
  }

  // ========== HOME PAGE FUNCTIONS ==========

  Future<Map<String, dynamic>> getHomeOverview(String userId) async {
    if (kIsWeb) {
      final now = DateTime.now();
      final list = await _firestoreService.getTransactions();
      final monthly = list
          .where(
            (t) =>
                !t.isDeleted &&
                (t.userId.isEmpty || t.userId == userId) &&
                t.transactionDate.month == now.month &&
                t.transactionDate.year == now.year,
          )
          .toList();

      double totalIncome = 0;
      double totalExpense = 0;
      for (final t in monthly) {
        if (t.type == 'income') {
          totalIncome += t.amount;
        } else {
          totalExpense += t.amount;
        }
      }
      final recentTransactions = await getRecentTransactions(userId, limit: 5);
      return {
        'income': totalIncome,
        'expense': totalExpense,
        'balance': totalIncome - totalExpense,
        'recentTransactions': recentTransactions,
      };
    }
    final now = DateTime.now();
    final db = await _databaseHelper.database;
    final userExpression = await _transactionUserExpression(db);
    final dateColumn = await _transactionDateColumn(db);

    final result = await db.rawQuery(
      '''
      SELECT 
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as totalIncome,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as totalExpense
      FROM transactions
      WHERE $userExpression = ? AND (isDeleted = 0 OR isDeleted IS NULL)
      AND strftime('%m', $dateColumn) = ?
      AND strftime('%Y', $dateColumn) = ?
      ''',
      [userId, now.month.toString().padLeft(2, '0'), now.year.toString()],
    );

    final totalIncome = (result.first['totalIncome'] as num?)?.toDouble() ?? 0;
    final totalExpense =
        (result.first['totalExpense'] as num?)?.toDouble() ?? 0;
    final balance = totalIncome - totalExpense;

    final recentTransactions = await getRecentTransactions(userId, limit: 5);

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': balance,
      'recentTransactions': recentTransactions,
    };
  }

  Future<List<TransactionModel>> getRecentTransactions(
    String userId, {
    int limit = 5,
  }) async {
    if (kIsWeb) {
      final list = await _firestoreService.getTransactions();
      return list
          .where((t) => t.userId.isEmpty || t.userId == userId)
          .take(limit)
          .toList();
    }
    final db = await _databaseHelper.database;
    final userExpression = await _transactionUserExpression(db);
    final dateColumn = await _transactionDateColumn(db);
    final updatedColumn = await _transactionUpdatedColumn(db);
    final rows = await db.rawQuery(
      'SELECT * FROM transactions WHERE $userExpression = ? AND (isDeleted = 0 OR isDeleted IS NULL) '
      'ORDER BY datetime($dateColumn) DESC, datetime($updatedColumn) DESC '
      'LIMIT ?',
      [userId, limit],
    );

    return rows.map(_transactionFromRow).toList();
  }

  Future<void> insertTransaction(TransactionModel transaction) async {
    if (transaction.userId.isEmpty) {
      return;
    }
    await upsertTransaction(transaction);
  }

  // ========== SAVING GOAL FUNCTIONS ==========

  Future<List<SavingGoal>> getAllSavingGoals(String userId) async {
    if (kIsWeb) {
      return await _firestoreService.getSavings();
    }
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM savings WHERE COALESCE(userId, user_id) = ? ORDER BY COALESCE(createdAt, created_at, id) DESC',
      [userId],
    );

    return rows.map((row) => _savingGoalFromRow(row, userId)).toList();
  }

  Future<SavingGoal?> getSavingGoalById(String userId, String goalId) async {
    if (kIsWeb) {
      final list = await _firestoreService.getSavings();
      final matched = list.where((s) => s.id == goalId).toList();
      return matched.isNotEmpty ? matched.first : null;
    }
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM savings WHERE id = ? AND COALESCE(userId, user_id) = ? LIMIT 1',
      [goalId, userId],
    );

    if (rows.isEmpty) return null;
    return _savingGoalFromRow(rows.first, userId);
  }

  Future<void> updateSavingGoal(SavingGoal goal) async {
    if (kIsWeb) {
      await _firestoreService.updateSaving(goal);
      return;
    }
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
        'isSynced': 0,
      },
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [goal.id, goal.userId],
    );

    try {
      if (goal.userId != demoUserId && await _isOnline()) {
        await _firestoreService.updateSaving(goal);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t tiÃ¡ÂºÂ¿t kiÃ¡Â»â€¡m Firestore: $e",
      );
    }
  }

  Future<void> deleteSavingGoal(String userId, String goalId) async {
    if (kIsWeb) {
      await _firestoreService.deleteSaving(goalId);
      return;
    }
    final db = await _databaseHelper.database;
    await db.delete(
      'savings',
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [goalId, userId],
    );

    try {
      if (userId != demoUserId && await _isOnline()) {
        await _firestoreService.deleteSaving(goalId);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ xÃƒÂ³a tiÃ¡ÂºÂ¿t kiÃ¡Â»â€¡m Firestore: $e",
      );
    }
  }

  // ========== DEBT RECORD FUNCTIONS ==========

  Future<List<DebtRecord>> getAllDebtRecords(String userId) async {
    if (kIsWeb) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('debts')
          .get();
      return snapshot.docs
          .map((doc) => DebtRecord.fromMap(doc.data()))
          .toList();
    }
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM debts WHERE COALESCE(userId, user_id) = ? ORDER BY COALESCE(createdAt, created_at, id) DESC',
      [userId],
    );

    return rows.map((row) => _debtRecordFromRow(row, userId)).toList();
  }

  Future<DebtRecord?> getDebtRecordById(String userId, String debtId) async {
    if (kIsWeb) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('debts')
          .doc(debtId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return DebtRecord.fromMap(doc.data()!);
    }
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM debts WHERE id = ? AND COALESCE(userId, user_id) = ? LIMIT 1',
      [debtId, userId],
    );

    if (rows.isEmpty) return null;
    return _debtRecordFromRow(rows.first, userId);
  }

  Future<void> insertDebtRecord(DebtRecord debt) async {
    if (kIsWeb) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final docId = debt.id.isNotEmpty ? debt.id : now.toString();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(debt.userId)
          .collection('debts')
          .doc(docId)
          .set({
            ...debt.toMap(),
            'id': docId,
            'colorValue': Colors.blue.value,
            'color_value': Colors.blue.value,
          }, SetOptions(merge: true));
      return;
    }
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'id': int.tryParse(debt.id) ?? now,
      'userId': debt.userId,
      'user_id': debt.userId,
      'icon': 'Ã°Å¸â€™Â°',
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
      'colorValue': Colors.blue.value,
      'color_value': Colors.blue.value,
      'createdAt': debt.createdAt == 0 ? now : debt.createdAt,
      'created_at': debt.createdAt == 0 ? now : debt.createdAt,
      'updatedAt': now,
      'updated_at': now,
      'status': debt.status,
    };
    await _insertWithCompatibleColumns(
      db,
      'debts',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      if (debt.userId != demoUserId && await _isOnline()) {
        await _firestoreService.addDebt(debt);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ thÃƒÂªm vay nÃ¡Â»Â£ Firestore: $e",
      );
    }
  }

  Future<void> updateDebtRecord(DebtRecord debt) async {
    if (kIsWeb) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(debt.userId)
          .collection('debts')
          .doc(debt.id)
          .update(debt.toMap());
      return;
    }
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
        'isSynced': 0,
      },
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [debt.id, debt.userId],
    );

    try {
      if (debt.userId != demoUserId && await _isOnline()) {
        await _firestoreService.updateDebt(debt);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t vay nÃ¡Â»Â£ Firestore: $e",
      );
    }
  }

  Future<void> deleteDebtRecord(String userId, String debtId) async {
    if (kIsWeb) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('debts')
          .doc(debtId)
          .delete();
      return;
    }
    final db = await _databaseHelper.database;
    await db.delete(
      'debts',
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [debtId, userId],
    );

    try {
      if (userId != demoUserId && await _isOnline()) {
        await _firestoreService.deleteDebt(debtId);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ xÃƒÂ³a vay nÃ¡Â»Â£ Firestore: $e",
      );
    }
  }

  // ========== INSTALLMENT PLAN FUNCTIONS ==========

  Future<List<InstallmentPlan>> getAllInstallmentPlans(String userId) async {
    if (kIsWeb) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('installments')
          .get();
      return snapshot.docs
          .map((doc) => InstallmentPlan.fromMap(doc.data()))
          .toList();
    }
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM installments WHERE COALESCE(userId, user_id) = ? ORDER BY COALESCE(createdAt, created_at, id) DESC',
      [userId],
    );

    return rows.map((row) => _installmentPlanFromRow(row, userId)).toList();
  }

  Future<InstallmentPlan?> getInstallmentPlanById(
    String userId,
    String planId,
  ) async {
    if (kIsWeb) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('installments')
          .doc(planId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return InstallmentPlan.fromMap(doc.data()!);
    }
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM installments WHERE id = ? AND COALESCE(userId, user_id) = ? LIMIT 1',
      [planId, userId],
    );

    if (rows.isEmpty) return null;
    return _installmentPlanFromRow(rows.first, userId);
  }

  Future<void> insertInstallmentPlan(InstallmentPlan plan) async {
    if (kIsWeb) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final docId = plan.id.isNotEmpty ? plan.id : now.toString();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(plan.userId)
          .collection('installments')
          .doc(docId)
          .set({
            ...plan.toMap(),
            'id': docId,
            'colorValue': Colors.purple.value,
            'color_value': Colors.purple.value,
          }, SetOptions(merge: true));
      return;
    }
    final db = await _databaseHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'id': int.tryParse(plan.id) ?? now,
      'userId': plan.userId,
      'user_id': plan.userId,
      'icon': plan.icon,
      'title': plan.title,
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
      'colorValue': Colors.purple.value,
      'color_value': Colors.purple.value,
      'createdAt': plan.createdAt == 0 ? now : plan.createdAt,
      'created_at': plan.createdAt == 0 ? now : plan.createdAt,
      'updatedAt': now,
      'updated_at': now,
      'status': plan.status,
    };
    await _insertWithCompatibleColumns(
      db,
      'installments',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      if (plan.userId != demoUserId && await _isOnline()) {
        await _firestoreService.addInstallment(plan);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ thÃƒÂªm trÃ¡ÂºÂ£ gÃƒÂ³p Firestore: $e",
      );
    }
  }

  Future<void> updateInstallmentPlan(InstallmentPlan plan) async {
    if (kIsWeb) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(plan.userId)
          .collection('installments')
          .doc(plan.id)
          .update(plan.toMap());
      return;
    }
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
        'isSynced': 0,
      },
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [plan.id, plan.userId],
    );

    try {
      if (plan.userId != demoUserId && await _isOnline()) {
        await _firestoreService.updateInstallment(plan);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ cÃ¡ÂºÂ­p nhÃ¡ÂºÂ­t trÃ¡ÂºÂ£ gÃƒÂ³p Firestore: $e",
      );
    }
  }

  Future<void> deleteInstallmentPlan(String userId, String planId) async {
    if (kIsWeb) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('installments')
          .doc(planId)
          .delete();
      return;
    }
    final db = await _databaseHelper.database;
    await db.delete(
      'installments',
      where: 'id = ? AND COALESCE(userId, user_id) = ?',
      whereArgs: [planId, userId],
    );

    try {
      if (userId != demoUserId && await _isOnline()) {
        await _firestoreService.deleteInstallment(planId);
      }
    } catch (e) {
      print(
        "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ xÃƒÂ³a trÃ¡ÂºÂ£ gÃƒÂ³p Firestore: $e",
      );
    }
  }

  // ========== WALLET FUNCTIONS ==========

  Future<List<Map<String, dynamic>>> getWalletsByUserId(String userId) async {
    if (kIsWeb) {
      final list = await _firestoreService.getWallets();
      return list
          .where((wallet) => wallet.userId.isEmpty || wallet.userId == userId)
          .map((w) => w.toMap())
          .toList();
    }
    final db = await _databaseHelper.database;
    return await db.rawQuery(
      'SELECT * FROM wallets WHERE COALESCE(userId, user_id) = ? ORDER BY name ASC',
      [userId],
    );
  }

  Future<double> getTotalWalletBalance(String userId) async {
    if (kIsWeb) {
      final list = await _firestoreService.getWallets();
      return list
          .where((wallet) => wallet.userId.isEmpty || wallet.userId == userId)
          .fold<double>(0.0, (sum, w) => sum + w.balance);
    }
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(balance) AS total FROM wallets WHERE COALESCE(userId, user_id) = ?',
      [userId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTransactionCountByUserId(String userId) async {
    if (kIsWeb) {
      final list = await _firestoreService.getTransactions();
      return list.where((t) => t.userId.isEmpty || t.userId == userId).length;
    }
    final db = await _databaseHelper.database;
    final userExpression = await _transactionUserExpression(db);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE $userExpression = ? AND (isDeleted = 0 OR isDeleted IS NULL)',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> upsertWallet(WalletModel wallet) async {
    if (kIsWeb) {
      try {
        await _firestoreService.updateWallet(wallet);
      } catch (_) {
        await _firestoreService.addWallet(wallet);
      }
      return;
    }
    final db = await _databaseHelper.database;
    await db.insert(
      'wallets',
      wallet.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      if (wallet.userId != demoUserId && await _isOnline()) {
        await _firestoreService.addWallet(wallet);
      }
    } catch (e) {
      print("LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ vÃƒÂ­ lÃƒÂªn Firestore: $e");
    }
  }

  Future<void> ensureDefaultWalletsForUser(String userId) async {
    if (kIsWeb) {
      final wallets = (await _firestoreService.getWallets())
          .where((wallet) => wallet.userId.isEmpty || wallet.userId == userId)
          .toList();
      if (wallets.isEmpty) {
        final now = DateTime.now();

        final cashWallet = WalletModel(
          id: 'wallet_cash_$userId',
          userId: userId,
          name: 'Ti\u1ec1n m\u1eb7t',
          balance: 0,
          type: 'cash',
          color: Colors.green.value,
          icon: 'cash',
          isDefault: true,
          createdAt: now,
          updatedAt: now,
        );

        final bankWallet = WalletModel(
          id: 'wallet_bank_$userId',
          userId: userId,
          name: 'T\u00e0i kho\u1ea3n ng\u00e2n h\u00e0ng',
          balance: 0,
          type: 'bank',
          color: Colors.blue.value,
          icon: 'bank',
          isDefault: false,
          createdAt: now,
          updatedAt: now,
        );

        await _firestoreService.addWallet(cashWallet);
        await _firestoreService.addWallet(bankWallet);
      }
      return;
    }
    final db = await _databaseHelper.database;
    final walletCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM wallets WHERE COALESCE(userId, user_id) = ?',
            [userId],
          ),
        ) ??
        0;

    if (walletCount == 0) {
      final now = DateTime.now();

      final cashWallet = WalletModel(
        id: 'wallet_cash_$userId',
        userId: userId,
        name: 'Ti\u1ec1n m\u1eb7t',
        balance: 0,
        type: 'cash',
        color: Colors.green.value,
        icon: 'cash',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );

      final bankWallet = WalletModel(
        id: 'wallet_bank_$userId',
        userId: userId,
        name: 'T\u00e0i kho\u1ea3n ng\u00e2n h\u00e0ng',
        balance: 0,
        type: 'bank',
        color: Colors.blue.value,
        icon: 'bank',
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      );

      await db.transaction((txn) async {
        await txn.insert('wallets', cashWallet.toSqliteMap());
        await txn.insert('wallets', bankWallet.toSqliteMap());
      });

      try {
        if (userId != demoUserId && await _isOnline()) {
          await _firestoreService.addWallet(cashWallet);
          await _firestoreService.addWallet(bankWallet);
        }
      } catch (e) {
        print(
          "LÃ¡Â»â€”i Ã„â€˜Ã¡Â»â€œng bÃ¡Â»â„¢ tÃ¡ÂºÂ¡o vÃƒÂ­ mÃ¡ÂºÂ·c Ã„â€˜Ã¡Â»â€¹nh Firestore: $e",
        );
      }
    }
  }

  Future<String> _resolveTransactionWalletId(
    String userId,
    String walletId,
  ) async {
    if (walletId.isNotEmpty) {
      final wallet = await _getWalletById(userId, walletId);
      if (wallet != null) {
        return wallet.id;
      }
    }

    final fallbackWallet = await _getDefaultWallet(userId);
    return fallbackWallet?.id ?? walletId;
  }

  Future<WalletModel?> _getDefaultWallet(String userId) async {
    await ensureDefaultWalletsForUser(userId);
    final wallets = await getWalletsByUserId(userId);
    if (wallets.isEmpty) return null;

    final models = wallets.map((row) => WalletModel.fromMap(row)).toList();
    for (final wallet in models) {
      if (wallet.isDefault) return wallet;
    }
    for (final wallet in models) {
      if (wallet.type == 'cash') return wallet;
    }
    return models.first;
  }

  Future<WalletModel?> _getWalletById(String userId, String walletId) async {
    if (walletId.isEmpty) return null;

    final wallets = await getWalletsByUserId(userId);
    for (final row in wallets) {
      final wallet = WalletModel.fromMap(row);
      if (wallet.id == walletId) {
        return wallet;
      }
    }
    return null;
  }

  double _walletDeltaForTransaction(TransactionModel transaction) {
    switch (transaction.type) {
      case 'income':
      case 'borrow':
        return transaction.amount;
      case 'expense':
      case 'lend':
        return -transaction.amount;
      default:
        return 0;
    }
  }

  Future<void> _applyWalletImpact(
    TransactionModel transaction, {
    bool reverse = false,
  }) async {
    final delta = _walletDeltaForTransaction(transaction);
    if (delta == 0 || transaction.userId.isEmpty) return;

    final walletId = await _resolveTransactionWalletId(
      transaction.userId,
      transaction.walletId,
    );
    if (walletId.isEmpty) return;

    final wallet = await _getWalletById(transaction.userId, walletId);
    if (wallet == null) return;

    final effectiveDelta = reverse ? -delta : delta;
    await upsertWallet(
      wallet.copyWith(
        balance: wallet.balance + effectiveDelta,
        updatedAt: DateTime.now(),
      ),
    );
  }
  Future<void> _cleanCorruptedTransactions(String userId) async {
    await ensureDefaultWalletsForUser(userId);
    final db = await _databaseHelper.database;
    
    // 1. Get all wallets of the user to know the valid wallet IDs
    final walletsRaw = await getWalletsByUserId(userId);
    final validWalletIds = walletsRaw.map((w) => w['id']?.toString() ?? '').toSet();
    if (validWalletIds.isEmpty) return; // Don't delete if wallets aren't loaded yet

    // 2. Find transactions belonging to the user but with invalid wallet ID
    final userExpression = await _transactionUserExpression(db);
    final corruptedRows = await db.query(
      'transactions',
      where: '$userExpression = ? AND (isDeleted = 0 OR isDeleted IS NULL)',
      whereArgs: [userId],
    );

    final List<String> idsToDelete = [];
    for (final row in corruptedRows) {
      final walletId = row['walletId']?.toString() ?? row['wallet_id']?.toString() ?? '';
      if (!validWalletIds.contains(walletId)) {
        final id = row['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          idsToDelete.add(id);
        }
      }
    }

    if (idsToDelete.isEmpty) return;

    print('Cleaning up ${idsToDelete.length} corrupted transactions for user $userId');

    // 3. Delete from local SQLite
    await db.transaction((txn) async {
      for (final id in idsToDelete) {
        await txn.delete(
          'transactions',
          where: 'id = ? AND $userExpression = ?',
          whereArgs: [id, userId],
        );
      }
    });

    // 4. Delete from Firestore
    for (final id in idsToDelete) {
      try {
        await _firestoreService.deleteTransaction(id);
      } catch (e) {
        print('Error deleting corrupted remote transaction $id: $e');
      }
    }
  }

  // ==================== COOPERATION ENGINE: SYNC ENGINE ====================

  Future<void> syncWithFirebase(String userId) async {
    if (kIsWeb) return;
    if (userId.isEmpty || userId == demoUserId) return;
    final online = await _isOnline();
    if (!online) return;

    try {
      final db = await _databaseHelper.database;
      await _syncDefaultCategoriesToCloud(userId);
      await _cleanCorruptedTransactions(userId);

      // 1. SYNC WALLETS
      final localWalletsRaw = await getWalletsByUserId(userId);
      final localWallets = localWalletsRaw
          .map((row) => WalletModel.fromMap(row))
          .toList();
      final remoteWallets = await _firestoreService.getWallets();
      final localWalletById = {for (final item in localWallets) item.id: item};
      final remoteWalletById = {
        for (final item in remoteWallets) item.id: item,
      };

      final walletsToPush = <WalletModel>[];
      for (final local in localWallets) {
        final remote = remoteWalletById[local.id];
        if (remote == null || local.updatedAt.isAfter(remote.updatedAt)) {
          walletsToPush.add(local);
        }
      }
      for (final remote in remoteWallets) {
        final local = localWalletById[remote.id];
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          await db.insert(
            'wallets',
            remote.toSqliteMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // 2. SYNC TRANSACTIONS
      final txSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .get();
      final remoteTx = txSnapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList();

      final localTxRaw = await db.query(
        'transactions',
        where: 'COALESCE(userId, user_id) = ?',
        whereArgs: [userId],
      );
      final localTx = localTxRaw.map(_transactionFromRow).toList();
      final localTxById = {for (final item in localTx) item.id: item};
      final remoteTxById = {for (final item in remoteTx) item.id: item};

      final txToPush = <TransactionModel>[];
      for (final local in localTx) {
        final remote = remoteTxById[local.id];
        if (remote == null || local.updatedAt.isAfter(remote.updatedAt)) {
          txToPush.add(local);
        }
      }
      for (final remote in remoteTx) {
        final local = localTxById[remote.id];
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          final remotePayload = _transactionToRow(remote);
          remotePayload['isSynced'] = 1;
          await db.insert(
            'transactions',
            remotePayload,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // 3. SYNC BUDGETS
      final budgetSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .get();
      final remoteBudgets = budgetSnapshot.docs
          .map((doc) => Budget.fromMap(doc.data(), doc.id))
          .toList();

      final localBudgetsRaw = await db.query(
        'budgets',
        where: 'COALESCE(userId, user_id) = ?',
        whereArgs: [userId],
      );
      final localBudgets = localBudgetsRaw
          .map((row) => _budgetFromRow(row, userId))
          .toList();
      final localBudgetById = {for (final item in localBudgets) item.id: item};
      final remoteBudgetById = {
        for (final item in remoteBudgets) item.id: item,
      };

      final budgetsToPush = <Budget>[];
      for (final local in localBudgets) {
        final remote = remoteBudgetById[local.id];
        if (remote == null || local.updatedAt.isAfter(remote.updatedAt)) {
          budgetsToPush.add(local);
        }
      }
      for (final remote in remoteBudgets) {
        final local = localBudgetById[remote.id];
        if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
          final remotePayload = remote.toSqliteMap();
          remotePayload['isSynced'] = 1;
          await db.insert(
            'budgets',
            remotePayload,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // 4. SYNC SAVINGS
      final savingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('savings')
          .get();
      final remoteSavings = savingSnapshot.docs
          .map((doc) => SavingGoal.fromMap(doc.data()))
          .toList();

      final localSavings = await getAllSavingGoals(userId);
      final localSavingById = {for (final item in localSavings) item.id: item};
      final remoteSavingById = {
        for (final item in remoteSavings) item.id: item,
      };

      final savingsToPush = <SavingGoal>[];
      for (final local in localSavings) {
        final remote = remoteSavingById[local.id];
        if (remote == null || local.updatedAt > remote.updatedAt) {
          savingsToPush.add(local);
        }
      }
      for (final remote in remoteSavings) {
        final local = localSavingById[remote.id];
        if (local == null || remote.updatedAt > local.updatedAt) {
          await _insertWithCompatibleColumns(db, 'savings', {
            'id': int.tryParse(remote.id) ?? remote.createdAt,
            'userId': userId,
            'user_id': userId,
            'icon': remote.icon,
            'title': remote.title,
            'currentAmount': remote.currentAmount,
            'current_amount': remote.currentAmount,
            'targetAmount': remote.targetAmount,
            'target_amount': remote.targetAmount,
            'deadline': DateTime.fromMillisecondsSinceEpoch(
              remote.targetDate,
            ).toIso8601String(),
            'targetDate': remote.targetDate,
            'target_date': remote.targetDate,
            'createdAt': remote.createdAt,
            'created_at': remote.createdAt,
            'updatedAt': remote.updatedAt,
            'updated_at': remote.updatedAt,
            'status': remote.status,
            'isSynced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 5. SYNC DEBTS
      final debtSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('debts')
          .get();
      final remoteDebts = debtSnapshot.docs
          .map((doc) => DebtRecord.fromMap(doc.data()))
          .toList();

      final localDebts = await getAllDebtRecords(userId);
      final localDebtById = {for (final item in localDebts) item.id: item};
      final remoteDebtById = {for (final item in remoteDebts) item.id: item};

      final debtsToPush = <DebtRecord>[];
      for (final local in localDebts) {
        final remote = remoteDebtById[local.id];
        if (remote == null || local.updatedAt > remote.updatedAt) {
          debtsToPush.add(local);
        }
      }
      for (final remote in remoteDebts) {
        final local = localDebtById[remote.id];
        if (local == null || remote.updatedAt > local.updatedAt) {
          await _insertWithCompatibleColumns(db, 'debts', {
            'id': int.tryParse(remote.id) ?? remote.createdAt,
            'userId': userId,
            'user_id': userId,
            'title': remote.title,
            'lender': remote.lenderName,
            'lenderName': remote.lenderName,
            'lender_name': remote.lenderName,
            'totalAmount': remote.totalAmount,
            'total_amount': remote.totalAmount,
            'paidAmount': remote.paidAmount,
            'paid_amount': remote.paidAmount,
            'monthlyPayment': remote.monthlyPayment,
            'monthly_payment': remote.monthlyPayment,
            'interestRate': remote.interestRate,
            'interest_rate': remote.interestRate,
            'dueDate': DateTime.fromMillisecondsSinceEpoch(
              remote.nextDueDate,
            ).toIso8601String(),
            'due_date': DateTime.fromMillisecondsSinceEpoch(
              remote.nextDueDate,
            ).toIso8601String(),
            'nextDueDate': remote.nextDueDate,
            'next_due_date': remote.nextDueDate,
            'createdAt': remote.createdAt,
            'created_at': remote.createdAt,
            'updatedAt': remote.updatedAt,
            'updated_at': remote.updatedAt,
            'status': remote.status,
            'isSynced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 6. SYNC INSTALLMENTS
      final installmentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('installments')
          .get();
      final remoteInstallments = installmentSnapshot.docs
          .map((doc) => InstallmentPlan.fromMap(doc.data()))
          .toList();

      final localInstallments = await getAllInstallmentPlans(userId);
      final localInstallmentById = {
        for (final item in localInstallments) item.id: item,
      };
      final remoteInstallmentById = {
        for (final item in remoteInstallments) item.id: item,
      };

      final installmentsToPush = <InstallmentPlan>[];
      for (final local in localInstallments) {
        final remote = remoteInstallmentById[local.id];
        if (remote == null || local.updatedAt > remote.updatedAt) {
          installmentsToPush.add(local);
        }
      }
      for (final remote in remoteInstallments) {
        final local = localInstallmentById[remote.id];
        if (local == null || remote.updatedAt > local.updatedAt) {
          await _insertWithCompatibleColumns(db, 'installments', {
            'id': int.tryParse(remote.id) ?? remote.createdAt,
            'userId': userId,
            'user_id': userId,
            'icon': remote.icon,
            'title': remote.title,
            'totalAmount': remote.totalAmount,
            'total_amount': remote.totalAmount,
            'paidAmount': remote.paidAmount,
            'paid_amount': remote.paidAmount,
            'monthlyPayment': remote.monthlyPayment,
            'monthly_payment': remote.monthlyPayment,
            'currentPeriod': remote.paidPeriods,
            'current_period': remote.paidPeriods,
            'paidPeriods': remote.paidPeriods,
            'paid_periods': remote.paidPeriods,
            'totalPeriods': remote.totalPeriods,
            'total_periods': remote.totalPeriods,
            'nextDueDate': DateTime.fromMillisecondsSinceEpoch(
              remote.nextDueDate,
            ).toIso8601String(),
            'next_due_date': DateTime.fromMillisecondsSinceEpoch(
              remote.nextDueDate,
            ).toIso8601String(),
            'nextDueDateEpoch': remote.nextDueDate,
            'next_due_date_epoch': remote.nextDueDate,
            'createdAt': remote.createdAt,
            'created_at': remote.createdAt,
            'updatedAt': remote.updatedAt,
            'updated_at': remote.updatedAt,
            'status': remote.status,
            'isSynced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Execute batch write to Firestore for items updated locally
      if (walletsToPush.isNotEmpty ||
          txToPush.isNotEmpty ||
          budgetsToPush.isNotEmpty ||
          savingsToPush.isNotEmpty ||
          debtsToPush.isNotEmpty ||
          installmentsToPush.isNotEmpty) {
        await _firestoreService.batchWrite(
          wallets: walletsToPush,
          transactions: txToPush,
          budgets: budgetsToPush,
          savings: savingsToPush,
          debts: debtsToPush,
          installments: installmentsToPush,
        );
      }

      _notifyTransactionChanged(userId);
    } catch (e) {
      print("syncWithFirebase error: $e");
    }
  }

  Future<void> _syncDefaultCategoriesToCloud(String userId) async {
    final remoteCategories = await _firestoreService.getCategories();
    final remoteIds = remoteCategories.map((item) => item.id).toSet();
    final missingDefaults = CategoryData.getAllCategories()
        .where((item) => !remoteIds.contains(item.id))
        .map((item) => item.copyWith(userId: userId))
        .toList();

    if (missingDefaults.isEmpty) {
      return;
    }

    await _firestoreService.batchWrite(categories: missingDefaults);
  }
  // ========== AUTH SESSION FUNCTIONS ==========

  Future<Map<String, dynamic>?> getAuthSessionByUserId(String userId) async {
    if (kIsWeb) {
      final profile = await _firestoreService.getProfile();
      if (profile != null) return profile;
      final user = FirebaseAuth.instance.currentUser;
      return {
        'userId': userId,
        'user_id': userId,
        'email': user?.email ?? '',
        'displayName': user?.displayName ?? '',
        'photoURL': user?.photoURL ?? '',
        'photo_url': user?.photoURL ?? '',
        'role': 'user',
      };
    }
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
    if (kIsWeb) {
      await _firestoreService.updateProfile(payload);
      return;
    }
    final db = await _databaseHelper.database;
    await db.insert(
      'auth_session',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> submitAppFeedback(AppFeedback feedback) async {
    await _firestoreService.addFeedback(feedback);
  }

  // ========== HELPER FUNCTIONS FOR MODEL CONVERSION ==========

  SavingGoal _savingGoalFromRow(Map<String, Object?> row, String userId) {
    return SavingGoal(
      id: row['id']?.toString() ?? '',
      userId: userId,
      title: row['title']?.toString() ?? 'MÃ¡Â»Â¥c tiÃƒÂªu',
      icon: row['icon']?.toString() ?? 'Ã°Å¸Å½Â¯',
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
      title: row['title']?.toString() ?? 'KhoÃ¡ÂºÂ£n vay',
      lenderName:
          row['lender']?.toString() ??
          row['lenderName']?.toString() ??
          row['lender_name']?.toString() ??
          'KhÃƒÂ´ng rÃƒÂµ',
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
      title: row['title']?.toString() ?? 'KÃ¡ÂºÂ¿ hoÃ¡ÂºÂ¡ch trÃ¡ÂºÂ£ gÃƒÂ³p',
      icon: row['icon']?.toString() ?? 'Ã°Å¸Â§Â¾',
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

  Map<String, dynamic> _transactionToRow(TransactionModel transaction) {
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
      'isDeleted': transaction.isDeleted ? 1 : 0,
      'receiptImageUrl': transaction.receiptImageUrl,
      'tags': transaction.tags != null ? jsonEncode(transaction.tags) : null,
      'recurringId': transaction.recurringId,
    };
  }

  TransactionModel _transactionFromRow(Map<String, Object?> row) {
    List<String>? parsedTags;
    final rawTags = row['tags']?.toString();
    if (rawTags != null && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

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
      isDeleted: _asInt(row['isDeleted']) == 1,
      receiptImageUrl: row['receiptImageUrl']?.toString(),
      tags: parsedTags,
      recurringId: row['recurringId']?.toString(),
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
          : category?.name ?? 'KhÃƒÂ´ng rÃƒÂµ',
      icon: row['icon']?.toString().isNotEmpty == true
          ? row['icon'].toString()
          : category?.icon ?? 'Ã°Å¸ÂÂ·Ã¯Â¸Â',
      month: _asInt(row['month']) ?? DateTime.now().month,
      year: _asInt(row['year']) ?? DateTime.now().year,
      limitAmount: limitAmount.toDouble(),
      spentAmount: spentAmount.toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      isActive: true,
      status: row['status']?.toString().isNotEmpty == true
          ? row['status'].toString()
          : '',
    );
  }

  String _resolveCategoryName(Object? categoryId) {
    return _findCategory(categoryId?.toString() ?? '')?.name ??
        'KhÃƒÂ´ng rÃƒÂµ';
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
    if (ratio >= 1.0) return 'danger';
    if (ratio >= 0.9) return 'warning';
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

  Future<String> _transactionUserColumn(Database db) async {
    final columns = await _getTableColumns(db, 'transactions');
    if (columns.contains('userId')) return 'userId';
    if (columns.contains('user_id')) return 'user_id';
    return 'userId';
  }

  Future<String> _transactionUserExpression(Database db) async {
    final columns = await _getTableColumns(db, 'transactions');
    final hasUserId = columns.contains('userId');
    final hasLegacyUserId = columns.contains('user_id');

    if (hasUserId && hasLegacyUserId) {
      return 'COALESCE(userId, user_id)';
    }
    if (hasUserId) {
      return 'userId';
    }
    if (hasLegacyUserId) {
      return 'user_id';
    }
    return 'userId';
  }

  Future<String> _transactionCategoryColumn(Database db) async {
    final columns = await _getTableColumns(db, 'transactions');
    if (columns.contains('categoryId')) return 'categoryId';
    if (columns.contains('category_id')) return 'category_id';
    return 'categoryId';
  }

  Future<String> _transactionDateColumn(Database db) async {
    final columns = await _getTableColumns(db, 'transactions');
    if (columns.contains('transactionDate')) return 'transactionDate';
    if (columns.contains('transaction_date')) return 'transaction_date';
    if (columns.contains('date')) return 'date';
    return 'transactionDate';
  }

  Future<String> _transactionUpdatedColumn(Database db) async {
    final columns = await _getTableColumns(db, 'transactions');
    if (columns.contains('updatedAt')) return 'updatedAt';
    if (columns.contains('updated_at')) return 'updated_at';
    return await _transactionDateColumn(db);
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
