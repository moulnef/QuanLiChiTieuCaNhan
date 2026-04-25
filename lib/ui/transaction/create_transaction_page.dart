import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import 'transaction_controller.dart';
import '../../domain/model/transaction_model.dart';
import '../../domain/model/category_model.dart';
import '../../data/local/category_data.dart';
import 'category_list_screen.dart';

class CreateTransactionPage extends ConsumerStatefulWidget {
  final TransactionModel? editData;
  const CreateTransactionPage({super.key, this.editData});

  @override
  ConsumerState<CreateTransactionPage> createState() =>
      _CreateTransactionPageState();
}

class _CreateTransactionPageState extends ConsumerState<CreateTransactionPage> {
  String _amountString = "0";
  String _currentType = 'expense';
  DateTime _selectedDate = DateTime.now();
  String _categoryId = '';
  CategoryModel? _selectedCategory;
  final TextEditingController _noteInput = TextEditingController();

  bool _isNumpadVisible = true;
  bool _isSaving = false;
  bool _isSuccess = false;
  bool _isFrequentExpanded = false;
  List<CategoryModel> _frequentCategories = [];
  final NumberFormat _compactFormatter = NumberFormat.compact(locale: 'vi');

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      _amountString = widget.editData!.amount.toStringAsFixed(0);
      _currentType = widget.editData!.type;
      _selectedDate = widget.editData!.transactionDate;
      _categoryId = widget.editData!.categoryId;
      _noteInput.text = widget.editData!.note;

      final allCategories = CategoryData.getAllCategories();
      _selectedCategory = allCategories
          .where((c) => c.name == _categoryId)
          .firstOrNull;
      _isNumpadVisible = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFrequentCategories();
    });
  }

  @override
  void dispose() {
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
    return '+${_compactFormatter.format(amount)}';
  }

  void _applyQuickAmount(int amount) {
    if (_isSuccess) return;
    _evaluateMath();
    final currentAmount = double.tryParse(_amountString) ?? 0;
    final nextAmount = (currentAmount + amount).round();
    setState(() {
      _amountString = nextAmount.toString();
      _isNumpadVisible = true;
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
  }

  String _formatNumberPart(String numStr) {
    if (numStr.isEmpty) return "";
    if (numStr.contains('.')) {
      List<String> parts = numStr.split('.');
      String intPart = parts[0];
      String decPart = parts.length > 1 ? parts[1] : '';

      String formattedInt = "0";
      if (intPart.isNotEmpty) {
        formattedInt = NumberFormat(
          '#,###',
          'en_US',
        ).format(double.parse(intPart)).replaceAll(',', '.');
      }
      return decPart.isEmpty ? "$formattedInt," : "$formattedInt,$decPart";
    } else {
      return NumberFormat(
        '#,###',
        'en_US',
      ).format(double.parse(numStr)).replaceAll(',', '.');
    }
  }

  String _getFormattedAmount() {
    if (_amountString == "0" || _amountString.isEmpty) return "0";
    try {
      String result = "";
      String currentNum = "";
      for (int i = 0; i < _amountString.length; i++) {
        String char = _amountString[i];
        if (char == '+' || char == '-' || char == 'x' || char == '÷') {
          if (currentNum.isNotEmpty) {
            result += _formatNumberPart(currentNum);
            currentNum = "";
          }
          result += " $char ";
        } else {
          currentNum += char;
        }
      }
      if (currentNum.isNotEmpty) {
        result += _formatNumberPart(currentNum);
      }
      return result;
    } catch (e) {
      return _amountString;
    }
  }

  void _onNumpadTap(String value) {
    if (_isSuccess || value.trim().isEmpty) return;

    setState(() {
      if (value == 'C') {
        _amountString = "0";
      } else if (value == 'Xóa') {
        if (_amountString.length > 1) {
          _amountString = _amountString.substring(0, _amountString.length - 1);
        } else {
          _amountString = "0";
        }
      } else if (value == 'Xong') {
        _evaluateMath();
        _isNumpadVisible = false;
      } else if (value == '+' || value == '-' || value == 'x' || value == '÷') {
        if (_amountString.endsWith('+') ||
            _amountString.endsWith('-') ||
            _amountString.endsWith('x') ||
            _amountString.endsWith('÷')) {
          _amountString =
              _amountString.substring(0, _amountString.length - 1) + value;
        } else {
          _amountString += value;
        }
      } else if (value == '.') {
        String lastPart = _amountString.split(RegExp(r'[\+\-x÷]')).last;
        if (!lastPart.contains('.')) {
          if (_amountString.isEmpty ||
              _amountString.endsWith('+') ||
              _amountString.endsWith('-') ||
              _amountString.endsWith('x') ||
              _amountString.endsWith('÷')) {
            _amountString += '0.';
          } else {
            _amountString += '.';
          }
        }
      } else {
        if (_amountString == "0") {
          _amountString = (value == '000' || value == '0') ? "0" : value;
        } else {
          _amountString += value;
        }
      }
    });
  }

  void _evaluateMath() {
    try {
      while (_amountString.endsWith('+') ||
          _amountString.endsWith('-') ||
          _amountString.endsWith('x') ||
          _amountString.endsWith('÷')) {
        _amountString = _amountString.substring(0, _amountString.length - 1);
      }
      if (_amountString.isEmpty) {
        _amountString = "0";
        return;
      }

      String expr = _amountString.replaceAll('x', '*').replaceAll('÷', '/');
      if (expr.startsWith('+') || expr.startsWith('-')) {
        expr = '0$expr';
      }

      List<double> numbers = [];
      List<String> ops = [];
      String currentNumber = '';

      for (int i = 0; i < expr.length; i++) {
        String char = expr[i];
        if (char == '+' || char == '-' || char == '*' || char == '/') {
          if (currentNumber.isNotEmpty) {
            numbers.add(double.parse(currentNumber));
            currentNumber = '';
          }
          ops.add(char);
        } else {
          currentNumber += char;
        }
      }
      if (currentNumber.isNotEmpty) numbers.add(double.parse(currentNumber));

      if (numbers.length <= ops.length) return;

      for (int i = 0; i < ops.length; i++) {
        if (ops[i] == '*' || ops[i] == '/') {
          double left = numbers[i];
          double right = numbers[i + 1];
          double res = ops[i] == '*'
              ? left * right
              : (right == 0 ? 0 : left / right);
          numbers[i] = res;
          numbers.removeAt(i + 1);
          ops.removeAt(i);
          i--;
        }
      }

      double result = numbers[0];
      for (int i = 0; i < ops.length; i++) {
        if (ops[i] == '+') result += numbers[i + 1];
        if (ops[i] == '-') result -= numbers[i + 1];
      }

      if (result == result.toInt()) {
        _amountString = result.toInt().toString();
      } else {
        _amountString = result
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
    } catch (e) {
      _amountString = "0";
    }
  }

  void _handleSaveData() async {
    if (_isSaving || _isSuccess) return;
    _evaluateMath();

    double amount = double.tryParse(_amountString) ?? 0;
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
        _isNumpadVisible = false;
      });
      _showCompactNotification(
        widget.editData != null
            ? "Cập nhật thành công!"
            : "Lưu giao dịch thành công!",
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
                const Text(
                  "Xóa giao dịch này?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Dữ liệu bị xóa sẽ không thể khôi phục lại được. Bạn có chắc chắn muốn tiếp tục?",
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
                        child: const Text(
                          "Hủy",
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
                        child: const Text(
                          "Xóa",
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
        "Đã xóa giao dịch",
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
                                    child: const Text(
                                      "Hôm nay",
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
          isEditing ? "Chi tiết giao dịch" : "Thêm giao dịch",
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
                if (_isNumpadVisible) setState(() => _isNumpadVisible = false);
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.opaque,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildToggleType(),
                  const SizedBox(height: 20),
                  _buildAmountBox(),
                  const SizedBox(height: 16),
                  _buildQuickAmountSection(),
                  const SizedBox(height: 16),
                  _buildCategoryBox(),
                  const SizedBox(height: 16),
                  _buildFrequentCategoryBox(),
                  const SizedBox(height: 16),
                  _buildDateBox(),
                  const SizedBox(height: 16),
                  _buildNoteBox(),
                ],
              ),
            ),
          ),
          if (_isNumpadVisible)
            _buildNumpad()
          else if (isEditing)
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
            color: Colors.black.withValues(alpha: 0.03),
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
      child: GestureDetector(
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
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountBox() {
    return GestureDetector(
      onTap: () => setState(() => _isNumpadVisible = true),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Số tiền",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${_getFormattedAmount()} đ",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _currentType == 'expense'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chạm để nhập hoặc dùng gợi ý bên dưới',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flash_on_rounded,
                color: Color(0xFFF59E0B),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Nhập nhanh',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAmounts
                .map(
                  (amount) => InkWell(
                    onTap: () => _applyQuickAmount(amount),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        _quickAmountLabel(amount),
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBox() {
    bool hasValue = _selectedCategory != null;
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        highlightColor: const Color(0xFFF0F5FF),
        splashColor: Colors.transparent,
      ),
      child: InkWell(
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
          if (res != null)
            setState(() {
              _selectedCategory = res;
              _categoryId = res.name;
            });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (hasValue ? _selectedCategory!.color : Colors.grey)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: _renderSmartIcon(_selectedCategory, 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  hasValue ? _selectedCategory!.name : "Chọn hạng mục",
                  style: TextStyle(
                    fontSize: 16,
                    color: hasValue
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                "Tất cả",
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequentCategoryBox() {
    return Container(
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
          Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              highlightColor: const Color(0xFFF0F5FF),
              splashColor: Colors.transparent,
            ),
            child: InkWell(
              onTap: () =>
                  setState(() => _isFrequentExpanded = !_isFrequentExpanded),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Hạng mục thường dùng",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
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
          ),
          if (_isFrequentExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _frequentCategories.map((cat) {
                  bool isCatSelected = _selectedCategory?.name == cat.name;
                  return GestureDetector(
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
                            ? const Color(0xFF6D28D9).withValues(alpha: 0.1)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCatSelected
                              ? const Color(0xFF6D28D9)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _renderSmartIcon(cat, 18),
                          const SizedBox(width: 8),
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: isCatSelected
                                  ? const Color(0xFF6D28D9)
                                  : const Color(0xFF334155),
                              fontWeight: isCatSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
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

  Widget _buildDateBox() {
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
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        highlightColor: const Color(0xFFF0F5FF),
        splashColor: Colors.transparent,
      ),
      child: InkWell(
        onTap: () async {
          final picked = await _showCustomDateTimePicker(
            context,
            _selectedDate,
          );
          if (picked != null) setState(() => _selectedDate = picked);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF1D4ED8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "$weekday, ${DateFormat('dd/MM/yyyy').format(_selectedDate)}",
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('HH:mm').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildDateQuickChip(
                    label: 'Hôm nay',
                    onTap: () => _quickPickDate(DateTime.now()),
                  ),
                  const SizedBox(width: 8),
                  _buildDateQuickChip(
                    label: 'Hôm qua',
                    onTap: () => _quickPickDate(
                      DateTime.now().subtract(const Duration(days: 1)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateQuickChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFC7D2FE)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4338CA),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        controller: _noteInput,
        onTap: () => setState(() => _isNumpadVisible = false),
        decoration: const InputDecoration(
          icon: Icon(Icons.notes_rounded, color: Color(0xFF94A3B8), size: 24),
          hintText: "Ghi chú thêm...",
          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
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

  Widget _buildSaveButtonOnly() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _handleSaveData,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            "LƯU GIAO DỊCH",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _showDeleteConfirmDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "XÓA",
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6D28D9).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _handleSaveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "LƯU LẠI",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _buildKey('C')),
                Expanded(child: _buildKey('÷')),
                Expanded(child: _buildKey('x')),
                Expanded(child: _buildKey('Xóa')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildKey('7')),
                Expanded(child: _buildKey('8')),
                Expanded(child: _buildKey('9')),
                Expanded(child: _buildKey('+')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildKey('4')),
                Expanded(child: _buildKey('5')),
                Expanded(child: _buildKey('6')),
                Expanded(child: _buildKey('-')),
              ],
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildKey('1')),
                            Expanded(child: _buildKey('2')),
                            Expanded(child: _buildKey('3')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildKey('0')),
                            Expanded(child: _buildKey('000')),
                            Expanded(child: _buildKey('.')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: _buildKey('Xong', isTall: true)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String val, {bool isTall = false}) {
    bool isAction =
        val == 'C' ||
        val == 'Xóa' ||
        val == 'Xong' ||
        val == '+' ||
        val == '-' ||
        val == 'x' ||
        val == '÷';

    BoxDecoration boxDeco;
    Color textColor;

    if (val == 'Xong') {
      boxDeco = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );
      textColor = Colors.white;
    } else if (isAction) {
      boxDeco = BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      );
      textColor = const Color(0xFF334155);
    } else {
      boxDeco = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      );
      textColor = const Color(0xFF1E293B);
    }

    Widget content = Container(
      margin: EdgeInsets.only(
        right: val != 'Xong' && val != 'Xóa' && val != '+' && val != '-'
            ? 8
            : 0,
      ),
      decoration: boxDeco,
      child: Center(
        child: val == 'Xóa'
            ? const Icon(
                Icons.backspace_rounded,
                color: Color(0xFF334155),
                size: 24,
              )
            : Text(
                val,
                style: TextStyle(
                  fontSize: isAction ? 20 : 24,
                  fontWeight: isAction ? FontWeight.bold : FontWeight.w600,
                  color: textColor,
                ),
              ),
      ),
    );

    Widget button = Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        highlightColor: val == 'Xong' ? Colors.white24 : Colors.grey.shade200,
        splashColor: Colors.transparent,
      ),
      child: InkWell(
        onTap: () => _onNumpadTap(val),
        borderRadius: BorderRadius.circular(val == 'Xong' ? 16 : 12),
        child: content,
      ),
    );

    return isTall ? button : AspectRatio(aspectRatio: 1.35, child: button);
  }
}
