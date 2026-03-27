import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'transaction_controller.dart'; 
import '../../domain/model/transaction_model.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF0077F6);
  static const Color expenseRed = Colors.redAccent;
  static const Color incomeGreen = Colors.green;
  static const Color backgroundGray = Color(0xFFF4F6F8);
  
  static const TextStyle normalText = TextStyle(fontSize: 16, color: Colors.black87);
  static const TextStyle headerAmount = TextStyle(fontSize: 40, fontWeight: FontWeight.w700);
  static const TextStyle placeholderText = TextStyle(fontSize: 14, color: Colors.black38);
}

class CreateTransactionPage extends ConsumerStatefulWidget {
  final TransactionModel? editData; 
  const CreateTransactionPage({super.key, this.editData});

  @override
  ConsumerState<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends ConsumerState<CreateTransactionPage> {
  final _amountInput = TextEditingController();
  final _noteInput = TextEditingController();
  final _personInput = TextEditingController();
  final _feeInput = TextEditingController();

  String _currentType = 'expense';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _categoryId = ''; 
  String _walletId = 'default_wallet';
  bool _isFeeEnabled = false;
  bool _excludeFromReport = false;

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      final tx = widget.editData!;
      _amountInput.text = tx.amount.toString();
      _noteInput.text = tx.note;
      _currentType = tx.type;
      _categoryId = tx.categoryId;
      _walletId = tx.walletId;
      _selectedDate = tx.date;
      _selectedTime = TimeOfDay.fromDateTime(tx.date);
      _personInput.text = tx.person ?? '';
    }
  }

  void _handleSaveData() async {
    final controller = ref.read(transactionControllerProvider);
    double amount = double.tryParse(_amountInput.text) ?? 0;

    String? errorMessage = controller.checkValidation(amount, _categoryId, _currentType, _personInput.text);
    if (errorMessage != null) {
      showTopSnackBar(Overlay.of(context), CustomSnackBar.info(message: errorMessage, backgroundColor: Colors.orange));
      return;
    }

    final finalDateTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );

    final transactionRecord = TransactionModel(
      id: widget.editData?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount, 
      type: _currentType,
      categoryId: _categoryId.isEmpty ? "default_category" : _categoryId,
      walletId: _walletId, 
      date: finalDateTime, 
      note: _noteInput.text, 
      person: _personInput.text,
    );

    await controller.createOrUpdateTransaction(transactionRecord);
    if (mounted) {
      showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: "Lưu thành công"));
      Future.delayed(const Duration(milliseconds: 500), () => Navigator.pop(context));
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  final Map<String, String> _transactionTypes = {
    'expense': "Chi tiền", 'income': "Thu tiền", 'transfer': "Chuyển khoản",
    'borrow': "Đi vay", 'lend': "Cho vay",
  };

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');
    final formattedDate = formatter.format(_selectedDate);
    final formattedTime = "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";
    Color amountColor = (_currentType == 'income' || _currentType == 'lend') ? AppTheme.incomeGreen : AppTheme.expenseRed;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        title: DropdownButton<String>(
          value: _currentType,
          items: _transactionTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.black)))).toList(),
          onChanged: (val) {
            setState(() { _currentType = val!; _personInput.clear(); _categoryId = ''; });
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.check, color: Colors.green, size: 30), onPressed: _handleSaveData),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    controller: _amountInput, keyboardType: TextInputType.number,
                    style: AppTheme.headerAmount.copyWith(color: amountColor),
                    decoration: const InputDecoration(hintText: "0 đ", suffixText: " đ", border: InputBorder.none, hintStyle: AppTheme.placeholderText),
                  ),
                  const Divider(),
                  TextField(
                    controller: _noteInput,
                    decoration: const InputDecoration(hintText: "Ghi chú...", border: InputBorder.none, hintStyle: AppTheme.placeholderText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.category, color: Colors.blue),
                    title: Text(_categoryId.isEmpty ? "Chọn nhóm" : "Nhóm", style: AppTheme.normalText),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (_categoryId.isNotEmpty) Text(_categoryId), const Icon(Icons.arrow_forward_ios, size: 16)]),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                    title: Text(_walletId == 'default_wallet' ? "Chọn nguồn tiền" : "Nguồn tiền", style: AppTheme.normalText),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (_walletId != 'default_wallet') Text(_walletId), const Icon(Icons.arrow_forward_ios, size: 16)]),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.grey),
                    title: Row(children: [Text(formattedDate), const SizedBox(width: 10), Text(formattedTime)]),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () { _pickDate().then((_) => _pickTime()); },
                  ),
                  const Divider(height: 1),
                  if (_currentType == 'borrow' || _currentType == 'lend')
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.purple),
                      title: TextField(
                        controller: _personInput,
                        decoration: InputDecoration(hintText: "Đối tác giao dịch", labelStyle: TextStyle(color: _personInput.text.isEmpty ? Colors.red : Colors.black), border: InputBorder.none, hintStyle: AppTheme.placeholderText),
                      ),
                      trailing: const Icon(Icons.contacts, size: 20, color: Colors.grey),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  SwitchListTile(title: const Text("Thêm phí giao dịch", style: AppTheme.normalText), value: _isFeeEnabled, onChanged: (val) => setState(() => _isFeeEnabled = val)),
                  if (_isFeeEnabled)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: _feeInput, decoration: const InputDecoration(hintText: "Nhập số tiền"), keyboardType: TextInputType.number)),
                  const Divider(height: 1),
                  SwitchListTile(title: const Text("Loại trừ khỏi báo cáo", style: AppTheme.normalText), value: _excludeFromReport, onChanged: (val) => setState(() => _excludeFromReport = val)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}