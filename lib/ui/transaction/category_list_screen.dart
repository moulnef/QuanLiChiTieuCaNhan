import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/model/category_model.dart';
import '../../data/local/category_data.dart';
import 'transaction_controller.dart';

class CategoryListScreen extends ConsumerStatefulWidget {
  final String transactionType;
  final String? selectedCategoryName;

  const CategoryListScreen({
    super.key,
    required this.transactionType,
    this.selectedCategoryName,
  });

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  String _searchQuery = "";
  List<CategoryModel> _allCategories = [];
  List<CategoryModel> _frequentCategories = [];
  bool _isLoadingFrequent = true;

  @override
  void initState() {
    super.initState();
    _allCategories = widget.transactionType == 'expense'
        ? CategoryData.getExpenseCategories()
        : CategoryData.getIncomeCategories();
    _loadRealFrequentCategories();
  }

  Future<void> _loadRealFrequentCategories() async {
    try {
      final controller = ref.read(transactionControllerProvider);
      if (controller.transactions.isEmpty) {
        // Giả sử có hàm fetch ở controller, nếu không có bạn có thể bỏ qua dòng này
        // await controller.fetchAllTransactions();
      }
      final filteredTransactions = controller.transactions.where((tx) => tx.type == widget.transactionType).toList();
      Map<String, int> counts = {};
      for (var tx in filteredTransactions) {
        counts[tx.categoryId] = (counts[tx.categoryId] ?? 0) + 1;
      }
      var sortedEntries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      var topIds = sortedEntries.take(4).map((e) => e.key).toList();
      List<CategoryModel> topCategories = [];
      for (var id in topIds) {
        var match = _allCategories.where((cat) => cat.name == id).firstOrNull;
        if (match != null) topCategories.add(match);
      }
      if (topCategories.isEmpty) topCategories = _allCategories.take(4).toList();
      if (mounted) {
        setState(() {
          _frequentCategories = topCategories;
          _isLoadingFrequent = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFrequent = false);
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.trim().isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _allCategories.where((cat) => cat.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    Map<String, List<CategoryModel>> groupedCategories = {};
    for (var cat in filteredList) {
      String groupName = cat.group ?? "Khác";
      if (!groupedCategories.containsKey(groupName)) {
        groupedCategories[groupName] = [];
      }
      groupedCategories[groupName]!.add(cat);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(
            widget.transactionType == 'expense' ? "Chọn hạng mục chi" : "Chọn hạng mục thu",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  if (_searchQuery.isEmpty) _buildFrequentSection(),
                  ...groupedCategories.keys.map((group) => _buildGroupSection(group, groupedCategories[group]!)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: const InputDecoration(
            hintText: "Tìm kiếm theo tên hạng mục",
            hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequentSection() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.black87, size: 22),
                SizedBox(width: 8),
                Text("Hay dùng", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _isLoadingFrequent
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : Wrap(
            alignment: WrapAlignment.start,
            children: _frequentCategories.map((cat) => _buildGridItem(cat)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(String name, List<CategoryModel> items) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(_getGroupIcon(name), color: Colors.black87, size: 22),
                const SizedBox(width: 8),
                Text(_capitalizeFirstLetter(name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.start,
            children: items.map((cat) => _buildGridItem(cat)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(CategoryModel cat) {
    bool isSelected = cat.name == widget.selectedCategoryName;
    return InkWell(
      onTap: () => Navigator.pop(context, cat),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12), // Fix linter warning
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 24),
                  ),
                  if (isSelected)
                    Container(
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.check, color: Colors.white, size: 10),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(cat.name, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getGroupIcon(String groupName) {
    String lowerGroup = groupName.toLowerCase();

    // Icon cho nhóm Vay
    if (lowerGroup.contains('vay')) {
      return Icons.account_balance_wallet_rounded;
    }

    if (lowerGroup.contains('đi lại') || lowerGroup.contains('di chuyển')) return Icons.directions_car_filled;
    if (lowerGroup.contains('ngân hàng') || lowerGroup.contains('tài chính')) return Icons.account_balance;
    if (lowerGroup.contains('thời trang') || lowerGroup.contains('trang phục')) return Icons.checkroom;
    if (lowerGroup.contains('hưởng thụ') || lowerGroup.contains('chăm sóc')) return Icons.spa;
    if (lowerGroup.contains('con cái') || lowerGroup.contains('em bé')) return Icons.child_care;
    if (lowerGroup.contains('hiếu hỉ') || lowerGroup.contains('lễ nghĩa')) return Icons.card_giftcard;
    if (lowerGroup.contains('nhà cửa')) return Icons.house_outlined;
    if (lowerGroup.contains('phát triển bản thân')) return Icons.auto_stories;
    if (lowerGroup.contains('sức khỏe')) return Icons.health_and_safety_rounded;

    if (lowerGroup.contains('ăn')) return Icons.restaurant;
    if (lowerGroup.contains('dịch vụ') || lowerGroup.contains('sinh hoạt')) return Icons.home_repair_service;
    if (lowerGroup.contains('mua sắm')) return Icons.shopping_bag;
    if (lowerGroup.contains('thu nhập')) return Icons.payments;
    if (lowerGroup.contains('giáo dục')) return Icons.school;
    if (lowerGroup.contains('giải trí')) return Icons.sports_esports;

    if (lowerGroup.contains('khác')) {
      return Icons.more_horiz;
    }

    return Icons.grid_view_rounded;
  }
}