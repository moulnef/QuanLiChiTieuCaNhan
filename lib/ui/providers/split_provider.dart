import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/database_helper.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/wallet_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_group.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_member.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_expense.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_debt.dart';
import 'auth_provider.dart';

class SplitProvider extends ChangeNotifier {
  final FinanceRepository _financeRepository;
  final AuthProvider _authProvider;
  final _uuid = const Uuid();

  List<SplitGroup> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  SplitProvider(this._financeRepository, this._authProvider) {
    if (_authProvider.isAuthenticated) {
      fetchGroups();
    }
  }

  List<SplitGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get _currentUserId => _authProvider.currentUser?.uid ?? 'user_001';

  Future<bool> _isOnline() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchGroups() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Load from SQLite local cache
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('split_groups', orderBy: 'createdAt DESC');
      
      _groups = rows.map((row) {
        final membersList = jsonDecode(row['members'] as String) as List;
        final expensesList = jsonDecode(row['expenses'] as String) as List;
        
        return SplitGroup.fromMap({
          'id': row['id'],
          'name': row['name'],
          'createdAt': row['createdAt'],
          'status': row['status'],
          'ownerId': row['ownerId'],
          'members': membersList,
          'expenses': expensesList,
          'memberUids': membersList
              .map((m) => m['userId'])
              .where((uid) => uid != null && uid.toString().isNotEmpty)
              .toList(),
        });
      }).toList();
      notifyListeners();

      // 2. Fetch from Firestore if online and merge
      if (_authProvider.isAuthenticated && await _isOnline()) {
        final snapshot = await FirebaseFirestore.instance
            .collection('split_groups')
            .where('memberUids', arrayContains: _currentUserId)
            .get();

        final firestoreGroups = snapshot.docs
            .map((doc) => SplitGroup.fromMap(doc.data()))
            .toList();

        // Update local cache with Firestore documents
        for (final group in firestoreGroups) {
          await db.insert(
            'split_groups',
            {
              'id': group.id,
              'name': group.name,
              'createdAt': group.createdAt.millisecondsSinceEpoch,
              'status': group.status.name,
              'ownerId': group.ownerId,
              'members': jsonEncode(group.members.map((m) => m.toMap()).toList()),
              'expenses': jsonEncode(group.expenses.map((e) => e.toMap()).toList()),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Reload from SQLite to keep source of truth local
        final updatedRows = await db.query('split_groups', orderBy: 'createdAt DESC');
        _groups = updatedRows.map((row) {
          final membersList = jsonDecode(row['members'] as String) as List;
          final expensesList = jsonDecode(row['expenses'] as String) as List;
          
          return SplitGroup.fromMap({
            'id': row['id'],
            'name': row['name'],
            'createdAt': row['createdAt'],
            'status': row['status'],
            'ownerId': row['ownerId'],
            'members': membersList,
            'expenses': expensesList,
            'memberUids': membersList
                .map((m) => m['userId'])
                .where((uid) => uid != null && uid.toString().isNotEmpty)
                .toList(),
          });
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Không thể đồng bộ dữ liệu nhóm: $e';
      debugPrint('Lỗi SplitProvider.fetchGroups: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addGroup(String name, List<String> memberNames) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final groupId = _uuid.v4();
      
      // Auto-add current user as member
      final currentUserName = _authProvider.currentUser?.displayName ?? 'Tôi';
      final currentUserMember = SplitMember(
        id: _uuid.v4(),
        name: '$currentUserName (Trưởng nhóm)',
        userId: _currentUserId,
      );

      final membersList = [currentUserMember];
      for (final name in memberNames) {
        if (name.trim().isNotEmpty) {
          membersList.add(SplitMember(
            id: _uuid.v4(),
            name: name.trim(),
          ));
        }
      }

      final memberUids = membersList
          .map((m) => m.userId)
          .where((uid) => uid != null)
          .cast<String>()
          .toList();

      final newGroup = SplitGroup(
        id: groupId,
        name: name,
        createdAt: now,
        status: SplitGroupStatus.active,
        ownerId: _currentUserId,
        memberUids: memberUids,
        members: membersList,
        expenses: [],
      );

      // Save to local cache
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'split_groups',
        {
          'id': newGroup.id,
          'name': newGroup.name,
          'createdAt': newGroup.createdAt.millisecondsSinceEpoch,
          'status': newGroup.status.name,
          'ownerId': newGroup.ownerId,
          'members': jsonEncode(newGroup.members.map((m) => m.toMap()).toList()),
          'expenses': jsonEncode([]),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Push to Firestore (handles offline syncing automatically)
      if (_authProvider.isAuthenticated) {
        await FirebaseFirestore.instance
            .collection('split_groups')
            .doc(newGroup.id)
            .set(newGroup.toMap());
      }

      _groups.insert(0, newGroup);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tạo nhóm: $e';
      debugPrint('Lỗi SplitProvider.addGroup: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(String groupId, SplitExpense expense) async {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index == -1) return;

    final group = _groups[index];
    if (group.status == SplitGroupStatus.settled) {
      throw StateError('Không thể thêm chi tiêu vào nhóm đã quyết toán.');
    }

    final updatedExpenses = List<SplitExpense>.from(group.expenses)..add(expense);
    final updatedGroup = group.copyWith(expenses: updatedExpenses);

    try {
      // Save locally
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'split_groups',
        {
          'expenses': jsonEncode(updatedGroup.expenses.map((e) => e.toMap()).toList()),
        },
        where: 'id = ?',
        whereArgs: [groupId],
      );

      // Sync with Firestore
      if (_authProvider.isAuthenticated) {
        await FirebaseFirestore.instance
            .collection('split_groups')
            .doc(groupId)
            .update({
              'expenses': updatedGroup.expenses.map((e) => e.toMap()).toList(),
            });
      }

      _groups[index] = updatedGroup;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi thêm khoản chi: $e';
      debugPrint('Lỗi SplitProvider.addExpense: $e');
    }
  }

  Future<void> updateGroupStatus(String groupId, SplitGroupStatus status) async {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index == -1) return;

    final group = _groups[index];
    final updatedGroup = group.copyWith(status: status);

    try {
      // Save locally
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'split_groups',
        {
          'status': status.name,
        },
        where: 'id = ?',
        whereArgs: [groupId],
      );

      // Sync with Firestore
      if (_authProvider.isAuthenticated) {
        await FirebaseFirestore.instance
            .collection('split_groups')
            .doc(groupId)
            .update({
              'status': status.name,
            });
      }

      _groups[index] = updatedGroup;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật trạng thái nhóm: $e';
      debugPrint('Lỗi SplitProvider.updateGroupStatus: $e');
    }
  }

  Future<void> settleDebt(
    SplitGroup group,
    SplitDebt debt,
    SplitMember fromMember,
    SplitMember toMember,
  ) async {
    // 1. Create a dummy expense representing the repayment in the group
    final settlementExpense = SplitExpense(
      id: _uuid.v4(),
      description: 'Quyết toán: ${fromMember.name} trả ${toMember.name}',
      amount: debt.amount,
      paidBy: fromMember.id,
      splitType: SplitType.custom,
      shares: {toMember.id: debt.amount},
      createdAt: DateTime.now(),
    );

    // Save to the split group
    await addExpense(group.id, settlementExpense);

    // 2. If the current user is the payor, log a personal Transaction in finance_provider
    if (fromMember.userId == _currentUserId) {
      try {
        final walletsRaw = await _financeRepository.getWalletsByUserId(_currentUserId);
        final wallets = walletsRaw.map((w) => WalletModel.fromMap(w)).toList();
        
        // Find default wallet or first available, or fallback
        final wallet = wallets.firstWhere(
          (w) => w.isDefault,
          orElse: () => wallets.isNotEmpty
              ? wallets.first
              : WalletModel(
                  id: 'default',
                  userId: _currentUserId,
                  name: 'Ví mặc định',
                  balance: 0.0,
                ),
        );

        final tx = TransactionModel(
          id: '', // Generated by upsertTransaction
          userId: _currentUserId,
          walletId: wallet.id,
          categoryId: 'split_bill',
          categoryName: 'Chia tiền nhóm',
          type: 'expense',
          amount: debt.amount,
          note: 'Quyết toán nhóm: ${fromMember.name} -> ${toMember.name} (Nhóm: ${group.name})',
          transactionDate: DateTime.now(),
        );

        await _financeRepository.upsertTransaction(tx);
      } catch (e) {
        debugPrint('Lỗi tự động tạo giao dịch cá nhân khi quyết toán: $e');
      }
    }
  }

  List<SplitDebt> calculateDebts(SplitGroup group) {
    if (group.members.isEmpty) return [];

    // 1. Sum up all payments and subtractions for each member
    final Map<String, double> balances = {};
    for (final member in group.members) {
      balances[member.id] = 0.0;
    }

    for (final expense in group.expenses) {
      final payerId = expense.paidBy;
      if (!balances.containsKey(payerId)) continue;
      
      // Payer gets credit
      balances[payerId] = (balances[payerId] ?? 0.0) + expense.amount;

      // Deduct shares
      if (expense.splitType == SplitType.equal) {
        final double share = expense.amount / group.members.length;
        for (final member in group.members) {
          balances[member.id] = (balances[member.id] ?? 0.0) - share;
        }
      } else {
        expense.shares.forEach((memberId, shareAmount) {
          if (balances.containsKey(memberId)) {
            balances[memberId] = (balances[memberId] ?? 0.0) - shareAmount;
          }
        });
      }
    }

    // 2. Separate into positive credits and negative debts, rounded to whole VND
    final List<MapEntry<String, double>> creditors = [];
    final List<MapEntry<String, double>> debtors = [];

    balances.forEach((memberId, balanceVal) {
      final double rounded = double.parse(balanceVal.toStringAsFixed(0));
      if (rounded > 1.0) {
        creditors.add(MapEntry(memberId, rounded));
      } else if (rounded < -1.0) {
        debtors.add(MapEntry(memberId, -rounded)); // debtor owes positive amount
      }
    });

    final List<SplitDebt> debts = [];

    // 3. Simplify debts using greedy matching
    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      debtors.sort((a, b) => b.value.compareTo(a.value));
      creditors.sort((a, b) => b.value.compareTo(a.value));

      final debtor = debtors.first;
      final creditor = creditors.first;

      final double amount = debtor.value < creditor.value ? debtor.value : creditor.value;

      if (amount >= 1.0) {
        debts.add(SplitDebt(
          from: debtor.key,
          to: creditor.key,
          amount: amount,
        ));
      }

      final newDebtorVal = debtor.value - amount;
      final newCreditorVal = creditor.value - amount;

      if (newDebtorVal < 1.0) {
        debtors.removeAt(0);
      } else {
        debtors[0] = MapEntry(debtor.key, newDebtorVal);
      }

      if (newCreditorVal < 1.0) {
        creditors.removeAt(0);
      } else {
        creditors[0] = MapEntry(creditor.key, newCreditorVal);
      }
    }

    return debts;
  }
}
