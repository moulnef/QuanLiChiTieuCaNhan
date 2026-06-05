import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/category_data.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/transaction/transaction_filtering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TransactionModel tx({
    required String id,
    required String categoryId,
    String categoryName = '',
    required String type,
    required double amount,
    required DateTime date,
    String note = '',
  }) {
    return TransactionModel(
      id: id,
      categoryId: categoryId,
      categoryName: categoryName,
      type: type,
      amount: amount,
      transactionDate: date,
      note: note,
    );
  }

  group('CategoryData helpers', () {
    test('findByIdOrName resolves both stored id and legacy stored name', () {
      final byId = CategoryData.findByIdOrName('e1');
      final byName = CategoryData.findByIdOrName('Cafe');

      expect(byId, isNotNull);
      expect(byName, isNotNull);
      expect(byId!.id, 'e1');
      expect(byName!.id, 'e1');
    });

    test('resolveDisplayName prefers catalog name for id or fallback name', () {
      expect(CategoryData.resolveDisplayName('e1'), 'Cafe');
      expect(CategoryData.resolveDisplayName('Cafe'), 'Cafe');
      expect(CategoryData.resolveDisplayName('', 'Cafe'), 'Cafe');
    });
  });

  group('filterAndSortTransactions', () {
    final transactions = <TransactionModel>[
      tx(
        id: '1',
        categoryId: 'e1',
        type: 'expense',
        amount: 40000,
        date: DateTime(2026, 6, 3, 8),
        note: 'Morning coffee',
      ),
      tx(
        id: '2',
        categoryId: 'Cafe',
        categoryName: 'Cafe',
        type: 'expense',
        amount: 55000,
        date: DateTime(2026, 6, 4, 9),
        note: 'Legacy category name',
      ),
      tx(
        id: '3',
        categoryId: 'i1',
        categoryName: 'Luong',
        type: 'income',
        amount: 12000000,
        date: DateTime(2026, 6, 5, 10),
        note: 'Salary',
      ),
      tx(
        id: '4',
        categoryId: 'e14',
        categoryName: 'Xang xe',
        type: 'expense',
        amount: 100000,
        date: DateTime(2026, 6, 2, 7),
        note: 'Fuel',
      ),
    ];

    test('filters by category id and legacy stored name consistently', () {
      final byId = filterAndSortTransactions(
        transactions: transactions,
        selectedCategoryGroup: 'e1',
      );
      final byName = filterAndSortTransactions(
        transactions: transactions,
        selectedCategoryGroup: 'Cafe',
      );

      expect(byId.filteredList.map((e) => e.id), ['2', '1']);
      expect(byName.filteredList.map((e) => e.id), ['2', '1']);
      expect(byId.totalExpense, 95000);
    });

    test('filters by parent category group from resolved category', () {
      final result = filterAndSortTransactions(
        transactions: transactions,
        selectedCategoryGroup: 'An u?ng',
      );

      expect(result.filteredList.map((e) => e.id), ['2', '1']);
    });

    test(
      'search matches resolved display name even when categoryName is empty',
      () {
        final result = filterAndSortTransactions(
          transactions: transactions,
          searchQuery: 'cafe',
        );

        expect(result.filteredList.map((e) => e.id), ['2', '1']);
      },
    );

    test('date range includes same-day transactions across full day', () {
      final result = filterAndSortTransactions(
        transactions: transactions,
        filterDateRange: DateTimeRange(
          start: DateTime(2026, 6, 4),
          end: DateTime(2026, 6, 4),
        ),
      );

      expect(result.filteredList.map((e) => e.id), ['2']);
    });

    test(
      'tab and sort calculations keep totals aligned with filtered list',
      () {
        final result = filterAndSortTransactions(
          transactions: transactions,
          currentTab: 'Chi tiêu',
          sortType: 'amount_asc',
        );

        expect(result.filteredList.map((e) => e.id), ['1', '2', '4']);
        expect(result.totalIncome, 0);
        expect(result.totalExpense, 195000);
      },
    );
  });
}
