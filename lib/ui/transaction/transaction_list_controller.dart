import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../../domain/model/transaction_model.dart';
import '../../data/repository/transaction_repository.dart';
import 'transaction_filtering.dart';

class TransactionListState {
  final AsyncValue<List<TransactionModel>> transactions;
  final List<TransactionModel> filteredList;
  final double totalIncome;
  final double totalExpense;
  final String currentTab;
  final String searchQuery;
  final DateTimeRange? filterDateRange;
  final String? selectedCategoryGroup;
  final String sortType;

  TransactionListState({
    required this.transactions,
    required this.filteredList,
    required this.totalIncome,
    required this.totalExpense,
    this.currentTab = 'Táº¥t cáº£',
    this.searchQuery = '',
    this.filterDateRange,
    this.selectedCategoryGroup,
    this.sortType = 'date_desc',
  });

  TransactionListState copyWith({
    AsyncValue<List<TransactionModel>>? transactions,
    List<TransactionModel>? filteredList,
    double? totalIncome,
    double? totalExpense,
    String? currentTab,
    String? searchQuery,
    DateTimeRange? filterDateRange,
    String? selectedCategoryGroup,
    String? sortType,
  }) {
    return TransactionListState(
      transactions: transactions ?? this.transactions,
      filteredList: filteredList ?? this.filteredList,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      currentTab: currentTab ?? this.currentTab,
      searchQuery: searchQuery ?? this.searchQuery,
      filterDateRange: filterDateRange ?? this.filterDateRange,
      selectedCategoryGroup: selectedCategoryGroup == 'CLEAR'
          ? null
          : (selectedCategoryGroup ?? this.selectedCategoryGroup),
      sortType: sortType ?? this.sortType,
    );
  }
}

class TransactionListController extends Notifier<TransactionListState> {
  static const String _demoUserId = 'user_001';

  final TransactionRepository _repository = TransactionRepository();
  StreamSubscription? _authSubscription;
  StreamSubscription? _transactionSubscription;



  @override
  TransactionListState build() {
    _listenToTransactions();
    return TransactionListState(
      transactions: const AsyncValue.loading(),
      filteredList: [],
      totalIncome: 0,
      totalExpense: 0,
    );
  }

  void _listenToTransactions() {
    ref.onDispose(() {
      _authSubscription?.cancel();
      _transactionSubscription?.cancel();
    });

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final targetUserId = user?.uid ?? _demoUserId;
      _loadTransactionsForUser(targetUserId);
    });
  }

  void _loadTransactionsForUser(String userId) {
    _transactionSubscription?.cancel();

    Future<void> loadCurrentList() async {
      try {
        final list = await _repository.getTransactions(userId);
        state = state.copyWith(transactions: AsyncValue.data(list));
        _applyFiltersAndSort(list);
      } catch (e, st) {
        state = state.copyWith(transactions: AsyncValue.error(e, st));
      }
    }

    loadCurrentList();
    _transactionSubscription = _repository
        .watchTransactions(userId)
        .listen((_) => loadCurrentList());
  }

  void _runFilter() {
    state.transactions.whenData((rawList) {
      _applyFiltersAndSort(rawList);
    });
  }

  void _applyFiltersAndSort(List<TransactionModel> rawList) {
    final filtered = filterAndSortTransactions(
      transactions: rawList,
      filterDateRange: state.filterDateRange,
      currentTab: state.currentTab,
      selectedCategoryGroup: state.selectedCategoryGroup,
      searchQuery: state.searchQuery,
      sortType: state.sortType,
    );

    state = state.copyWith(
      filteredList: filtered.filteredList,
      totalIncome: filtered.totalIncome,
      totalExpense: filtered.totalExpense,
    );
  }

  void changeTab(String tab) {
    state = state.copyWith(currentTab: tab);
    _runFilter();
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _runFilter();
  }

  void updateDateRange(DateTimeRange? range) {
    state = state.copyWith(filterDateRange: range);
    _runFilter();
  }

  void updateCategoryGroup(String? group) {
    state = state.copyWith(selectedCategoryGroup: group ?? 'CLEAR');
    _runFilter();
  }

  void updateSortType(String type) {
    state = state.copyWith(sortType: type);
    _runFilter();
  }
}

final transactionListControllerProvider =
    NotifierProvider<TransactionListController, TransactionListState>(() {
      return TransactionListController();
    });
