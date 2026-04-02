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

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _allCategories = widget.transactionType == 'expense'
        ? CategoryData.getExpenseCategories()
        : CategoryData.getIncomeCategories();
    _loadRealFrequentCategories();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedCategory();
    });
  }

  void _scrollToSelectedCategory() {
    if (widget.selectedCategoryName != null && _itemKeys.containsKey(widget.selectedCategoryName)) {
      final context = _itemKeys[widget.selectedCategoryName]!.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRealFrequentCategories() async {
    try {
      final controller = ref.read(transactionControllerProvider);
      if (controller.transactions.isEmpty) await controller.fetchAllTransactions();

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

      if (mounted) setState(() { _frequentCategories = topCategories; _isLoadingFrequent = false; });
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
      if (!groupedCategories.containsKey(groupName)) groupedCategories[groupName] = [];
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
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  if (_searchQuery.isEmpty) _buildFrequentSection(),
                  ...groupedCategories.keys.map((group) => _buildGroupSection(group, groupedCategories[group]!)).toList(),
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
            child: Text("Hay dùng", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                Icon(_getGroupIcon(name), color: Colors.grey.shade700, size: 22),
                const SizedBox(width: 8),
                Text(
                  _capitalizeFirstLetter(name),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
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
    _itemKeys[cat.name] ??= GlobalKey();

    return Theme(
      data: Theme.of(context).copyWith(hoverColor: Colors.transparent, highlightColor: Colors.blue.shade50, splashColor: Colors.transparent),
      child: InkWell(
        key: _itemKeys[cat.name],
        onTap: () => Navigator.pop(context, cat),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      // 💡 ĐÃ SỬA: Quay về dùng Icon chuẩn của thư viện Flutter
                      child: Center(
                        child: Icon(
                          cat.iconData ?? Icons.category, // Sử dụng iconData có sẵn
                          color: cat.color,
                          size: 24,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.check, color: Colors.white, size: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                      cat.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getGroupIcon(String groupName) {
    String lowerGroup = groupName.toLowerCase();
    if (lowerGroup.contains('ăn')) return Icons.restaurant_menu;
    if (lowerGroup.contains('dịch vụ') || lowerGroup.contains('sinh hoạt')) return Icons.house_outlined;
    if (lowerGroup.contains('di chuyển')) return Icons.directions_car_filled_outlined;
    if (lowerGroup.contains('mua sắm')) return Icons.shopping_bag_outlined;
    if (lowerGroup.contains('thu nhập')) return Icons.account_balance_wallet_outlined;
    return Icons.folder_outlined;
  }
}