import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/budget_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/database/mock/mock_budgets.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';

class BudgetProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<Budget> _allBudgets = [];
  List<TransactionModel> _transactions = [];
  StreamSubscription? _transactionSubscription;

  List<Budget> get budgets => _allBudgets;
  
  BudgetProvider() {
    // Khởi tạo ngân sách từ mock data nhưng cập nhật lại tháng/năm hiện tại để khớp với giao dịch mới
    final now = DateTime.now();
    _allBudgets = MockBudgets.items.map((b) => b.copyWith(
      month: now.month,
      year: now.year,
      spentAmount: 0, // Reset chi tiêu về 0 để tính toán từ đầu từ Firestore
    )).toList();
    
    _listenToTransactions();
  }

  void _listenToTransactions() {
    _transactionSubscription?.cancel();
    _transactionSubscription = _firestoreService.getTransactions().listen((snapshot) {
      _transactions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return TransactionModel(
          id: doc.id,
          userId: _firestoreService.userId ?? '',
          categoryId: data['categoryId'] ?? 'cat_other',
          categoryName: data['category'] ?? 'Khác',
          type: 'expense',
          amount: (data['amount'] as num).toDouble(),
          note: data['note'] ?? '',
          transactionDate: (data['date'] as Timestamp).toDate(),
        );
      }).toList();
      
      _updateBudgetStatus();
    });
  }

  void _updateBudgetStatus() {
    // Lấy theo thời gian thực tế để khớp với các giao dịch mới thêm
    final now = DateTime.now();

    _allBudgets = BudgetService.getMonthlyBudgetStatus(
      transactions: _transactions,
      budgets: _allBudgets,
      month: now.month,
      year: now.year,
    );
    
    notifyListeners();
  }

  void addBudget(Budget budget) {
    _allBudgets = [..._allBudgets, budget];
    _updateBudgetStatus();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }
}
