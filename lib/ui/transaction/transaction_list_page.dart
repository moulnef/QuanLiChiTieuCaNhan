import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'transaction_list_controller.dart';
import '../transaction/create_transaction_page.dart';
import '../../data/local/category_data.dart';
import '../../domain/model/transaction_model.dart';
import '../../domain/model/category_model.dart';
import 'time_settings_page.dart';

class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});

  @override
  ConsumerState<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  bool _isSearchMode = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListControllerProvider);
    final controller = ref.read(transactionListControllerProvider.notifier);
    double totalBalance = state.totalIncome - state.totalExpense;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF0F5FF), // Nền Galaxy Nhạt
      endDrawer: _buildRightDrawer(ref, state),
      body: Column(
        children: [
          // --- HEADER GALAXY GRADIENT ---
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20, right: 20, bottom: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32),
              ),
            ),
            child: _isSearchMode
                ? Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      onChanged: (value) => controller.updateSearch(value),
                      decoration: InputDecoration(
                        hintText: "Tìm kiếm...",
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Giao dịch",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _isSearchMode = true),
                      icon: const Icon(Icons.search_rounded, color: Colors.white),
                      splashRadius: 24,
                    ),
                    IconButton(
                      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                      icon: const Icon(Icons.tune_rounded, color: Colors.white),
                      splashRadius: 24,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTransactionPage())),
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                        splashRadius: 24,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          // --- TAB BARS ---
          _buildTabBar(state, controller),

          // --- SUMMARY BOXES ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _buildStatBox("Thu nhập", "+${_formatMoney(state.totalIncome)} đ", const Color(0xFF10B981))),
                const SizedBox(width: 10),
                Expanded(child: _buildStatBox("Chi tiêu", "-${_formatMoney(state.totalExpense)} đ", const Color(0xFFEF4444))),
                const SizedBox(width: 10),
                Expanded(child: _buildStatBox("Tổng", "${totalBalance < 0 ? '-' : ''}${_formatMoney(totalBalance.abs())} đ", const Color(0xFF1D4ED8))),
              ],
            ),
          ),

          // --- DANH SÁCH GIAO DỊCH ---
          Expanded(
            child: state.transactions.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9))),
              error: (err, stack) => Center(child: Text('Lỗi: $err')),
              data: (_) {
                if (state.filteredList.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text("Không có giao dịch nào.", style: TextStyle(color: Colors.grey, fontSize: 15)),
                    ),
                  );
                }

                Map<String, List<TransactionModel>> groupedData = {};
                for (var tx in state.filteredList) {
                  String dateKey = DateFormat('yyyy-MM-dd').format(tx.date);
                  if (!groupedData.containsKey(dateKey)) groupedData[dateKey] = [];
                  groupedData[dateKey]!.add(tx);
                }

                List<Widget> groupWidgets = [];
                groupedData.forEach((dateKey, txList) {
                  DateTime parsedDate = DateTime.parse(dateKey);
                  double dailyTotal = 0;
                  for (var tx in txList) {
                    if (tx.type == 'income') { dailyTotal += tx.amount; } else { dailyTotal -= tx.amount; }
                  }

                  groupWidgets.add(
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_getFormattedDate(parsedDate), style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("${dailyTotal < 0 ? '-' : (dailyTotal > 0 ? '+' : '')}${_formatMoney(dailyTotal.abs())} đ", style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13))
                            ],
                          ),
                        ),
                        ...txList.map((tx) {
                          final isExpense = tx.type == 'expense';
                          final category = CategoryData.getAllCategories().where((c) => c.name == tx.categoryId).firstOrNull;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                            child: Theme(
                              data: Theme.of(context).copyWith(hoverColor: Colors.transparent, splashColor: Colors.transparent),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionPage(editData: tx))),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46, height: 46,
                                        decoration: BoxDecoration(color: (category?.color ?? Colors.grey).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                                        child: Icon(category?.iconData ?? Icons.receipt_long, color: category?.color ?? Colors.grey, size: 22),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(tx.note.isNotEmpty ? tx.note : tx.categoryId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(tx.categoryId, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("${isExpense ? '-' : '+'}${_formatMoney(tx.amount)} đ", style: TextStyle(color: isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text(DateFormat('HH:mm').format(tx.date), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                        ],
                                      )
                                    ],
                                  ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: ['Tất cả', 'Thu nhập', 'Chi tiêu'].map((tab) {
          final isSelected = state.currentTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => controller.changeTab(tab),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: isSelected ? const Color(0xFF6D28D9) : Colors.transparent, borderRadius: BorderRadius.circular(26)),
                child: Text(tab, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
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
                  const Text("Lọc & Sắp xếp", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.category_rounded, color: Colors.blue)),
              title: const Text("Danh mục", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(state.selectedCategoryGroup ?? "Tất cả"),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () { Navigator.pop(context); _showCategoryFilter(context, ref, state); },
            ),
            const Divider(indent: 60, color: Color(0xFFF1F5F9)),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.sort_rounded, color: Colors.orange)),
              title: const Text("Sắp xếp", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_getSortLabel(state.sortType)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () { Navigator.pop(context); _showSortFilter(context, ref, state); },
            ),
            const Divider(indent: 60, color: Color(0xFFF1F5F9)),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.calendar_today_rounded, color: Colors.green)),
              title: const Text("Thời gian", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(state.filterDateRange != null ? "${DateFormat('dd/MM').format(state.filterDateRange!.start)} - ${DateFormat('dd/MM').format(state.filterDateRange!.end)}" : "Tất cả"),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const TimeSettingsPage())); },
            )
          ],
        ),
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    List<String> weekdays = ['Chủ Nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
    return "${weekdays[date.weekday == 7 ? 0 : date.weekday]}, ${DateFormat('dd/MM/yyyy').format(date)}";
  }

  // --- CẬP NHẬT: Giao diện lọc y chang CategoryListScreen, lấy data theo Tab hiện tại ---
  void _showCategoryFilter(BuildContext context, WidgetRef ref, TransactionListState state) {
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) {
          String searchQuery = "";

          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setSheetState) {
                final filteredList = baseCategories.where((cat) => cat.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();

                Map<String, List<CategoryModel>> groupedCategories = {};
                for (var cat in filteredList) {
                  String groupName = cat.group ?? "Khác";
                  if (!groupedCategories.containsKey(groupName)) groupedCategories[groupName] = [];
                  groupedCategories[groupName]!.add(cat);
                }

                return FractionallySizedBox(
                    heightFactor: 0.88, // Chiếm 88% màn hình
                    child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10))),
                          const SizedBox(height: 16),
                          const Text("Lọc theo hạng mục", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          const SizedBox(height: 16),

                          // Nút "Tất cả giao dịch" (Bỏ lọc)
                          Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: InkWell(
                                  onTap: () {
                                    ref.read(transactionListControllerProvider.notifier).updateCategoryGroup(null);
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: state.selectedCategoryGroup == null ? const Color(0xFF6D28D9).withValues(alpha: 0.1) : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: state.selectedCategoryGroup == null ? const Color(0xFF6D28D9) : Colors.transparent),
                                        boxShadow: state.selectedCategoryGroup == null ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                      ),
                                      child: Row(
                                          children: [
                                            Icon(Icons.apps_rounded, color: state.selectedCategoryGroup == null ? const Color(0xFF6D28D9) : const Color(0xFF64748B)),
                                            const SizedBox(width: 12),
                                            Text("Tất cả hạng mục", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: state.selectedCategoryGroup == null ? const Color(0xFF6D28D9) : const Color(0xFF334155))),
                                            const Spacer(),
                                            if (state.selectedCategoryGroup == null) const Icon(Icons.check_circle_rounded, color: Color(0xFF6D28D9))
                                          ]
                                      )
                                  )
                              )
                          ),
                          const SizedBox(height: 12),

                          // Ô Tìm kiếm (Giống CategoryListScreen)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: TextField(
                                onChanged: (v) => setSheetState(() => searchQuery = v),
                                style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                                decoration: const InputDecoration(
                                  hintText: "Tìm kiếm theo tên hạng mục...",
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                                  prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF6D28D9)),
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
                                              ref.read(transactionListControllerProvider.notifier).updateCategoryGroup(catName);
                                              Navigator.pop(context);
                                            }
                                        );
                                      }),
                                      const SizedBox(height: 40),
                                    ],
                                  )
                              )
                          )
                        ]
                    )
                );
              }
          );
        }
    );
  }

  Widget _buildFilterGroupSection(String name, List<CategoryModel> items, String? selectedCategory, Function(String) onTapCategory) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: Icon(_getGroupIcon(name), color: const Color(0xFF64748B), size: 18),
              ),
              const SizedBox(width: 10),
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 0,
            runSpacing: 16,
            children: items.map((cat) => _buildFilterGridItem(cat, selectedCategory, onTapCategory)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGridItem(CategoryModel cat, String? selectedCategory, Function(String) onTapCategory) {
    bool isSelected = cat.name == selectedCategory;

    return Builder(
        builder: (context) {
          return InkWell(
            onTap: () => onTapCategory(cat.name),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: (MediaQuery.of(context).size.width - 72) / 4, // Chia đúng 4 cột giống trang bên kia
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(cat.iconData, color: cat.color, size: 24),
                      ),
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)]),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.check, color: Colors.white, size: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF334155),
                        ),
                        textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  void _showSortFilter(BuildContext context, WidgetRef ref, TransactionListState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Container(width: 40, height: 4, decoration: const BoxDecoration(color: Color(0xFFE2E8F0), borderRadius: BorderRadius.all(Radius.circular(10))))),
            _buildSheetOption(label: "Ngày gần nhất", icon: Icons.access_time_filled_rounded, isSelected: state.sortType == 'date_desc', onTap: () { ref.read(transactionListControllerProvider.notifier).updateSortType('date_desc'); Navigator.pop(context); }),
            _buildSheetOption(label: "Tiền nhiều nhất", icon: Icons.arrow_upward_rounded, isSelected: state.sortType == 'amount_desc', onTap: () { ref.read(transactionListControllerProvider.notifier).updateSortType('amount_desc'); Navigator.pop(context); }),
            _buildSheetOption(label: "Tiền ít nhất", icon: Icons.arrow_downward_rounded, isSelected: state.sortType == 'amount_asc', onTap: () { ref.read(transactionListControllerProvider.notifier).updateSortType('amount_asc'); Navigator.pop(context); }),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetOption({required String label, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: const Color(0xFF6D28D9).withValues(alpha: 0.1),
      leading: Icon(icon, color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF94A3B8)),
      title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF1E293B), fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF6D28D9)) : null,
      onTap: onTap,
    );
  }

  IconData _getGroupIcon(String groupName) {
    String lowerGroup = groupName.toLowerCase();
    if (lowerGroup.contains('ăn')) return Icons.restaurant_menu_rounded;
    if (lowerGroup.contains('dịch vụ') || lowerGroup.contains('sinh hoạt')) return Icons.electrical_services_rounded;
    if (lowerGroup.contains('di chuyển') || lowerGroup.contains('đi lại')) return Icons.directions_car_rounded;
    if (lowerGroup.contains('trang phục') || lowerGroup.contains('mua sắm')) return Icons.checkroom_rounded;
    if (lowerGroup.contains('hưởng thụ') || lowerGroup.contains('giải trí')) return Icons.celebration_rounded;
    if (lowerGroup.contains('con cái')) return Icons.child_care_rounded;
    if (lowerGroup.contains('hiếu hỉ') || lowerGroup.contains('biếu tặng')) return Icons.card_giftcard_rounded;
    if (lowerGroup.contains('nhà cửa')) return Icons.home_rounded;
    if (lowerGroup.contains('phát triển') || lowerGroup.contains('học')) return Icons.psychology_rounded;
    if (lowerGroup.contains('sức khỏe') || lowerGroup.contains('y tế')) return Icons.medical_services_rounded;
    if (lowerGroup.contains('ngân hàng')) return Icons.account_balance_rounded;
    if (lowerGroup.contains('vay') || lowerGroup.contains('nợ')) return Icons.credit_score_rounded;
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