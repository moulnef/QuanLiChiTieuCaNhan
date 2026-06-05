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
      if (controller.transactions.isEmpty)
        await controller.fetchAllTransactions();

      final filteredTransactions = controller.transactions
          .where((tx) => tx.type == widget.transactionType)
          .toList();

      Map<String, int> counts = {};
      for (var tx in filteredTransactions) {
        counts[tx.categoryId] = (counts[tx.categoryId] ?? 0) + 1;
      }

      var sortedEntries = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      var topIds = sortedEntries.take(4).map((e) => e.key).toList();

      List<CategoryModel> topCategories = [];
      for (var id in topIds) {
        final match = CategoryData.findByIdOrName(id);
        if (match != null) topCategories.add(match);
      }

      if (topCategories.isEmpty)
        topCategories = _allCategories.take(4).toList();

      if (mounted)
        setState(() {
          _frequentCategories = topCategories;
          _isLoadingFrequent = false;
        });
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
    final filteredList = _allCategories
        .where(
          (cat) => cat.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    Map<String, List<CategoryModel>> groupedCategories = {};
    for (var cat in filteredList) {
      String groupName = CategoryData.normalizeLabel(
        cat.group ?? '\u004b\u0068\u00e1\u0063',
      );
      if (!groupedCategories.containsKey(groupName))
        groupedCategories[groupName] = [];
      groupedCategories[groupName]!.add(cat);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.transactionType == 'expense'
              ? '\u0043\u0068\u1ecd\u006e \u0068\u1ea1\u006e\u0067 \u006d\u1ee5\u0063 \u0063\u0068\u0069'
              : '\u0043\u0068\u1ecd\u006e \u0068\u1ea1\u006e\u0067 \u006d\u1ee5\u0063 \u0074\u0068\u0075',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (_searchQuery.isEmpty) _buildFrequentSection(),
                    ...groupedCategories.keys.map(
                      (group) =>
                          _buildGroupSection(group, groupedCategories[group]!),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
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
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            hintText:
                '\u0054\u00ec\u006d \u006b\u0069\u1ebf\u006d \u0074\u0068\u0065\u006f \u0074\u00ea\u006e \u0068\u1ea1\u006e\u0067 \u006d\u1ee5\u0063',
            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
            prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF6D28D9)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequentSection() {
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
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 22),
              SizedBox(width: 8),
              Text(
                '\u0048\u0061\u0079 \u0064\u00f9\u006e\u0067',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingFrequent
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6D28D9),
                  ),
                )
              : Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 0,
                  runSpacing: 16,
                  children: _frequentCategories
                      .map((cat) => _buildGridItem(cat))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(String name, List<CategoryModel> items) {
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
                _capitalizeFirstLetter(name),
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
            children: items.map((cat) => _buildGridItem(cat)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(CategoryModel cat) {
    final selectedValue = widget.selectedCategoryName ?? '';
    bool isSelected = cat.id == selectedValue || cat.name == selectedValue;

    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        highlightColor: const Color(0xFFF0F5FF),
        splashColor: Colors.transparent,
      ),
      child: InkWell(
        onTap: () => Navigator.pop(context, cat),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width:
              (MediaQuery.of(context).size.width - 72) /
              4, // Chia 4 cá»™t Ä‘á»u nhau, trá»« padding
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
                  cat.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
      ),
    );
  }

  // ÄÃƒ Cáº¬P NHáº¬T: Bá»• sung icon cho táº¥t cáº£ cÃ¡c nhÃ³m háº¡ng má»¥c
  IconData _getGroupIcon(String groupName) {
    String lowerGroup = groupName.toLowerCase();

    // --- CÃ¡c nhÃ³m Chi tiÃªu ---
    if (lowerGroup.contains('Äƒn')) return Icons.restaurant_menu_rounded;
    if (lowerGroup.contains('dá»‹ch vá»¥') ||
        lowerGroup.contains('sinh hoáº¡t'))
      return Icons.electrical_services_rounded;
    if (lowerGroup.contains('di chuyá»ƒn') || lowerGroup.contains('Ä‘i láº¡i'))
      return Icons.directions_car_rounded;
    if (lowerGroup.contains('trang phá»¥c') || lowerGroup.contains('mua sáº¯m'))
      return Icons.checkroom_rounded;
    if (lowerGroup.contains('hÆ°á»Ÿng thá»¥') ||
        lowerGroup.contains('giáº£i trÃ­'))
      return Icons.celebration_rounded;
    if (lowerGroup.contains('con cÃ¡i')) return Icons.child_care_rounded;
    if (lowerGroup.contains('hiáº¿u há»‰') ||
        lowerGroup.contains('biáº¿u táº·ng'))
      return Icons.card_giftcard_rounded;
    if (lowerGroup.contains('nhÃ  cá»­a')) return Icons.home_rounded;
    if (lowerGroup.contains('phÃ¡t triá»ƒn') || lowerGroup.contains('há»c'))
      return Icons.psychology_rounded;
    if (lowerGroup.contains('sá»©c khá»e') || lowerGroup.contains('y táº¿'))
      return Icons.medical_services_rounded;
    if (lowerGroup.contains('ngÃ¢n hÃ ng'))
      return Icons.account_balance_rounded;
    if (lowerGroup.contains('vay') || lowerGroup.contains('ná»£'))
      return Icons.credit_score_rounded;

    // --- CÃ¡c nhÃ³m Thu nháº­p ---
    if (lowerGroup.contains('thu nháº­p')) return Icons.monetization_on_rounded;
    if (lowerGroup.contains('Ä‘áº§u tÆ°')) return Icons.trending_up_rounded;

    // Máº·c Ä‘á»‹nh cho nhÃ³m "KhÃ¡c"
    return Icons.category_rounded;
  }
}
