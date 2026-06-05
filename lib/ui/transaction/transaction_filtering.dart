import 'package:flutter/material.dart';

import '../../data/local/category_data.dart';
import '../../domain/model/transaction_model.dart';

class TransactionFilterResult {
  final List<TransactionModel> filteredList;
  final double totalIncome;
  final double totalExpense;

  const TransactionFilterResult({
    required this.filteredList,
    required this.totalIncome,
    required this.totalExpense,
  });
}

TransactionFilterResult filterAndSortTransactions({
  required List<TransactionModel> transactions,
  DateTimeRange? filterDateRange,
  String currentTab = 'Tất cả',
  String? selectedCategoryGroup,
  String searchQuery = '',
  String sortType = 'date_desc',
}) {
  var result = List<TransactionModel>.from(transactions);

  if (filterDateRange != null) {
    result = result.where((tx) {
      return tx.date.isAfter(
            filterDateRange.start.subtract(const Duration(seconds: 1)),
          ) &&
          tx.date.isBefore(filterDateRange.end.add(const Duration(days: 1)));
    }).toList();
  }

  if (currentTab == 'Thu nhập') {
    result = result.where((tx) => tx.type == 'income').toList();
  } else if (currentTab == 'Chi tiêu') {
    result = result.where((tx) => tx.type == 'expense').toList();
  }

  if (selectedCategoryGroup != null) {
    final selected = CategoryData.normalizeLabel(
      selectedCategoryGroup,
    ).toLowerCase();

    result = result.where((tx) {
      final category =
          CategoryData.findByIdOrName(tx.categoryId) ??
          CategoryData.findByIdOrName(tx.categoryName);
      final candidates = <String>{
        CategoryData.normalizeLabel(tx.categoryId).toLowerCase(),
        CategoryData.normalizeLabel(tx.categoryName).toLowerCase(),
      };
      if (category != null) {
        candidates.add(category.id.toLowerCase());
        candidates.add(category.name.toLowerCase());
        if (category.group != null && category.group!.trim().isNotEmpty) {
          candidates.add(
            CategoryData.normalizeLabel(category.group!).toLowerCase(),
          );
        }
      }
      return candidates.contains(selected);
    }).toList();
  }

  if (searchQuery.isNotEmpty) {
    final query = searchQuery.toLowerCase();
    result = result.where((tx) {
      final resolvedName = CategoryData.resolveDisplayName(
        tx.categoryId,
        tx.categoryName,
      ).toLowerCase();
      return tx.note.toLowerCase().contains(query) ||
          tx.categoryName.toLowerCase().contains(query) ||
          resolvedName.contains(query);
    }).toList();
  }

  if (sortType == 'date_desc') {
    result.sort((a, b) => b.date.compareTo(a.date));
  } else if (sortType == 'amount_desc') {
    result.sort((a, b) => b.amount.compareTo(a.amount));
  } else if (sortType == 'amount_asc') {
    result.sort((a, b) => a.amount.compareTo(b.amount));
  }

  var income = 0.0;
  var expense = 0.0;
  for (final tx in result) {
    if (tx.type == 'income') {
      income += tx.amount;
    } else {
      expense += tx.amount;
    }
  }

  return TransactionFilterResult(
    filteredList: result,
    totalIncome: income,
    totalExpense: expense,
  );
}
