import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'transaction_list_controller.dart';
import '../transaction/create_transaction_page.dart';
import '../../data/local/category_data.dart';
import '../../domain/model/transaction_model.dart';
import '../../domain/model/category_model.dart';
import '../../services/translation_service.dart';
import '../../utils/app_localizer.dart';

class TransactionListPage extends ConsumerStatefulWidget {
  final bool forceShowBackButton;

  const TransactionListPage({super.key, this.forceShowBackButton = false});

  @override
  ConsumerState<TransactionListPage> createState() =>
      _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  bool _isSearchMode = false;
  final Map<String, String> _dynamicCategoryTranslations = {};
  final Set<String> _pendingCategoryTranslations = {};

  String _displayCategory(String raw) {
    final mapped = raw.xtrCategory(context);
    if (mapped != raw) {
      return mapped;
    }
    return _dynamicCategoryTranslations[raw] ?? raw;
  }

  CategoryModel? _resolveCategoryModel(TransactionModel tx) {
    return CategoryData.findByIdOrName(tx.categoryId) ??
        CategoryData.findByIdOrName(tx.categoryName);
  }

  String _displayTransactionCategory(TransactionModel tx) {
    final category = _resolveCategoryModel(tx);
    final rawName = category?.name ?? tx.categoryName.trim();
    if (rawName.isNotEmpty) {
      return _displayCategory(rawName);
    }
    if (tx.categoryId.trim().isNotEmpty) {
      return _displayCategory(CategoryData.resolveDisplayName(tx.categoryId));
    }
    return _displayCategory('Khác');
  }

  void _queueCategoryTranslations(TransactionListState state) {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    if (lang != 'en') {
      if (_dynamicCategoryTranslations.isNotEmpty ||
          _pendingCategoryTranslations.isNotEmpty) {
        _dynamicCategoryTranslations.clear();
        _pendingCategoryTranslations.clear();
      }
      return;
    }

    final candidates = <String>{};
    for (final tx in state.filteredList) {
      final category = _resolveCategoryModel(tx);
      final categoryName = (category?.name ?? tx.categoryName).trim();
      if (categoryName.isNotEmpty) {
        candidates.add(categoryName);
      }
    }

    final unresolved = candidates
        .where((name) {
          final mapped = name.xtrCategory(context);
          return mapped == name &&
              !_dynamicCategoryTranslations.containsKey(name) &&
              !_pendingCategoryTranslations.contains(name);
        })
        .toList(growable: false);

    if (unresolved.isEmpty) {
      return;
    }

    _pendingCategoryTranslations.addAll(unresolved);

    Future<void>(() async {
      try {
        final translated = await TranslationService.instance.translateMany(
          sourceTexts: unresolved,
          targetLanguageCode: 'en',
        );

        if (!mounted) {
          return;
        }
        if (Localizations.localeOf(context).languageCode.toLowerCase() !=
            'en') {
          _pendingCategoryTranslations.removeAll(unresolved);
          return;
        }

        setState(() {
          for (var i = 0; i < unresolved.length; i++) {
            final source = unresolved[i];
            final target = translated[i].trim();
            if (target.isNotEmpty && target != source) {
              _dynamicCategoryTranslations[source] = target;
            }
          }
          _pendingCategoryTranslations.removeAll(unresolved);
        });
      } catch (_) {
        _pendingCategoryTranslations.removeAll(unresolved);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListControllerProvider);
    _queueCategoryTranslations(state);
    final controller = ref.read(transactionListControllerProvider.notifier);
    double totalBalance = state.totalIncome - state.totalExpense;
    final bool canGoBack =
        widget.forceShowBackButton || Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF), // Nền Galaxy Nhạt
      body: Column(
        children: [
          // --- HEADER GALAXY GRADIENT ---
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: _isSearchMode
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _isSearchMode = false);
                          controller.updateSearch('');
                        },
                      ),
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: TextField(
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            onChanged: (value) =>
                                controller.updateSearch(value),
                            decoration: InputDecoration(
                              hintText: "Tìm kiếm...".xtr(context),
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (canGoBack) ...[
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                splashRadius: 22,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                "Giao dịch".xtr(context),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _ScaleOnTap(
                            onTap: () => setState(() => _isSearchMode = true),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          _ScaleOnTap(
                            onTap: () => _showFilterSortPanel(context, state),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ScaleOnTap(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateTransactionPage(),
                              ),
                            ),
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.22),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Thêm'.xtr(context),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // --- TAB BARS ---
          _buildTabBar(state, controller),

          // --- ACTIVE FILTER CHIP BAR ---
          _buildActiveFilterBar(state),

          // --- SUMMARY BOXES ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    "Thu nhập".xtr(context),
                    "+${_formatMoney(state.totalIncome)} đ",
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatBox(
                    "Chi tiêu".xtr(context),
                    "-${_formatMoney(state.totalExpense)} đ",
                    const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatBox(
                    "Tổng".xtr(context),
                    "${totalBalance < 0 ? '-' : ''}${_formatMoney(totalBalance.abs())} đ",
                    const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),

          // --- DANH SÁCH GIAO DỊCH ---
          Expanded(
            child: state.transactions.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
              ),
              error: (err, stack) =>
                  Center(child: Text('Lỗi: $err'.xtr(context))),
              data: (_) {
                if (state.filteredList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        "Không có giao dịch nào.".xtr(context),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }

                Map<String, List<TransactionModel>> groupedData = {};
                for (var tx in state.filteredList) {
                  String dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
                  if (!groupedData.containsKey(dateKey)) {
                    groupedData[dateKey] = [];
                  }
                  groupedData[dateKey]!.add(tx);
                }

                List<Widget> groupWidgets = [];
                groupedData.forEach((dateKey, txList) {
                  DateTime parsedDate = DateTime.parse(dateKey);
                  double dailyTotal = 0;
                  for (var tx in txList) {
                    if (tx.type == 'income') {
                      dailyTotal += tx.amount;
                    } else {
                      dailyTotal -= tx.amount;
                    }
                  }

                  groupWidgets.add(
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getFormattedDate(parsedDate),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                "${dailyTotal < 0 ? '-' : (dailyTotal > 0 ? '+' : '')}${_formatMoney(dailyTotal.abs())} đ",
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...txList.map((tx) {
                          final isExpense = tx.type == 'expense';
                          final category = _resolveCategoryModel(tx);

                          return _ScaleOnTap(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CreateTransactionPage(editData: tx),
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: (category?.color ?? Colors.grey)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        category?.iconData ??
                                            Icons.receipt_long,
                                        color: category?.color ?? Colors.grey,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.note.isNotEmpty
                                                ? tx.note
                                                : _displayTransactionCategory(
                                                    tx,
                                                  ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Color(0xFF1E293B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _displayTransactionCategory(tx),
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${isExpense ? '-' : '+'}${_formatMoney(tx.amount)} đ",
                                          style: TextStyle(
                                            color: isExpense
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('HH:mm').format(tx.date),
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                });

                groupWidgets.add(const SizedBox(height: 80));
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: groupWidgets,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(TransactionListState state, dynamic controller) {
    const tabs = ['Tất cả', 'Thu nhập', 'Chi tiêu'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = state.currentTab == tab;
          return Expanded(
            child: _ScaleOnTap(
              onTap: () => controller.changeTab(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6D28D9)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  tab.xtr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatBox(String title, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterBar(TransactionListState state) {
    final hasCategory = state.selectedCategoryGroup != null;
    final hasDate = state.filterDateRange != null;
    final hasSort = state.sortType != 'date_desc';
    final hasAnyFilter = hasCategory || hasDate || hasSort;

    if (!hasAnyFilter) {
      return const SizedBox(height: 6);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (hasCategory)
                    _buildActiveChip(
                      label: _displayCategory(state.selectedCategoryGroup!),
                      icon: Icons.category_rounded,
                      onRemove: () {
                        ref
                            .read(transactionListControllerProvider.notifier)
                            .updateCategoryGroup(null);
                      },
                    ),
                  if (hasDate)
                    _buildActiveChip(
                      label: _formatDateRange(state.filterDateRange),
                      icon: Icons.calendar_today_rounded,
                      onRemove: () {
                        ref
                            .read(transactionListControllerProvider.notifier)
                            .updateDateRange(null);
                      },
                    ),
                  if (hasSort)
                    _buildActiveChip(
                      label: _getSortLabel(state.sortType).xtr(context),
                      icon: Icons.sort_rounded,
                      onRemove: () {
                        ref
                            .read(transactionListControllerProvider.notifier)
                            .updateSortType('date_desc');
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              final notifier = ref.read(
                transactionListControllerProvider.notifier,
              );
              notifier.updateCategoryGroup(null);
              notifier.updateDateRange(null);
              notifier.updateSortType('date_desc');
            },
            child: Text('Đặt lại'.xtr(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChip({
    required String label,
    required IconData icon,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6D28D9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5B21B6),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          _ScaleOnTap(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF6D28D9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSortPanel(BuildContext context, TransactionListState state) {
    final notifier = ref.read(transactionListControllerProvider.notifier);
    String? tempCategory = state.selectedCategoryGroup;
    String tempSort = state.sortType;
    DateTimeRange? tempDateRange = state.filterDateRange;

    final groups = _resolveCategoryGroups(state.currentTab);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Lọc & Sắp xếp',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              tempCategory = null;
                              tempDateRange = null;
                              tempSort = 'date_desc';
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text('Đặt lại'.xtr(context)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      children: [
                        _panelCard(
                          title: 'Sắp xếp'.xtr(context),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildChoicePill(
                                label: 'Mới nhất'.xtr(context),
                                selected: tempSort == 'date_desc',
                                onTap: () =>
                                    setSheetState(() => tempSort = 'date_desc'),
                              ),
                              _buildChoicePill(
                                label: 'Số tiền giảm dần'.xtr(context),
                                selected: tempSort == 'amount_desc',
                                onTap: () => setSheetState(
                                  () => tempSort = 'amount_desc',
                                ),
                              ),
                              _buildChoicePill(
                                label: 'Số tiền tăng dần'.xtr(context),
                                selected: tempSort == 'amount_asc',
                                onTap: () => setSheetState(
                                  () => tempSort = 'amount_asc',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _panelCard(
                          title: 'Danh mục'.xtr(context),
                          subtitle: 'Theo nhóm danh mục của tab hiện tại'.xtr(
                            context,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildChoicePill(
                                label: 'Tất cả'.xtr(context),
                                selected: tempCategory == null,
                                onTap: () =>
                                    setSheetState(() => tempCategory = null),
                              ),
                              ...groups.map(
                                (group) => _buildChoicePill(
                                  label: _displayCategory(group),
                                  selected: tempCategory == group,
                                  onTap: () =>
                                      setSheetState(() => tempCategory = group),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _panelCard(
                          title: 'Thời gian'.xtr(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildChoicePill(
                                    label: 'Hôm nay'.xtr(context),
                                    selected: _isSameRange(
                                      tempDateRange,
                                      _todayRange(),
                                    ),
                                    onTap: () => setSheetState(
                                      () => tempDateRange = _todayRange(),
                                    ),
                                  ),
                                  _buildChoicePill(
                                    label: 'Tuần này'.xtr(context),
                                    selected: _isSameRange(
                                      tempDateRange,
                                      _thisWeekRange(),
                                    ),
                                    onTap: () => setSheetState(
                                      () => tempDateRange = _thisWeekRange(),
                                    ),
                                  ),
                                  _buildChoicePill(
                                    label: 'Tháng này'.xtr(context),
                                    selected: _isSameRange(
                                      tempDateRange,
                                      _thisMonthRange(),
                                    ),
                                    onTap: () => setSheetState(
                                      () => tempDateRange = _thisMonthRange(),
                                    ),
                                  ),
                                  _buildChoicePill(
                                    label: 'Năm này'.xtr(context),
                                    selected: _isSameRange(
                                      tempDateRange,
                                      _thisYearRange(),
                                    ),
                                    onTap: () => setSheetState(
                                      () => tempDateRange = _thisYearRange(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                    initialDateRange: tempDateRange,
                                    helpText: 'Chọn khoảng thời gian'.xtr(
                                      context,
                                    ),
                                  );
                                  if (picked == null) return;
                                  setSheetState(() => tempDateRange = picked);
                                },
                                icon: const Icon(Icons.date_range_rounded),
                                label: Text(
                                  tempDateRange == null
                                      ? 'Chọn khoảng tùy chỉnh'.xtr(context)
                                      : _formatDateRange(tempDateRange),
                                ),
                              ),
                              if (tempDateRange != null)
                                TextButton(
                                  onPressed: () =>
                                      setSheetState(() => tempDateRange = null),
                                  child: Text('Xóa lọc thời gian'.xtr(context)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Hủy'.xtr(context)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                notifier.updateSortType(tempSort);
                                notifier.updateCategoryGroup(tempCategory);
                                notifier.updateDateRange(tempDateRange);
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.check_rounded),
                              label: Text('Áp dụng'.xtr(context)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _panelCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            )
          else
            const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildChoicePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _ScaleOnTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6D28D9) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF6D28D9) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF334155),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  List<String> _resolveCategoryGroups(String currentTab) {
    final List<CategoryModel> categories;
    if (currentTab == 'Chi tiêu') {
      categories = CategoryData.getExpenseCategories();
    } else if (currentTab == 'Thu nhập') {
      categories = CategoryData.getIncomeCategories();
    } else {
      categories = CategoryData.getAllCategories();
    }

    final groups = categories.map((e) => e.group ?? 'Khác').toSet().toList()
      ..sort();
    return groups;
  }

  String _formatDateRange(DateTimeRange? range) {
    if (range == null) return 'Tất cả thời gian'.xtr(context);
    return '${DateFormat('dd/MM').format(range.start)} - ${DateFormat('dd/MM').format(range.end)}';
  }

  bool _isSameRange(DateTimeRange? a, DateTimeRange b) {
    if (a == null) return false;
    return a.start.year == b.start.year &&
        a.start.month == b.start.month &&
        a.start.day == b.start.day &&
        a.end.year == b.end.year &&
        a.end.month == b.end.month &&
        a.end.day == b.end.day;
  }

  DateTimeRange _todayRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: start, end: start);
  }

  DateTimeRange _thisWeekRange() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _thisMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _thisYearRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31);
    return DateTimeRange(start: start, end: end);
  }

  Widget _buildRightDrawer(WidgetRef ref, TransactionListState state) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Lọc & Sắp xếp",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category_rounded, color: Colors.blue),
              ),
              title: const Text(
                "Danh mục",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                state.selectedCategoryGroup == null
                    ? "Tất cả".xtr(context)
                    : _displayCategory(state.selectedCategoryGroup!),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                _showCategoryFilter(context, ref, state);
              },
            ),
            const Divider(indent: 60, color: Color(0xFFF1F5F9)),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sort_rounded, color: Colors.orange),
              ),
              title: const Text(
                "Sắp xếp",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(_getSortLabel(state.sortType)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                _showSortFilter(context, ref, state);
              },
            ),
            const Divider(indent: 60, color: Color(0xFFF1F5F9)),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.green,
                ),
              ),
              title: const Text(
                "Thời gian",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                state.filterDateRange != null
                    ? "${DateFormat('dd/MM').format(state.filterDateRange!.start)} - ${DateFormat('dd/MM').format(state.filterDateRange!.end)}"
                    : "Tất cả".xtr(context),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                _showFilterSortPanel(context, state);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    return "${AppLocalizer.weekdayLabel(context, date)}, ${DateFormat('dd/MM/yyyy').format(date)}";
  }

  // --- CẬP NHẬT: Giao diện lọc y chang CategoryListScreen, lấy data theo Tab hiện tại ---
  void _showCategoryFilter(
    BuildContext context,
    WidgetRef ref,
    TransactionListState state,
  ) {
    // Lấy danh mục dựa trên Tab hiện tại
    List<CategoryModel> baseCategories;
    if (state.currentTab == 'Chi tiêu') {
      baseCategories = CategoryData.getExpenseCategories();
    } else if (state.currentTab == 'Thu nhập') {
      baseCategories = CategoryData.getIncomeCategories();
    } else {
      baseCategories = CategoryData.getAllCategories();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF0F5FF),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        String searchQuery = "";

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final filteredList = baseCategories
                .where(
                  (cat) => cat.name.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ),
                )
                .toList();

            Map<String, List<CategoryModel>> groupedCategories = {};
            for (var cat in filteredList) {
              String groupName = cat.group ?? "Khác";
              if (!groupedCategories.containsKey(groupName)) {
                groupedCategories[groupName] = [];
              }
              groupedCategories[groupName]!.add(cat);
            }

            return FractionallySizedBox(
              heightFactor: 0.88, // Chiếm 88% màn hình
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Lọc theo hạng mục".xtr(context),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nút "Tất cả giao dịch" (Bỏ lọc)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      onTap: () {
                        ref
                            .read(transactionListControllerProvider.notifier)
                            .updateCategoryGroup(null);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: state.selectedCategoryGroup == null
                              ? const Color(0xFF6D28D9).withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: state.selectedCategoryGroup == null
                                ? const Color(0xFF6D28D9)
                                : Colors.transparent,
                          ),
                          boxShadow: state.selectedCategoryGroup == null
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.apps_rounded,
                              color: state.selectedCategoryGroup == null
                                  ? const Color(0xFF6D28D9)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Tất cả hạng mục".xtr(context),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: state.selectedCategoryGroup == null
                                    ? const Color(0xFF6D28D9)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            const Spacer(),
                            if (state.selectedCategoryGroup == null)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF6D28D9),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ô Tìm kiếm (Giống CategoryListScreen)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (v) => setSheetState(() => searchQuery = v),
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: "Tìm kiếm theo tên hạng mục...".xtr(
                            context,
                          ),
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF6D28D9),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),

                  // Danh sách các nhóm danh mục
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          ...groupedCategories.keys.map((group) {
                            return _buildFilterGroupSection(
                              group,
                              groupedCategories[group]!,
                              state.selectedCategoryGroup,
                              (catName) {
                                ref
                                    .read(
                                      transactionListControllerProvider
                                          .notifier,
                                    )
                                    .updateCategoryGroup(catName);
                                Navigator.pop(context);
                              },
                            );
                          }),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterGroupSection(
    String name,
    List<CategoryModel> items,
    String? selectedCategory,
    Function(String) onTapCategory,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getGroupIcon(name),
                  color: const Color(0xFF64748B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _displayCategory(name),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 0,
            runSpacing: 16,
            children: items
                .map(
                  (cat) => _buildFilterGridItem(
                    cat,
                    selectedCategory,
                    onTapCategory,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGridItem(
    CategoryModel cat,
    String? selectedCategory,
    Function(String) onTapCategory,
  ) {
    bool isSelected =
        cat.id == selectedCategory || cat.name == selectedCategory;

    return Builder(
      builder: (context) {
        return InkWell(
          onTap: () => onTapCategory(cat.id),
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width:
                (MediaQuery.of(context).size.width - 72) /
                4, // Chia đúng 4 cột giống trang bên kia
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(cat.iconData, color: cat.color, size: 24),
                    ),
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    _displayCategory(cat.name),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF6D28D9)
                          : const Color(0xFF334155),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortFilter(
    BuildContext context,
    WidgetRef ref,
    TransactionListState state,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                width: 40,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
            _buildSheetOption(
              label: "Ngày gần nhất".xtr(context),
              icon: Icons.access_time_filled_rounded,
              isSelected: state.sortType == 'date_desc',
              onTap: () {
                ref
                    .read(transactionListControllerProvider.notifier)
                    .updateSortType('date_desc');
                Navigator.pop(context);
              },
            ),
            _buildSheetOption(
              label: "Tiền nhiều nhất".xtr(context),
              icon: Icons.arrow_upward_rounded,
              isSelected: state.sortType == 'amount_desc',
              onTap: () {
                ref
                    .read(transactionListControllerProvider.notifier)
                    .updateSortType('amount_desc');
                Navigator.pop(context);
              },
            ),
            _buildSheetOption(
              label: "Tiền ít nhất".xtr(context),
              icon: Icons.arrow_downward_rounded,
              isSelected: state.sortType == 'amount_asc',
              onTap: () {
                ref
                    .read(transactionListControllerProvider.notifier)
                    .updateSortType('amount_asc');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: const Color(0xFF6D28D9).withValues(alpha: 0.1),
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF94A3B8),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF1E293B),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6D28D9))
          : null,
      onTap: onTap,
    );
  }

  IconData _getGroupIcon(String groupName) {
    String lowerGroup = groupName.toLowerCase();
    if (lowerGroup.contains('ăn')) return Icons.restaurant_menu_rounded;
    if (lowerGroup.contains('dịch vụ') || lowerGroup.contains('sinh hoạt')) {
      return Icons.electrical_services_rounded;
    }
    if (lowerGroup.contains('di chuyển') || lowerGroup.contains('đi lại')) {
      return Icons.directions_car_rounded;
    }
    if (lowerGroup.contains('trang phục') || lowerGroup.contains('mua sắm')) {
      return Icons.checkroom_rounded;
    }
    if (lowerGroup.contains('hưởng thụ') || lowerGroup.contains('giải trí')) {
      return Icons.celebration_rounded;
    }
    if (lowerGroup.contains('con cái')) return Icons.child_care_rounded;
    if (lowerGroup.contains('hiếu hỉ') || lowerGroup.contains('biếu tặng')) {
      return Icons.card_giftcard_rounded;
    }
    if (lowerGroup.contains('nhà cửa')) return Icons.home_rounded;
    if (lowerGroup.contains('phát triển') || lowerGroup.contains('học')) {
      return Icons.psychology_rounded;
    }
    if (lowerGroup.contains('sức khỏe') || lowerGroup.contains('y tế')) {
      return Icons.medical_services_rounded;
    }
    if (lowerGroup.contains('ngân hàng')) return Icons.account_balance_rounded;
    if (lowerGroup.contains('vay') || lowerGroup.contains('nợ')) {
      return Icons.credit_score_rounded;
    }
    if (lowerGroup.contains('thu nhập')) return Icons.monetization_on_rounded;
    if (lowerGroup.contains('đầu tư')) return Icons.trending_up_rounded;
    return Icons.folder_rounded;
  }

  String _getSortLabel(String type) {
    if (type == 'amount_desc') return "Cao nhất";
    if (type == 'amount_asc') return "Thấp nhất";
    return "Ngày gần nhất";
  }

  String _formatMoney(double amount) {
    return NumberFormat('#,###', 'en_US').format(amount).replaceAll(',', '.');
  }
}

class _ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ScaleOnTap({required this.child, this.onTap});

  @override
  State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
