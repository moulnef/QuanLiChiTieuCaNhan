import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/model/transaction_model.dart';
import '../../data/remote/firestore_service.dart';
import '../../data/local/category_data.dart'; // Thêm dòng này để lấy nhóm danh mục

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

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
      selectedCategoryGroup: selectedCategoryGroup == 'CLEAR' ? null : (selectedCategoryGroup ?? this.selectedCategoryGroup),
      sortType: sortType ?? this.sortType,
    );
  }
}

class TransactionListController extends Notifier<TransactionListState> {
  @override
  TransactionListState build() {
    _listenToFirebase();
    return TransactionListState(
      transactions: const AsyncValue.loading(),
      filteredList: [],
      totalIncome: 0,
      totalExpense: 0,
    );
  }

  void _listenToFirebase() {
    final service = ref.read(firestoreServiceProvider);
    final sub = service.getTransactionsStream().listen((snapshot) {
      final list = snapshot.docs.map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      state = state.copyWith(transactions: AsyncValue.data(list));
      _runFilter();
    });
    ref.onDispose(() => sub.cancel());
  }

  void _runFilter() {
    state.transactions.whenData((rawList) {
      List<TransactionModel> result = rawList;

      // 1. Lọc Thời gian
      if (state.filterDateRange != null) {
        result = result.where((tx) =>
        tx.date.isAfter(state.filterDateRange!.start.subtract(const Duration(seconds: 1))) &&
            tx.date.isBefore(state.filterDateRange!.end.add(const Duration(days: 1)))
        ).toList();
      }

      // 2. Lọc Tab
      if (state.currentTab == 'Thu nhập') {
        result = result.where((tx) => tx.type == 'income').toList();
      } else if (state.currentTab == 'Chi tiêu') {
        result = result.where((tx) => tx.type == 'expense').toList();
      }

      // 3. Lọc Nhóm Danh Mục Cha (Vd: Ăn uống, Con cái)
      if (state.selectedCategoryGroup != null) {
        // Lấy tất cả tên danh mục con thuộc nhóm cha này
        final catsInGroup = CategoryData.getAllCategories()
            .where((c) => c.group == state.selectedCategoryGroup)
            .map((c) => c.name)
            .toList();

        result = result.where((tx) => catsInGroup.contains(tx.categoryId)).toList();
      }

      // 4. Lọc Tìm kiếm
      if (state.searchQuery.isNotEmpty) {
        result = result.where((tx) => tx.note.toLowerCase().contains(state.searchQuery.toLowerCase()) || tx.categoryId.toLowerCase().contains(state.searchQuery.toLowerCase())).toList();
      }

      // 5. Sắp xếp
      if (state.sortType == 'date_desc') {
        result.sort((a, b) => b.date.compareTo(a.date)); // Ngày gần nhất
      } else if (state.sortType == 'amount_desc') {
        result.sort((a, b) => b.amount.compareTo(a.amount)); // Tiền cao nhất
      } else if (state.sortType == 'amount_asc') {
        result.sort((a, b) => a.amount.compareTo(b.amount)); // Tiền thấp nhất
      }

      // 6. Tính tổng
      double income = 0; double expense = 0;
      for (var tx in result) {
        if (tx.type == 'income') income += tx.amount; else expense += tx.amount;
      }

      state = state.copyWith(filteredList: result, totalIncome: income, totalExpense: expense);
    });
  }

  // CÁC HÀM CẬP NHẬT TỪ UI
  void changeTab(String tab) { state = state.copyWith(currentTab: tab); _runFilter(); }
  void updateSearch(String query) { state = state.copyWith(searchQuery: query); _runFilter(); }
  void updateDateRange(DateTimeRange? range) { state = state.copyWith(filterDateRange: range); _runFilter(); }
  void updateCategoryGroup(String? group) { state = state.copyWith(selectedCategoryGroup: group ?? 'CLEAR'); _runFilter(); }
  void updateSortType(String type) { state = state.copyWith(sortType: type); _runFilter(); }
}

final transactionListControllerProvider = NotifierProvider<TransactionListController, TransactionListState>(() {
  return TransactionListController();
});