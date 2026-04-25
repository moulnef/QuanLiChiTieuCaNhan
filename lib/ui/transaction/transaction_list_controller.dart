import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../domain/model/transaction_model.dart';
import '../../data/local/category_data.dart';
import '../../data/repository/transaction_repository.dart';

class TransactionListState {
  final AsyncValue<List<TransactionModel>> transactions;
  final List<TransactionModel> filteredList;
  final double totalIncome;
  final double totalExpense;
  final String currentTab;
  final String searchQuery;
  final DateTimeRange? filterDateRange;

  // 2 Biến mới cho bộ lọc
  final String? selectedCategoryGroup;
  final String sortType; // 'date_desc', 'amount_desc', 'amount_asc'

  TransactionListState({
    required this.transactions,
    required this.filteredList,
    required this.totalIncome,
    required this.totalExpense,
    this.currentTab = 'Tất cả',
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
      // Dùng logic gán null đặc biệt nếu muốn xóa filter
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

  String _resolveUserId() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null && currentUid.isNotEmpty) {
      return currentUid;
    }
    return _demoUserId;
  }

  @override
  TransactionListState build() {
    // Gọi lắng nghe ngay khi Provider được khởi tạo
    _listenToTransactions();
    return TransactionListState(
      transactions: const AsyncValue.loading(),
      filteredList: [],
      totalIncome: 0,
      totalExpense: 0,
    );
  }

  void _listenToTransactions() {
    final userId = _resolveUserId();

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
    final StreamSubscription<void> sub = _repository
        .watchTransactions(userId)
        .listen((_) => loadCurrentList());

    ref.onDispose(sub.cancel);
  }

  // Tách hàm xử lý Filter ra để dùng chung
  void _runFilter() {
    state.transactions.whenData((rawList) {
      _applyFiltersAndSort(rawList);
    });
  }

  // Hàm "Trái tim" của Controller: Xử lý logic lọc và tính toán
  void _applyFiltersAndSort(List<TransactionModel> rawList) {
    List<TransactionModel> result = List.from(
      rawList,
    ); // Tạo bản sao để tránh lỗi tham chiếu

    // 1. Lọc Thời gian
    if (state.filterDateRange != null) {
      result = result.where((tx) {
        return tx.date.isAfter(
              state.filterDateRange!.start.subtract(const Duration(seconds: 1)),
            ) &&
            tx.date.isBefore(
              state.filterDateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    // 2. Lọc Tab (Tất cả / Thu nhập / Chi tiêu)
    if (state.currentTab == 'Thu nhập') {
      result = result.where((tx) => tx.type == 'income').toList();
    } else if (state.currentTab == 'Chi tiêu') {
      result = result.where((tx) => tx.type == 'expense').toList();
    }

    // 3. Lọc theo Nhóm Danh Mục Cha
    if (state.selectedCategoryGroup != null) {
      final catsInGroup = CategoryData.getAllCategories()
          .where((c) => c.group == state.selectedCategoryGroup)
          .map((c) => c.name.toLowerCase())
          .toList();

      result = result.where((tx) {
        // Kiểm tra cả ID và Tên vì Chatbot có thể lưu lệch ô
        return catsInGroup.contains(tx.categoryId.toLowerCase()) ||
            catsInGroup.contains(tx.categoryName.toLowerCase());
      }).toList();
    }

    // 4. Lọc Tìm kiếm (Note hoặc Category)
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      result = result
          .where(
            (tx) =>
                tx.note.toLowerCase().contains(query) ||
                tx.categoryName.toLowerCase().contains(query),
          )
          .toList();
    }

    // 5. Sắp xếp (Sort)
    if (state.sortType == 'date_desc') {
      result.sort((a, b) => b.date.compareTo(a.date));
    } else if (state.sortType == 'amount_desc') {
      result.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (state.sortType == 'amount_asc') {
      result.sort((a, b) => a.amount.compareTo(b.amount));
    }

    // 6. Tính tổng Thu/Chi dựa trên kết quả ĐÃ LỌC
    double income = 0;
    double expense = 0;
    for (var tx in result) {
      if (tx.type == 'income')
        income += tx.amount;
      else
        expense += tx.amount;
    }

    // Cập nhật lại state cuối cùng để UI render
    state = state.copyWith(
      filteredList: result,
      totalIncome: income,
      totalExpense: expense,
    );
  }

  // --- Các hàm UI gọi ---
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
    // Sửa logic Clear để an toàn hơn
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
