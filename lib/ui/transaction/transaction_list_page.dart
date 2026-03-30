import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'transaction_list_controller.dart';
import '../transaction/transaction_controller.dart';
import '../transaction/create_transaction_page.dart';
import '../../data/local/category_data.dart';
import '../../domain/model/transaction_model.dart';
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
      backgroundColor: Colors.white,
      endDrawer: _buildRightDrawer(ref, state),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: _isSearchMode
                        ? Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20), onPressed: () { setState(() => _isSearchMode = false); controller.updateSearch(''); }),
                        Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: TextField(autofocus: true, onChanged: (value) => controller.updateSearch(value), decoration: const InputDecoration(hintText: "Tìm kiếm danh mục...", hintStyle: TextStyle(color: Colors.grey, fontSize: 14), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12))))),
                        const SizedBox(width: 8),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Giao dịch", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
                        Row(
                          children: [
                            IconButton(onPressed: () => setState(() => _isSearchMode = true), icon: const Icon(Icons.search, color: Colors.black), splashRadius: 24),
                            IconButton(onPressed: () => _scaffoldKey.currentState?.openEndDrawer(), icon: const Icon(Icons.tune, color: Colors.black), splashRadius: 24),
                            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTransactionPage())), icon: const Icon(Icons.add, color: Colors.black, size: 28), splashRadius: 24),
                          ],
                        )
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['Tất cả', 'Thu nhập', 'Chi tiêu'].map((tab) {
                      final isSelected = state.currentTab == tab;
                      return Expanded(child: GestureDetector(onTap: () => controller.changeTab(tab), behavior: HitTestBehavior.opaque, child: Center(child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? Colors.blue : Colors.transparent, width: 3))), child: Text(tab, style: TextStyle(color: isSelected ? Colors.blue : Colors.grey.shade600, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 15))))));
                    }).toList(),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                ],
              ),
            ),
            Container(height: 8, color: const Color(0xFFF4F7FB)),
            Container(
              color: Colors.white, padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _buildStatBox("Thu nhập", "+${_formatMoney(state.totalIncome)} đ", const Color(0xFF10B981))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatBox("Chi tiêu", "-${_formatMoney(state.totalExpense)} đ", const Color(0xFFEF4444))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatBox("Tổng", "${totalBalance < 0 ? '-' : ''}${_formatMoney(totalBalance.abs())} đ", const Color(0xFF3B82F6))),
                ],
              ),
            ),
            Container(height: 8, color: const Color(0xFFF4F7FB)),
            state.transactions.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (err, stack) => Center(child: Text('Lỗi: $err')),
              data: (_) {
                if (state.filteredList.isEmpty) return Container(color: Colors.white, padding: const EdgeInsets.all(40), alignment: Alignment.center, child: const Text("Không có giao dịch.", style: TextStyle(color: Colors.grey)));
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
                  for (var tx in txList) { if (tx.type == 'income') dailyTotal += tx.amount; else dailyTotal -= tx.amount; }
                  groupWidgets.add(Column(children: [
                    Container(color: Colors.white, child: Column(children: [
                      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_getFormattedDate(parsedDate), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 13)), Text("${dailyTotal < 0 ? '-' : (dailyTotal > 0 ? '+' : '')}${_formatMoney(dailyTotal.abs())} đ", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13))])),
                      Column(children: txList.map((tx) {
                        final isExpense = tx.type == 'expense';
                        final category = CategoryData.getAllCategories().where((c) => c.name == tx.categoryId).firstOrNull;
                        return Theme(data: Theme.of(context).copyWith(hoverColor: Colors.transparent, highlightColor: Colors.blue.shade50, splashColor: Colors.transparent), child: InkWell(onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionPage(editData: tx))); }, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: (category?.color ?? Colors.grey).withOpacity(0.15), shape: BoxShape.circle), child: Icon(category?.iconData ?? Icons.receipt_long, color: category?.color ?? Colors.grey, size: 20)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx.note.isNotEmpty ? tx.note : tx.categoryId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)), const SizedBox(height: 4), Text(tx.categoryId, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("${isExpense ? '-' : '+'}${_formatMoney(tx.amount)} đ", style: TextStyle(color: isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 4), Text(DateFormat('HH:mm').format(tx.date), style: TextStyle(color: Colors.grey.shade400, fontSize: 12))])]))));
                      }).toList())
                    ])),
                    Container(height: 8, color: const Color(0xFFF4F7FB)),
                  ]));
                });
                groupWidgets.add(const SizedBox(height: 80)); return Column(children: groupWidgets);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightDrawer(WidgetRef ref, TransactionListState state) {
    return Drawer(backgroundColor: Colors.white, child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Lọc & Sắp xếp", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))])), const Divider(height: 1), ListTile(leading: const Icon(Icons.category_outlined, color: Colors.blue), title: const Text("Danh mục"), subtitle: Text(state.selectedCategoryGroup ?? "Tất cả"), trailing: const Icon(Icons.chevron_right), onTap: () { Navigator.pop(context); _showCategoryFilter(context, ref, state); }), const Divider(indent: 60), ListTile(leading: const Icon(Icons.sort, color: Colors.orange), title: const Text("Sắp xếp"), subtitle: Text(_getSortLabel(state.sortType)), trailing: const Icon(Icons.chevron_right), onTap: () { Navigator.pop(context); _showSortFilter(context, ref, state); }), const Divider(indent: 60), ListTile(leading: const Icon(Icons.calendar_today_outlined, color: Colors.green), title: const Text("Thời gian"), subtitle: Text(state.filterDateRange != null ? "${DateFormat('dd/MM').format(state.filterDateRange!.start)} - ${DateFormat('dd/MM').format(state.filterDateRange!.end)}" : "Tất cả"), trailing: const Icon(Icons.chevron_right), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const TimeSettingsPage())); })])));
  }

  Widget _buildStatBox(String title, String amount, Color color) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: Column(children: [Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)]));
  }

  String _getFormattedDate(DateTime date) { List<String> weekdays = ['Chủ Nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7']; return "${weekdays[date.weekday == 7 ? 0 : date.weekday]}, ${DateFormat('dd/MM/yyyy').format(date)}"; }

  void _showCategoryFilter(BuildContext context, WidgetRef ref, TransactionListState state) {
    final groups = CategoryData.getAllCategories().map((c) => c.group).where((g) => g != null).toSet().toList();
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [_buildSheetOption(label: "Tất cả danh mục", icon: Icons.apps, isSelected: state.selectedCategoryGroup == null, onTap: () { ref.read(transactionListControllerProvider.notifier).updateCategoryGroup(null); Navigator.pop(context); }), const Divider(height: 1), ...groups.map((g) => _buildSheetOption(label: g!, icon: Icons.folder_outlined, isSelected: state.selectedCategoryGroup == g, onTap: () { ref.read(transactionListControllerProvider.notifier).updateCategoryGroup(g); Navigator.pop(context); }))] ))));
  }

  void _showSortFilter(BuildContext context, WidgetRef ref, TransactionListState state) {
    showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [_buildSheetOption(label: "Ngày gần nhất", icon: Icons.access_time, isSelected: state.sortType == 'date_desc', onTap: () { ref.read(transactionListControllerProvider.notifier).updateSortType('date_desc'); Navigator.pop(context); }), _buildSheetOption(label: "Tiền nhiều nhất", icon: Icons.arrow_upward, isSelected: state.sortType == 'amount_desc', onTap: () { ref.read(transactionListControllerProvider.notifier).updateSortType('amount_desc'); Navigator.pop(context); }), _buildSheetOption(label: "Tiền ít nhất", icon: Icons.arrow_downward, isSelected: state.sortType == 'amount_asc', onTap: () { ref.read(transactionListControllerProvider.notifier).updateSortType('amount_asc'); Navigator.pop(context); })])));
  }

  Widget _buildSheetOption({required String label, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return ListTile(selected: isSelected, selectedTileColor: Colors.blue, leading: Icon(icon, color: isSelected ? Colors.white : Colors.grey), title: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), trailing: isSelected ? const Icon(Icons.check, color: Colors.white) : null, onTap: onTap);
  }

  String _getSortLabel(String type) { if (type == 'amount_desc') return "Cao nhất"; if (type == 'amount_asc') return "Thấp nhất"; return "Ngày gần nhất"; }

  // --- HÀM ĐỊNH DẠNG TIỀN DÙNG DẤU CHẤM (.) ---
  String _formatMoney(double amount) {
    return NumberFormat('#,###', 'en_US').format(amount).replaceAll(',', '.');
  }
}