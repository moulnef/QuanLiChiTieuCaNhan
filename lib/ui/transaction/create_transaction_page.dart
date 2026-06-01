import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import 'transaction_controller.dart';
import '../../domain/model/transaction_model.dart';
import '../../domain/model/category_model.dart';
import '../../data/local/category_data.dart';
import '../../services/translation_service.dart';
import '../../utils/app_localizer.dart';
import 'category_list_screen.dart';

class CreateTransactionPage extends ConsumerStatefulWidget {
  final TransactionModel? editData;
  const CreateTransactionPage({super.key, this.editData});

  @override
  ConsumerState<CreateTransactionPage> createState() =>
      _CreateTransactionPageState();
}

class _CreateTransactionPageState extends ConsumerState<CreateTransactionPage> {
  late final TextEditingController _amountController;
  final FocusNode _amountFocusNode = FocusNode();
  String _currentType = 'expense';
  DateTime _selectedDate = DateTime.now();
  String _categoryId = '';
  CategoryModel? _selectedCategory;
  final TextEditingController _noteInput = TextEditingController();

  bool _isSaving = false;
  bool _isSuccess = false;
  bool _isFrequentExpanded = false;
  List<CategoryModel> _frequentCategories = [];
  final Map<String, String> _dynamicCategoryTranslations = {};
  final Set<String> _pendingCategoryTranslations = {};

  void _onAmountFocusChange() {
    setState(() {});
  }

  String _displayCategoryName(String raw) {
    final mapped = raw.xtrCategory(context);
    if (mapped != raw) {
      return mapped;
    }
    return _dynamicCategoryTranslations[raw] ?? raw;
  }

  void _queueCategoryTranslations([Iterable<String> extra = const []]) {
    final lang = context.locale.languageCode.toLowerCase();
    if (lang != 'en') {
      if (_dynamicCategoryTranslations.isNotEmpty ||
          _pendingCategoryTranslations.isNotEmpty) {
        _dynamicCategoryTranslations.clear();
        _pendingCategoryTranslations.clear();
      }
      return;
    }

    final candidates = <String>{
      ...extra.map((e) => e.trim()).where((e) => e.isNotEmpty),
      ..._frequentCategories
          .map((e) => e.name.trim())
          .where((e) => e.isNotEmpty),
    };

    final selectedName = _selectedCategory?.name.trim();
    if (selectedName != null && selectedName.isNotEmpty) {
      candidates.add(selectedName);
    }
    if (_categoryId.trim().isNotEmpty) {
      candidates.add(_categoryId.trim());
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
        if (context.locale.languageCode.toLowerCase() != 'en') {
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
  void initState() {
    super.initState();
    if (widget.editData != null) {
      final formatted = NumberFormat('#,###', 'en_US')
          .format(widget.editData!.amount)
          .replaceAll(',', '.');
      _amountController = TextEditingController(text: formatted);
      _currentType = widget.editData!.type;
      _selectedDate = widget.editData!.transactionDate;
      _categoryId = widget.editData!.categoryId;
      _noteInput.text = widget.editData!.note;

      final allCategories = CategoryData.getAllCategories();
      _selectedCategory = allCategories
          .where((c) => c.name == _categoryId)
          .firstOrNull;
    } else {
      _amountController = TextEditingController(text: '0');
    }

    _amountFocusNode.addListener(_onAmountFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFrequentCategories();
      _queueCategoryTranslations();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.removeListener(_onAmountFocusChange);
    _amountFocusNode.dispose();
    _noteInput.dispose();
    super.dispose();
  }

  List<int> get _quickAmounts {
    if (_currentType == 'income') {
      return const [100000, 500000, 1000000, 5000000];
    }
    return const [20000, 50000, 100000, 500000];
  }

  String _quickAmountLabel(int amount) {
    final localeCode = context.locale.languageCode == 'en' ? 'en' : 'vi';
    return '+${NumberFormat.compact(locale: localeCode).format(amount)}';
  }

  void _applyQuickAmount(int amount) {
    if (_isSuccess) return;
    final cleanText = _amountController.text.replaceAll('.', '');
    final currentAmount = double.tryParse(cleanText) ?? 0;
    final nextAmount = (currentAmount + amount).round();
    final formatter = NumberFormat('#,###', 'en_US');
    final formatted = formatter.format(nextAmount).replaceAll(',', '.');
    setState(() {
      _amountController.text = formatted;
    });
  }

  void _quickPickDate(DateTime date) {
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      _selectedDate.hour,
      _selectedDate.minute,
    );
    setState(() => _selectedDate = picked);
  }

  void _showCompactNotification(
    String message,
    Color bgColor,
    IconData iconData,
  ) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconData, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 1),
    );
  }

  void _loadFrequentCategories() {
    final allCats = _currentType == 'expense'
        ? CategoryData.getExpenseCategories()
        : CategoryData.getIncomeCategories();
    final txs = ref
        .read(transactionControllerProvider)
        .transactions
        .where((t) => t.type == _currentType)
        .toList();

    Map<String, int> counts = {};
    for (var tx in txs) {
      counts[tx.categoryId] = (counts[tx.categoryId] ?? 0) + 1;
    }

    var sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    List<CategoryModel> top = [];
    for (var entry in sorted.take(6)) {
      var cat = allCats.where((c) => c.name == entry.key).firstOrNull;
      if (cat != null) top.add(cat);
    }
    if (top.isEmpty) top = allCats.take(6).toList();

    setState(() => _frequentCategories = top);
    _queueCategoryTranslations(top.map((e) => e.name));
  }

  void _handleSaveData() async {
    if (_isSaving || _isSuccess) return;

    final cleanText = _amountController.text.replaceAll('.', '');
    double amount = double.tryParse(cleanText) ?? 0;
    final controller = ref.read(transactionControllerProvider);

    String? error = controller.checkValidation(
      amount,
      _categoryId,
      _currentType,
      '',
    );
    if (error != null) {
      _showCompactNotification(error, Colors.orange, Icons.error_outline);
      return;
    }

    setState(() => _isSaving = true);

    await controller.createOrUpdateTransaction(
      TransactionModel(
        id:
            widget.editData?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        type: _currentType,
        categoryId: _categoryId,
        transactionDate: _selectedDate,
        note: _noteInput.text,
      ),
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isSuccess = true;
      });
      _showCompactNotification(
        widget.editData != null
            ? "Cập nhật thành công!".xtr(context)
            : "Lưu giao dịch thành công!".xtr(context),
        const Color(0xFF10B981),
        Icons.check_circle_outline,
      );
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) Navigator.pop(context);
    }
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Xóa giao dịch này?".xtr(context),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Dữ liệu bị xóa sẽ không thể khôi phục lại được. Bạn có chắc chắn muốn tiếp tục?"
                      .xtr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          "Hủy".xtr(context),
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleDelete();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Xóa".xtr(context),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleDelete() async {
    if (widget.editData != null) {
      ref
          .read(transactionControllerProvider)
          .deleteTransaction(widget.editData!.id);
      _showCompactNotification(
        "Đã xóa giao dịch".xtr(context),
        Colors.red,
        Icons.delete_outline,
      );
      Navigator.pop(context);
    }
  }

  Future<DateTime?> _showCustomDateTimePicker(
    BuildContext context,
    DateTime initialDate,
  ) async {
    DateTime tempDate = initialDate;
    TimeOfDay tempTime = TimeOfDay.fromDateTime(initialDate);
    bool isSelectingDate = true;

    return await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                  () => isSelectingDate = true,
                                ),
                                child: Center(
                                  child: Text(
                                    DateFormat('dd/MM/yyyy').format(tempDate),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelectingDate
                                          ? const Color(0xFF6D28D9)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: const Color(0xFFE2E8F0),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                  () => isSelectingDate = false,
                                ),
                                child: Center(
                                  child: Text(
                                    '${tempTime.hour.toString().padLeft(2, '0')}:${tempTime.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: !isSelectingDate
                                          ? const Color(0xFF6D28D9)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 300,
                              child: isSelectingDate
                                  ? CalendarDatePicker(
                                      initialDate: tempDate,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                      onDateChanged: (date) {
                                        setDialogState(() {
                                          tempDate = date;
                                          isSelectingDate = false;
                                        });
                                      },
                                    )
                                  : CupertinoDatePicker(
                                      mode: CupertinoDatePickerMode.time,
                                      initialDateTime: DateTime(
                                        tempDate.year,
                                        tempDate.month,
                                        tempDate.day,
                                        tempTime.hour,
                                        tempTime.minute,
                                      ),
                                      use24hFormat: true,
                                      onDateTimeChanged:
                                          (DateTime newDateTime) {
                                            setDialogState(
                                              () => tempTime =
                                                  TimeOfDay.fromDateTime(
                                                    newDateTime,
                                                  ),
                                            );
                                          },
                                    ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        tempDate = DateTime.now();
                                        tempTime = TimeOfDay.now();
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFF6D28D9),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      "Hôm nay".xtr(context),
                                      style: TextStyle(
                                        color: Color(0xFF6D28D9),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1D4ED8),
                                          Color(0xFF6D28D9),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(
                                        context,
                                        DateTime(
                                          tempDate.year,
                                          tempDate.month,
                                          tempDate.day,
                                          tempTime.hour,
                                          tempTime.minute,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        "Xong",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ĐÃ SỬA: Thay đổi cat.iconData thành cat.icon
  Widget _renderSmartIcon(CategoryModel? cat, double size) {
    if (cat == null) {
      return Icon(
        Icons.add_circle_outline,
        color: const Color(0xFF94A3B8),
        size: size,
      );
    }
    return Icon(cat.iconData, color: cat.color, size: size);
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.editData != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          (isEditing ? "Chi tiết giao dịch" : "Thêm giao dịch").xtr(context),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _handleSaveData,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
              label: const Text(
                'Lưu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.opaque,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildToggleType(),
                  const SizedBox(height: 16),
                  _buildAmountBox(),
                  const SizedBox(height: 16),
                  _buildCategoryAndDateRow(),
                  const SizedBox(height: 16),
                  _buildNoteBox(),
                  const SizedBox(height: 16),
                  _buildFrequentCategoryBox(),
                ],
              ),
            ),
          ),
          if (isEditing)
            _buildEditButtons()
          else
            _buildSaveButtonOnly(),
        ],
      ),
    );
  }

  Widget _buildToggleType() {
    return Container(
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
        children: [
          _buildToggleOption('expense', 'Chi tiêu'),
          _buildToggleOption('income', 'Thu nhập'),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String type, String label) {
    bool isSelected = _currentType == type;
    return Expanded(
      child: _ScaleOnTap(
        onTap: () {
          if (_currentType != type) {
            setState(() {
              _currentType = type;
              _selectedCategory = null;
              _categoryId = '';
              _noteInput.clear();
              _selectedDate = DateTime.now();
            });
            _loadFrequentCategories();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6D28D9) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              fontWeight: isSelected ? FontWeight.bold : const Color(0xFF6D28D9) == const Color(0xFF6D28D9) ? FontWeight.w600 : FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountBox() {
    final themeColor = _currentType == 'expense'
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);
    final hasFocus = _amountFocusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasFocus
              ? themeColor.withOpacity(0.5)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: hasFocus
                ? themeColor.withOpacity(0.12)
                : Colors.black.withOpacity(0.03),
            blurRadius: hasFocus ? 20 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Số tiền".xtr(context).toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            focusNode: _amountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: themeColor,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "0",
              hintStyle: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: themeColor.withOpacity(0.4),
              ),
              suffixText: " đ",
              suffixStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
              isDense: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              ThousandSeparatorFormatter(),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: _quickAmounts
                  .map(
                    (amount) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _ScaleOnTap(
                        onTap: () => _applyQuickAmount(amount),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Center(
                            child: Text(
                              _quickAmountLabel(amount),
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAndDateRow() {
    _queueCategoryTranslations();
    bool hasCat = _selectedCategory != null;

    List<String> weekdays = [
      'Chủ Nhật',
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
    ];
    String weekday =
        weekdays[_selectedDate.weekday == 7 ? 0 : _selectedDate.weekday];

    return Row(
      children: [
        Expanded(
          child: _ScaleOnTap(
            onTap: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryListScreen(
                    transactionType: _currentType,
                    selectedCategoryName: _selectedCategory?.name,
                  ),
                ),
              );
              if (res != null) {
                setState(() {
                  _selectedCategory = res;
                  _categoryId = res.name;
                });
              }
              if (res != null) {
                _queueCategoryTranslations([res.name]);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              height: 72,
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
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (hasCat ? _selectedCategory!.color : Colors.grey)
                          .withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: _renderSmartIcon(_selectedCategory, 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Danh mục".xtr(context).toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasCat
                              ? _displayCategoryName(_selectedCategory!.name)
                              : "Chọn mục".xtr(context),
                          style: TextStyle(
                            fontSize: 14,
                            color: hasCat
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ScaleOnTap(
            onTap: () async {
              final picked = await _showCustomDateTimePicker(
                context,
                _selectedDate,
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              height: 72,
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
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF1D4ED8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Thời gian".xtr(context).toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${DateFormat('dd/MM').format(_selectedDate)} - ${DateFormat('HH:mm').format(_selectedDate)}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _noteInput,
        decoration: InputDecoration(
          icon: const Icon(Icons.notes_rounded, color: Color(0xFF94A3B8), size: 24),
          hintText: "Ghi chú thêm...".xtr(context),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          border: InputBorder.none,
        ),
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFrequentCategoryBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _ScaleOnTap(
            onTap: () =>
                setState(() => _isFrequentExpanded = !_isFrequentExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Hạng mục thường dùng".xtr(context),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isFrequentExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_isFrequentExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _frequentCategories.map((cat) {
                  bool isCatSelected = _selectedCategory?.name == cat.name;
                  return _ScaleOnTap(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                        _categoryId = cat.name;
                        _isFrequentExpanded = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isCatSelected
                            ? const Color(0xFF6D28D9).withOpacity(0.12)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCatSelected
                              ? const Color(0xFF6D28D9)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _renderSmartIcon(cat, 18),
                          const SizedBox(width: 8),
                          Text(
                            _displayCategoryName(cat.name),
                            style: TextStyle(
                              fontSize: 13,
                              color: isCatSelected
                                  ? const Color(0xFF6D28D9)
                                  : const Color(0xFF334155),
                              fontWeight: isCatSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButtonOnly() {
    return const SizedBox.shrink();
  }

  Widget _buildEditButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _ScaleOnTap(
              onTap: _showDeleteConfirmDialog,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    "XÓA".xtr(context),
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _ScaleOnTap(
              onTap: _handleSaveData,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D28D9).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "LƯU LẠI".xtr(context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    String cleanText = newValue.text.replaceAll('.', '');
    if (cleanText.startsWith('0') && cleanText.length > 1) {
      cleanText = cleanText.replaceFirst(RegExp(r'^0+'), '');
    }

    if (cleanText.isEmpty) {
      return const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
    }

    final formatter = NumberFormat('#,###', 'en_US');
    final parsed = double.tryParse(cleanText);
    if (parsed == null) return oldValue;
    String formatted = formatter.format(parsed).replaceAll(',', '.');

    int digitsBeforeCursor = newValue.selection.end > newValue.text.length
        ? cleanText.length
        : newValue.text.substring(0, newValue.selection.end).replaceAll('.', '').length;

    int newCursorPosition = 0;
    int digitCount = 0;
    while (newCursorPosition < formatted.length && digitCount < digitsBeforeCursor) {
      if (formatted[newCursorPosition] != '.') {
        digitCount++;
      }
      newCursorPosition++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
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
