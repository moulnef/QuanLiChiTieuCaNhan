import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/local/database_helper.dart';
import '../data/remote/firestore_service.dart';
import '../data/repository/finance_repository.dart';
import '../domain/model/transaction_model.dart';
import '../domain/model/budget.dart';
import '../domain/model/saving.dart';
import '../domain/model/debt_record.dart';
import '../domain/model/installment_plan.dart';

class SyncResult {
  final int successCount;
  final int failCount;
  final DateTime syncTime;

  SyncResult({
    required this.successCount,
    required this.failCount,
    required this.syncTime,
  });
}

enum SyncStatus { idle, syncing, success, error, offline }

class SyncEvent {
  final SyncStatus status;
  final String? error;
  SyncEvent(this.status, [this.error]);
}

class SyncService with WidgetsBindingObserver {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final FinanceRepository _financeRepository = FinanceRepository();
  StreamSubscription? _connectivitySubscription;
  bool _wasOnline = true;

  Timer? _periodicTimer;
  Timer? _debounceTimer;
  String? _currentUserId;

  final StreamController<SyncEvent> _syncEventController =
      StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get syncEventStream => _syncEventController.stream;

  Future<int> getPendingCount([String? userId]) async {
    if (kIsWeb) return 0;
    try {
      final targetUserId = userId ?? _currentUserId;
      if (targetUserId == null || targetUserId.isEmpty) return 0;
      final db = await DatabaseHelper.instance.database;
      int count = 0;

      final tables = [
        'transactions',
        'budgets',
        'savings',
        'debts',
        'installments',
      ];
      for (final table in tables) {
        final res = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM $table WHERE (isSynced = 0 OR isSynced IS NULL) AND COALESCE(userId, user_id) = ?',
          [targetUserId],
        );
        count += Sqflite.firstIntValue(res) ?? 0;
      }
      return count;
    } catch (e) {
      print('Lỗi getPendingCount: $e');
      return 0;
    }
  }

  Future<SyncResult> syncNow(String userId) async {
    final now = DateTime.now();
    if (kIsWeb || userId.isEmpty) {
      return SyncResult(successCount: 0, failCount: 0, syncTime: now);
    }

    _emitEvent(SyncStatus.syncing);

    int successCount = 0;
    int failCount = 0;

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Transactions
      final txRows = await db.query(
        'transactions',
        where:
            '(isSynced = 0 OR isSynced IS NULL) AND COALESCE(userId, user_id) = ?',
        whereArgs: [userId],
      );
      final List<TransactionModel> txList = [];
      for (final row in txRows) {
        try {
          txList.add(_transactionFromRow(row));
        } catch (e) {
          print('Lỗi map transaction: $e');
          failCount++;
        }
      }

      // 2. Budgets
      final budgetRows = await db.query(
        'budgets',
        where:
            '(isSynced = 0 OR isSynced IS NULL) AND COALESCE(userId, user_id) = ?',
        whereArgs: [userId],
      );
      final List<Budget> budgetList = [];
      for (final row in budgetRows) {
        try {
          budgetList.add(Budget.fromMap(row, row['id']?.toString()));
        } catch (e) {
          print('Lỗi map budget: $e');
          failCount++;
        }
      }

      // 3. Savings
      final savingRows = await db.query(
        'savings',
        where:
            '(isSynced = 0 OR isSynced IS NULL) AND COALESCE(userId, user_id) = ?',
        whereArgs: [userId],
      );
      final List<SavingGoal> savingList = [];
      for (final row in savingRows) {
        try {
          savingList.add(_savingFromRow(row));
        } catch (e) {
          print('Lỗi map saving goal: $e');
          failCount++;
        }
      }

      // 4. Debts
      final debtRows = await db.query(
        'debts',
        where:
            '(isSynced = 0 OR isSynced IS NULL) AND COALESCE(userId, user_id) = ?',
        whereArgs: [userId],
      );
      final List<DebtRecord> debtList = [];
      for (final row in debtRows) {
        try {
          debtList.add(_debtFromRow(row));
        } catch (e) {
          print('Lỗi map debt: $e');
          failCount++;
        }
      }

      // 5. Installments
      final installmentRows = await db.query(
        'installments',
        where:
            '(isSynced = 0 OR isSynced IS NULL) AND COALESCE(userId, user_id) = ?',
        whereArgs: [userId],
      );
      final List<InstallmentPlan> installmentList = [];
      for (final row in installmentRows) {
        try {
          installmentList.add(_installmentFromRow(row));
        } catch (e) {
          print('Lỗi map installment: $e');
          failCount++;
        }
      }

      final totalUnsynced =
          txList.length +
          budgetList.length +
          savingList.length +
          debtList.length +
          installmentList.length;
      if (totalUnsynced == 0) {
        await _financeRepository
            .syncWithFirebase(userId)
            .timeout(const Duration(seconds: 25));
        await saveLastSyncTime();
        _emitEvent(SyncStatus.success);
        return SyncResult(successCount: 0, failCount: failCount, syncTime: now);
      }

      // Upload to firestore using FirestoreService batchWrite
      await _firestoreService
          .batchWrite(
            transactions: txList.isNotEmpty ? txList : null,
            budgets: budgetList.isNotEmpty ? budgetList : null,
            savings: savingList.isNotEmpty ? savingList : null,
            debts: debtList.isNotEmpty ? debtList : null,
            installments: installmentList.isNotEmpty ? installmentList : null,
          )
          .timeout(const Duration(seconds: 15));

      // If we reach here, batchWrite succeeded! Mark all these as synced in SQLite
      final batch = db.batch();

      for (final tx in txList) {
        batch.update(
          'transactions',
          {'isSynced': 1},
          where: 'id = ?',
          whereArgs: [tx.id],
        );
        successCount++;
      }
      for (final b in budgetList) {
        batch.update(
          'budgets',
          {'isSynced': 1},
          where: 'id = ?',
          whereArgs: [b.id],
        );
        successCount++;
      }
      for (final s in savingList) {
        batch.update(
          'savings',
          {'isSynced': 1},
          where: 'id = ?',
          whereArgs: [s.id],
        );
        successCount++;
      }
      for (final d in debtList) {
        batch.update(
          'debts',
          {'isSynced': 1},
          where: 'id = ?',
          whereArgs: [d.id],
        );
        successCount++;
      }
      for (final i in installmentList) {
        batch.update(
          'installments',
          {'isSynced': 1},
          where: 'id = ?',
          whereArgs: [i.id],
        );
        successCount++;
      }

      await batch.commit(noResult: true);
      await _financeRepository
          .syncWithFirebase(userId)
          .timeout(const Duration(seconds: 25));
      await saveLastSyncTime();

      _emitEvent(SyncStatus.success);
    } catch (e) {
      print('Lỗi syncNow: $e');
      // Làm sạch thông báo lỗi: bỏ "Exception:", "FirestoreException:", v.v.
      String errMsg = e.toString();
      if (errMsg.contains(': ')) {
        errMsg = errMsg.substring(errMsg.indexOf(': ') + 2);
      }

      if (e is TimeoutException) {
        errMsg =
            'Hết thời gian chờ kết nối Firebase. Vui lòng kiểm tra lại mạng.';
      }

      _emitEvent(SyncStatus.error, errMsg);
      throw errMsg;
    }

    return SyncResult(
      successCount: successCount,
      failCount: failCount,
      syncTime: now,
    );
  }

  void startAutoSync(String userId) {
    if (kIsWeb || userId.isEmpty) return;
    _currentUserId = userId;

    stopAutoSync();

    // 1. Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasConnection = _checkHasConnection(results);
      if (hasConnection) {
        if (!_wasOnline) {
          _wasOnline = true;
          triggerImmediateSync();
        }
        _startPeriodicTimer();
      } else {
        _wasOnline = false;
        _periodicTimer?.cancel();
        _periodicTimer = null;
        _emitEvent(SyncStatus.offline);
      }
    });

    // 2. Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // 3. Initial connection check and sync
    _checkConnectivityAndSync();
  }

  void stopAutoSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      triggerImmediateSync();
    });
  }

  void triggerImmediateSync() {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () async {
      final results = await Connectivity().checkConnectivity();
      if (_checkHasConnection(results)) {
        await _runSync();
      }
    });
  }

  Future<void> _runSync() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      await syncNow(_currentUserId!);
    } catch (e) {
      print('Auto sync failed: $e');
    }
  }

  Future<void> _checkConnectivityAndSync() async {
    final results = await Connectivity().checkConnectivity();
    if (_checkHasConnection(results)) {
      _wasOnline = true;
      triggerImmediateSync();
      _startPeriodicTimer();
    } else {
      _wasOnline = false;
      _emitEvent(SyncStatus.offline);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnectivityAndSync();
    }
  }

  void _emitEvent(SyncStatus status, [String? error]) {
    if (!_syncEventController.isClosed) {
      _syncEventController.add(SyncEvent(status, error));
    }
  }

  Future<void> saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
    } catch (e) {
      print('Lỗi saveLastSyncTime: $e');
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString('last_sync_time');
      if (timeStr == null) return null;
      return DateTime.tryParse(timeStr);
    } catch (e) {
      print('Lỗi getLastSyncTime: $e');
      return null;
    }
  }

  bool _checkHasConnection(dynamic results) {
    if (results is List) {
      return results.any((result) => result != ConnectivityResult.none);
    } else {
      return results != ConnectivityResult.none;
    }
  }

  // --- PRIVATE MODEL CONVERTERS ---

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
          '',
      type: row['type']?.toString() ?? 'expense',
      amount: _asDouble(row['amount']),
      note: row['note']?.toString() ?? '',
      transactionDate: _parseDate(
        row['transactionDate'] ?? row['transaction_date'] ?? row['date'],
      ),
      createdAt: _parseDate(
        row['createdAt'] ?? row['created_at'] ?? row['transactionDate'],
      ),
      updatedAt: _parseDate(
        row['updatedAt'] ?? row['updated_at'] ?? row['transactionDate'],
      ),
      isDeleted: _asInt(row['isDeleted']) == 1,
      receiptImageUrl: row['receiptImageUrl']?.toString(),
      tags: parsedTags,
      recurringId: row['recurringId']?.toString(),
    );
  }

  SavingGoal _savingFromRow(Map<String, dynamic> row) {
    return SavingGoal(
      id: row['id']?.toString() ?? '',
      userId: row['userId']?.toString() ?? row['user_id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      icon: row['icon']?.toString() ?? '🎯',
      currentAmount: _asInt(row['currentAmount'] ?? row['current_amount']) ?? 0,
      targetAmount: _asInt(row['targetAmount'] ?? row['target_amount']) ?? 0,
      targetDate: _asInt(row['targetDate'] ?? row['target_date']) ?? 0,
      createdAt: _asInt(row['createdAt'] ?? row['created_at']) ?? 0,
      updatedAt: _asInt(row['updatedAt'] ?? row['updated_at']) ?? 0,
      status: row['status']?.toString() ?? 'active',
      colorValue: _asInt(row['colorValue'] ?? row['color_value']),
    );
  }

  DebtRecord _debtFromRow(Map<String, dynamic> row) {
    return DebtRecord(
      id: row['id']?.toString() ?? '',
      userId: row['userId']?.toString() ?? row['user_id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      lenderName:
          row['lenderName']?.toString() ??
          row['lender_name']?.toString() ??
          row['lender']?.toString() ??
          'Không rõ',
      totalAmount: _asInt(row['totalAmount'] ?? row['total_amount']) ?? 0,
      paidAmount: _asInt(row['paidAmount'] ?? row['paid_amount']) ?? 0,
      monthlyPayment:
          _asInt(row['monthlyPayment'] ?? row['monthly_payment']) ?? 0,
      interestRate:
          ((row['interestRate'] ?? row['interest_rate'] ?? 0.0) as num)
              .toDouble(),
      nextDueDate: _asInt(row['nextDueDate'] ?? row['next_due_date']) ?? 0,
      createdAt: _asInt(row['createdAt'] ?? row['created_at']) ?? 0,
      updatedAt: _asInt(row['updatedAt'] ?? row['updated_at']) ?? 0,
      status: row['status']?.toString() ?? 'active',
    );
  }

  InstallmentPlan _installmentFromRow(Map<String, dynamic> row) {
    return InstallmentPlan(
      id: row['id']?.toString() ?? '',
      userId: row['userId']?.toString() ?? row['user_id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      icon: row['icon']?.toString() ?? '💰',
      totalAmount: _asInt(row['totalAmount'] ?? row['total_amount']) ?? 0,
      paidAmount: _asInt(row['paidAmount'] ?? row['paid_amount']) ?? 0,
      monthlyPayment:
          _asInt(row['monthlyPayment'] ?? row['monthly_payment']) ?? 0,
      paidPeriods:
          _asInt(
            row['paidPeriods'] ??
                row['paid_periods'] ??
                row['currentPeriod'] ??
                row['current_period'],
          ) ??
          0,
      totalPeriods: _asInt(row['totalPeriods'] ?? row['total_periods']) ?? 0,
      nextDueDate:
          _asInt(
            row['nextDueDate'] ??
                row['next_due_date'] ??
                row['nextDueDateEpoch'] ??
                row['next_due_date_epoch'],
          ) ??
          0,
      createdAt: _asInt(row['createdAt'] ?? row['created_at']) ?? 0,
      updatedAt: _asInt(row['updatedAt'] ?? row['updated_at']) ?? 0,
      status: row['status']?.toString() ?? 'active',
    );
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
}
