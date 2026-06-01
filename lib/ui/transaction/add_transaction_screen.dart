import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../data/remote/firestore_service.dart';
import '../../domain/model/transaction_model.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  String _selectedCategory = 'Ăn uống';
  final List<String> _categories = [
    'Ăn uống',
    'Di chuyển',
    'Mua sắm',
    'Giải trí',
    'Hóa đơn',
    'Khác',
  ];

  bool _isSaving = false;

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
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
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
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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

  Future<void> _saveTransaction() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (title.isEmpty || amount == null) {
      _showTopNotification("Vui lòng nhập tên và số tiền hợp lệ", Colors.orange, Icons.warning_amber_rounded);
      return;
    }

    setState(() => _isSaving = true);

    try {
      String categoryId = 'e46';
      if (_selectedCategory == 'Ăn uống') {
        categoryId = 'e2';
      } else if (_selectedCategory == 'Di chuyển') categoryId = 'e14';
      else if (_selectedCategory == 'Mua sắm') categoryId = 'e38';
      else if (_selectedCategory == 'Giải trí') categoryId = 'e24';
      else if (_selectedCategory == 'Hóa đơn') categoryId = 'e8';

      final uId = _firestoreService.userId;

      final tx = TransactionModel(
        id: '',
        userId: uId,
        walletId: 'wallet_cash_$uId',
        categoryId: categoryId,
        categoryName: _selectedCategory,
        type: 'expense',
        amount: amount,
        note: _noteController.text.trim(),
        transactionDate: DateTime.now(),
      );

      await _firestoreService.addTransaction(tx);

      if (mounted) {
        _showTopNotification("Đã lưu chi tiêu thành công!", const Color(0xFF10B981), Icons.check_circle_outline);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showTopNotification("Lỗi khi lưu: $e", Colors.red, Icons.error_outline);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF), // Galaxy Nhạt
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("Thêm chi tiêu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white, letterSpacing: 0.5)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildInputBox(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: "Nội dung chi tiêu (VD: Ăn phở)", border: InputBorder.none, labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              _buildInputBox(
                child: TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: "Số tiền (VNĐ)", border: InputBorder.none, labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
              _buildInputBox(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w500)))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                  decoration: const InputDecoration(labelText: "Danh mục", border: InputBorder.none, labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                ),
              ),
              const SizedBox(height: 16),
              _buildInputBox(
                child: TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: "Ghi chú thêm (không bắt buộc)", border: InputBorder.none, labelStyle: TextStyle(color: Color(0xFF94A3B8))),
                  style: const TextStyle(color: Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(height: 36),
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0xFF6D28D9).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]
                ),
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("LƯU CHI TIÊU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: child,
    );
  }
}