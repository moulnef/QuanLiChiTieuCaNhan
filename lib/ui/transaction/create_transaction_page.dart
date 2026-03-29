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
  ConsumerState<CreateTransactionPage> createState() => _CreateTransactionPageState();
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

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      _amountString = widget.editData!.amount.toStringAsFixed(0);
      _currentType = widget.editData!.type;
      _selectedDate = widget.editData!.date;
      _categoryId = widget.editData!.categoryId;
      _noteInput.text = widget.editData!.note;

      final allCategories = CategoryData.getAllCategories();
      _selectedCategory = allCategories.where((c) => c.name == _categoryId).firstOrNull;
      _isNumpadVisible = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFrequentCategories();
    });
  }

  void _showCompactNotification(String message, Color bgColor) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.66,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
            child: Row(
              mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 1),
    );
  }

  void _loadFrequentCategories() {
    final allCats = _currentType == 'expense' ? CategoryData.getExpenseCategories() : CategoryData.getIncomeCategories();
    final txs = ref.read(transactionControllerProvider).transactions.where((t) => t.type == _currentType).toList();

    Map<String, int> counts = {};
    for (var tx in txs) {
      counts[tx.categoryId] = (counts[tx.categoryId] ?? 0) + 1;
    }

    var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    List<CategoryModel> top = [];
    for (var entry in sorted.take(6)) {
      var cat = allCats.where((c) => c.name == entry.key).firstOrNull;
      if (cat != null) {
        top.add(cat);
      }
    }
    if (top.isEmpty) {
      top = allCats.take(6).toList();
    }
    setState(() => _frequentCategories = top);
  }

  String _getFormattedAmount() {
    if (_amountString == "0" || _amountString.isEmpty) return "0";
    try {
      String result = "";
      String currentNum = "";
      for (int i = 0; i < _amountString.length; i++) {
        String char = _amountString[i];
        if (char == '+' || char == '-') {
          if (currentNum.isNotEmpty) {
            result += NumberFormat('#,###', 'en_US').format(double.parse(currentNum)).replaceAll(',', '.');
            currentNum = "";
          }
          result += " $char ";
        } else {
          currentNum += char;
        }
      }
      if (currentNum.isNotEmpty) {
        result += NumberFormat('#,###', 'en_US').format(double.parse(currentNum)).replaceAll(',', '.');
      }
      return result;
    } catch (e) {
      return _amountString;
    }
  }

  void _onNumpadTap(String value) {
    if (_isSuccess) return;
    setState(() {
      if (value == 'C') {
        _amountString = "0";
      } else if (value == 'Xóa') {
        if (_amountString.length > 1) {
          _amountString = _amountString.substring(0, _amountString.length - 1);
        } else {
          _amountString = "0";
        }
      } else if (value == 'Xong' || value == '=') {
        _evaluateMath();
        if (value == 'Xong') _isNumpadVisible = false;
      } else if (value == '+' || value == '-') {
        _evaluateMath();
        if (!_amountString.endsWith('+') && (!_amountString.endsWith('-'))) {
          _amountString += value;
        }
      } else {
        if (_amountString == "0") {
          _amountString = value;
        } else {
          _amountString += value;
        }
      }
    });
  }

  void _evaluateMath() {
    try {
      if (_amountString.contains('+')) {
        List<String> parts = _amountString.split('+');
        double sum = 0;
        for (String p in parts) {
          if (p.isNotEmpty) sum += double.parse(p);
        }
        _amountString = sum.toStringAsFixed(0);
      } else if (_amountString.contains('-')) {
        List<String> parts = _amountString.split('-');
        double result = parts.isNotEmpty && parts[0].isNotEmpty ? double.parse(parts[0]) : 0;
        for (int i = 1; i < parts.length; i++) {
          if (parts[i].isNotEmpty) result -= double.parse(parts[i]);
        }
        _amountString = result.toStringAsFixed(0);
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

    String? error = controller.checkValidation(amount, _categoryId, _currentType, '');
    if (error != null) {
      _showCompactNotification(error, Colors.orange);
      return;
    }

    setState(() => _isSaving = true);
    await controller.createOrUpdateTransaction(TransactionModel(
      id: widget.editData?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount, type: _currentType, categoryId: _categoryId, date: _selectedDate, note: _noteInput.text,
    ));

    if (mounted) {
      setState(() { _isSaving = false; _isSuccess = true; _isNumpadVisible = false; });
      _showCompactNotification(widget.editData != null ? "Cập nhật thành công!" : "Lưu giao dịch thành công!", Colors.blue);
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) Navigator.pop(context);
    }
  }

  // --- ĐỊNH NGHĨA HÀM XÓA ĐỂ HẾT LỖI UNDEFINED ---
  void _handleDelete() async {
    if (widget.editData != null) {
      ref.read(transactionControllerProvider).deleteTransaction(widget.editData!.id);
      _showCompactNotification("Đã xóa giao dịch", Colors.red);
      Navigator.pop(context);
    }
  }

  Future<DateTime?> _showCustomDateTimePicker(BuildContext context, DateTime initialDate) async {
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
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Expanded(child: GestureDetector(onTap: () => setDialogState(() => isSelectingDate = true), child: Center(child: Text(DateFormat('dd/MM/yyyy').format(tempDate), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelectingDate ? Colors.blue : Colors.grey.shade400))))),
                            Container(width: 1, height: 24, color: Colors.grey.shade300),
                            Expanded(child: GestureDetector(onTap: () => setDialogState(() => isSelectingDate = false), child: Center(child: Text('${tempTime.hour.toString().padLeft(2, '0')}:${tempTime.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: !isSelectingDate ? Colors.blue : Colors.grey.shade400))))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 300,
                              child: isSelectingDate
                                  ? CalendarDatePicker(initialDate: tempDate, firstDate: DateTime(2000), lastDate: DateTime(2100), onDateChanged: (date) { setDialogState(() { tempDate = date; isSelectingDate = false; }); })
                                  : CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: DateTime(tempDate.year, tempDate.month, tempDate.day, tempTime.hour, tempTime.minute), use24hFormat: true, onDateTimeChanged: (DateTime newDateTime) { setDialogState(() => tempTime = TimeOfDay.fromDateTime(newDateTime)); }),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: OutlinedButton(onPressed: () { setDialogState(() { tempDate = DateTime.now(); tempTime = TimeOfDay.now(); }); }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Colors.blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text("Hôm nay", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))),
                                const SizedBox(width: 12),
                                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, DateTime(tempDate.year, tempDate.month, tempDate.day, tempTime.hour, tempTime.minute)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text("Xong", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(top: 45, left: 60, child: Container(width: 5, height: 20, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(5)))),
                  Positioned(top: 45, right: 60, child: Container(width: 5, height: 20, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(5)))),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.editData != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, centerTitle: false, titleSpacing: 0, title: Text(isEditing ? "Chi tiết giao dịch" : "Thêm giao dịch", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () { if (_isNumpadVisible) setState(() => _isNumpadVisible = false); FocusScope.of(context).unfocus(); },
              behavior: HitTestBehavior.opaque,
              child: ListView(
                physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(16),
                children: [
                  _buildToggleType(), const SizedBox(height: 20),
                  _buildAmountBox(), const SizedBox(height: 16),
                  _buildCategoryBox(), const SizedBox(height: 16),
                  _buildFrequentCategoryBox(), const SizedBox(height: 16),
                  _buildDateBox(), const SizedBox(height: 16),
                  _buildNoteBox(),
                ],
              ),
            ),
          ),
          if (_isNumpadVisible) _buildNumpad()
          else if (isEditing) _buildEditButtons()
          else _buildSaveButtonOnly(),
        ],
      ),
    );
  }

  Widget _buildToggleType() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade300)),
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? Colors.blue : Colors.transparent, borderRadius: BorderRadius.circular(26)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 15)),
        ),
      ),
    );
  }

  Widget _buildAmountBox() {
    return GestureDetector(
      onTap: () => setState(() => _isNumpadVisible = true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("Số tiền", style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text("${_getFormattedAmount()} đ", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _currentType == 'expense' ? const Color(0xFFEF4444) : const Color(0xFF10B981))),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBox() {
    bool hasValue = _selectedCategory != null;
    return Theme(
      data: Theme.of(context).copyWith(hoverColor: Colors.transparent, highlightColor: Colors.red.shade50, splashColor: Colors.transparent),
      child: InkWell(
        onTap: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryListScreen(transactionType: _currentType, selectedCategoryName: _selectedCategory?.name)));
          if (res != null) setState(() { _selectedCategory = res; _categoryId = res.name; });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(hasValue ? _selectedCategory!.icon : Icons.add_circle_outline, color: hasValue ? _selectedCategory!.color : Colors.red),
              const SizedBox(width: 16),
              Expanded(child: Text(hasValue ? _selectedCategory!.name : "Chọn hạng mục", style: TextStyle(fontSize: 16, color: hasValue ? Colors.black87 : Colors.red, fontWeight: FontWeight.w500))),
              const Text("Tất cả", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequentCategoryBox() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(hoverColor: Colors.transparent, highlightColor: Colors.blue.shade50, splashColor: Colors.transparent),
            child: InkWell(
              onTap: () => setState(() => _isFrequentExpanded = !_isFrequentExpanded),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Hay dùng", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)), Icon(_isFrequentExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.black54)]),
              ),
            ),
          ),
          if (_isFrequentExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF4F7FB)),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Wrap(
                  spacing: 12, runSpacing: 12,
                  children: _frequentCategories.map((cat) {
                    bool isCatSelected = _selectedCategory?.name == cat.name;
                    return GestureDetector(
                      onTap: () { setState(() { _selectedCategory = cat; _categoryId = cat.name; _isFrequentExpanded = false; }); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: isCatSelected ? Colors.blue.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: isCatSelected ? Colors.blue : Colors.transparent)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 16, color: cat.color),
                            const SizedBox(width: 6),
                            Text(cat.name, style: TextStyle(fontSize: 13, color: isCatSelected ? Colors.blue : Colors.black87, fontWeight: isCatSelected ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )
            )
          ]
        ],
      ),
    );
  }

  Widget _buildDateBox() {
    List<String> weekdays = ['Chủ Nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
    String weekday = weekdays[_selectedDate.weekday == 7 ? 0 : _selectedDate.weekday];
    return Theme(
      data: Theme.of(context).copyWith(hoverColor: Colors.transparent, highlightColor: Colors.blue.shade50, splashColor: Colors.transparent),
      child: InkWell(
        onTap: () async {
          final picked = await _showCustomDateTimePicker(context, _selectedDate);
          if (picked != null) setState(() => _selectedDate = picked);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.black54, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text("$weekday - ${DateFormat('dd/MM/yyyy').format(_selectedDate)}", style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500))),
              Text(DateFormat('HH:mm').format(_selectedDate), style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: TextField(controller: _noteInput, onTap: () => setState(() => _isNumpadVisible = false), decoration: const InputDecoration(icon: Icon(Icons.notes, color: Colors.black87), hintText: "Ghi chú...", hintStyle: TextStyle(color: Colors.black38), border: InputBorder.none), style: const TextStyle(color: Colors.black87, fontSize: 16)),
    );
  }

  Widget _buildSaveButtonOnly() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
      child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _handleSaveData, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Lưu giao dịch", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
    );
  }

  Widget _buildEditButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
      child: Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: _handleDelete, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: Colors.red, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Xóa", style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 16),
          Expanded(child: ElevatedButton(onPressed: _handleSaveData, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Lưu lại", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    final keys = ['7','8','9','Xóa','4','5','6','+','1','2','3','-','C','0','=','Xong'];
    return Container(color: Colors.white, child: GridView.count(crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.3, children: keys.map((k) => _buildKey(k)).toList()));
  }

  Widget _buildKey(String val) {
    bool isAction = val == 'C' || val == 'Xóa' || val == 'Xong' || val == '+' || val == '-' || val == '=';
    return Theme(
      data: Theme.of(context).copyWith(hoverColor: Colors.transparent, highlightColor: Colors.blue.shade50, splashColor: Colors.transparent),
      child: InkWell(
        onTap: () => _onNumpadTap(val),
        child: Container(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade100, width: 0.5)), child: Center(child: Text(val, style: TextStyle(fontSize: isAction ? 18 : 24, fontWeight: isAction ? FontWeight.bold : FontWeight.w500, color: val == 'Xong' ? Colors.blue : Colors.black87)))),
      ),
    );
  }
}