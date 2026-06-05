import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/remote/firestore_service.dart';
import '../../domain/model/transaction_model.dart';
import '../../domain/model/category_model.dart';
import '../../data/local/category_data.dart';
import '../../utils/app_localizer.dart';
import 'category_list_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TextEditingController _amountController = TextEditingController(text: '0');
  final TextEditingController _noteController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  String _currentType = 'expense';
  DateTime _selectedDate = DateTime.now();
  String _categoryId = '';
  CategoryModel? _selectedCategory;

  bool _isSaving = false;
  bool _isSuccess = false;
  bool _isFrequentExpanded = false;
  List<CategoryModel> _frequentCategories = [];
  bool _isLoadingFrequent = false;

  @override
  void initState() {
    super.initState();
    // Default category 'Ăn uống' or 'e2'
    _selectedCategory = CategoryData.findByIdOrName('e2');
    if (_selectedCategory != null) {
      _categoryId = _selectedCategory!.id;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFrequentCategories();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
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

  void _showTopNotification(String message, Color bgColor, IconData icon) {
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
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
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
      displayDuration: const Duration(milliseconds: 1500),
    );
  }

  void _loadFrequentCategories() async {
    setState(() => _isLoadingFrequent = true);
    try {
      final allCats = _currentType == 'expense'
          ? CategoryData.getExpenseCategories()
          : CategoryData.getIncomeCategories();
      final txs = await _firestoreService.getTransactions();
      final filteredTxs = txs.where((t) => t.type == _currentType).toList();

      Map<String, int> counts = {};
      for (var tx in filteredTxs) {
        counts[tx.categoryId] = (counts[tx.categoryId] ?? 0) + 1;
      }

      var sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      List<CategoryModel> top = [];
      for (var entry in sorted.take(8)) {
        final cat = CategoryData.findByIdOrName(entry.key);
        if (cat != null) top.add(cat);
      }
      if (top.isEmpty) top = allCats.take(8).toList();

      if (mounted) {
        setState(() {
          _frequentCategories = top;
          _isLoadingFrequent = false;
        });
      }
    } catch (e) {
      final allCats = _currentType == 'expense'
          ? CategoryData.getExpenseCategories()
          : CategoryData.getIncomeCategories();
      if (mounted) {
        setState(() {
          _frequentCategories = allCats.take(8).toList();
          _isLoadingFrequent = false;
        });
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (_isSaving || _isSuccess) return;

    final cleanText = _amountController.text.replaceAll('.', '');
    final amount = double.tryParse(cleanText);

    if (amount == null || amount <= 0 || _categoryId.isEmpty) {
      _showTopNotification(
        "Vui lòng nhập số tiền và chọn danh mục hợp lệ".xtr(context),
        AppColors.warning,
        Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uId = _firestoreService.userId;

      final tx = TransactionModel(
        id: '',
        userId: uId,
        walletId: 'wallet_cash_$uId',
        categoryId: _categoryId,
        categoryName: _selectedCategory?.name ?? '',
        type: _currentType,
        amount: amount,
        note: _noteController.text.trim(),
        transactionDate: _selectedDate,
      );

      await _firestoreService.addTransaction(tx);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSuccess = true;
        });
        _showTopNotification(
          "Lưu giao dịch thành công!".xtr(context),
          AppColors.teal,
          Icons.check_circle_outline,
        );
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showTopNotification(
          "Lỗi khi lưu: $e",
          AppColors.danger,
          Icons.error_outline,
        );
      }
    }
  }

  String _displayCategoryName(String raw) {
    return raw.xtrCategory(context);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _applyQuickDatePreset(DateTime date) {
    if (_isSuccess) return;
    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
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
              return Column(
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
                                      ? AppColors.primaryPurple
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
                                      ? AppColors.primaryPurple
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
                                  onDateTimeChanged: (DateTime newDateTime) {
                                    setDialogState(
                                      () => tempTime = TimeOfDay.fromDateTime(
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
                                    color: AppColors.primaryPurple,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  "Hôm nay".xtr(context),
                                  style: const TextStyle(
                                    color: AppColors.primaryPurple,
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
                                      AppColors.darkBlue,
                                      AppColors.primaryPurple,
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
                                      borderRadius: BorderRadius.circular(12),
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
              );
            },
          ),
        );
      },
    );
  }

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

  void _showCustomNumpadSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Số tiền nhập".xtr(context),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_amountController.text} đ",
                          style: TextStyle(
                            color: _currentType == 'expense'
                                ? AppColors.danger
                                : AppColors.safe,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.6,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final keys = [
                          '1', '2', '3',
                          '4', '5', '6',
                          '7', '8', '9',
                          ',', '0', 'backspace'
                        ];
                        final key = keys[index];
                        if (key == 'backspace') {
                          return _buildNumpadKeyButton(
                            child: const Icon(
                              Icons.backspace_rounded,
                              color: Color(0xFF334155),
                            ),
                            onTap: () {
                              _updateAmountFromKey('backspace');
                              setSheetState(() {});
                            },
                          );
                        }
                        return _buildNumpadKeyButton(
                          child: Text(
                            key,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          onTap: () {
                            _updateAmountFromKey(key);
                            setSheetState(() {});
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: Text(
                          "Xong".xtr(context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNumpadKeyButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return _ScaleOnTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: child),
      ),
    );
  }

  void _updateAmountFromKey(String key) {
    if (_isSuccess) return;
    final cleanText = _amountController.text.replaceAll('.', '');
    if (key == 'backspace') {
      if (cleanText.isEmpty || cleanText == '0') {
        _amountController.text = '0';
      } else if (cleanText.length <= 1) {
        _amountController.text = '0';
      } else {
        final next = cleanText.substring(0, cleanText.length - 1);
        _formatAndSetAmount(double.tryParse(next) ?? 0);
      }
    } else if (key == ',') {
      // Ignore decimal
    } else {
      if (cleanText == '0') {
        _formatAndSetAmount(double.tryParse(key) ?? 0);
      } else {
        if (cleanText.length < 12) {
          final next = cleanText + key;
          _formatAndSetAmount(double.tryParse(next) ?? 0);
        }
      }
    }
    setState(() {});
  }

  void _formatAndSetAmount(double val) {
    final formatter = NumberFormat('#,###', 'en_US');
    final formatted = formatter.format(val.round()).replaceAll(',', '.');
    setState(() {
      _amountController.text = formatted;
    });
  }

  Widget _buildLivePreviewCard() {
    final isExpense = _currentType == 'expense';
    final gradientColors = isExpense
        ? [AppColors.danger, AppColors.darkRed]
        : [AppColors.safe, AppColors.darkGreen];

    final amount = _amountController.text.isNotEmpty ? _amountController.text : "0";
    final categoryLabel = _selectedCategory != null
        ? _displayCategoryName(_selectedCategory!.name)
        : "Chọn danh mục".xtr(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      height: MediaQuery.of(context).size.height * 0.32,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isExpense ? AppColors.danger : AppColors.safe).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isExpense ? "↑ Chi tiêu".xtr(context) : "↓ Thu nhập".xtr(context),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                DateFormat('dd/MM • HH:mm').format(_selectedDate),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "$amount đ",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              categoryLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            child: TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Thêm ghi chú...".xtr(context),
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) {
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleType() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
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
              _noteController.clear();
              _selectedDate = DateTime.now();
            });
            _loadFrequentCategories();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label.xtr(context),
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountBox() {
    final themeColor = _currentType == 'expense'
        ? AppColors.danger
        : AppColors.safe;

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "SỐ TIỀN".xtr(context),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showCustomNumpadSheet,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _amountController.text.isNotEmpty ? _amountController.text : "0",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "đ",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: _quickAmounts.map((amount) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _ScaleOnTap(
                    onTap: () {
                      _applyQuickAmount(amount);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
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
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateStrip() {
    final now = DateTime.now();
    final presets = <({String label, DateTime date})>[
      (label: "Hôm nay".xtr(context), date: now),
      (
        label: "Hôm qua".xtr(context),
        date: now.subtract(const Duration(days: 1)),
      ),
      (
        label: "Cuối tuần".xtr(context),
        date: now.add(Duration(days: DateTime.saturday - now.weekday)),
      ),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...presets.map((preset) {
            final selected = _isSameDay(_selectedDate, preset.date);
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: _ScaleOnTap(
                onTap: () => _applyQuickDatePreset(preset.date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.darkBlue : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? AppColors.darkBlue : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: selected ? Colors.white : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        preset.label,
                        style: TextStyle(
                          color: selected ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          _ScaleOnTap(
            onTap: () async {
              final picked = await _showCustomDateTimePicker(context, _selectedDate);
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 15,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Chọn ngày...".xtr(context),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAndDateRow() {
    bool hasCat = _selectedCategory != null;

    return Row(
      children: [
        Expanded(
          child: _ScaleOnTap(
            onTap: () async {
              final res = await showModalBottomSheet<CategoryModel>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: CategoryListScreen(
                    transactionType: _currentType,
                    selectedCategoryName: _selectedCategory?.name,
                  ),
                ),
              );
              if (res != null) {
                setState(() {
                  _selectedCategory = res;
                  _categoryId = res.id;
                });
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
                      color: AppColors.darkBlue.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.darkBlue,
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
                          "${DateFormat('dd/MM').format(_selectedDate)} • ${DateFormat('HH:mm').format(_selectedDate)}",
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
        controller: _noteController,
        decoration: InputDecoration(
          icon: const Icon(
            Icons.menu_rounded,
            color: Color(0xFF94A3B8),
            size: 24,
          ),
          hintText: "Ghi chú thêm...".xtr(context),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          border: InputBorder.none,
        ),
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        onChanged: (val) {
          setState(() {});
        },
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isFrequentExpanded
                ? Column(
                    children: [
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        child: _isLoadingFrequent
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  childAspectRatio: 0.85,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                                itemCount: _frequentCategories.length,
                                itemBuilder: (context, index) {
                                  final cat = _frequentCategories[index];
                                  bool isCatSelected = _selectedCategory?.id == cat.id;
                                  return _ScaleOnTap(
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = cat;
                                        _categoryId = cat.id;
                                      });
                                      _showCustomNumpadSheet();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isCatSelected
                                            ? AppColors.primaryPurple.withOpacity(0.08)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isCatSelected
                                              ? AppColors.primaryPurple
                                              : const Color(0xFFE2E8F0),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: cat.color.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                cat.iconData,
                                                color: cat.color,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              _displayCategoryName(cat.name),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isCatSelected
                                                    ? AppColors.primaryPurple
                                                    : const Color(0xFF475569),
                                                fontWeight: isCatSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
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
                              ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final cleanText = _amountController.text.replaceAll('.', '');
    final amount = double.tryParse(cleanText) ?? 0;
    final isEnabled = amount > 0 && _categoryId.isNotEmpty;

    final themeColor = _currentType == 'expense'
        ? AppColors.danger
        : AppColors.safe;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
      child: SafeArea(
        top: false,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: _ScaleOnTap(
            onTap: (isEnabled && !_isSaving)
                ? () {
                    HapticFeedback.mediumImpact();
                    _saveTransaction();
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 58,
              decoration: BoxDecoration(
                gradient: isEnabled
                    ? LinearGradient(
                        colors: [
                          themeColor,
                          Color.lerp(themeColor, const Color(0xFF111827), 0.15) ??
                              themeColor
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isEnabled ? null : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(50),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: themeColor.withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Lưu giao dịch'.xtr(context),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Thêm giao dịch".xtr(context),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1E293B),
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildLivePreviewCard(),
                  const SizedBox(height: 20),
                  _buildToggleType(),
                  const SizedBox(height: 20),
                  _buildAmountBox(),
                  const SizedBox(height: 20),
                  _buildQuickDateStrip(),
                  const SizedBox(height: 20),
                  _buildCategoryAndDateRow(),
                  const SizedBox(height: 20),
                  _buildNoteBox(),
                  const SizedBox(height: 20),
                  _buildFrequentCategoryBox(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildSaveButton(),
        ],
      ),
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