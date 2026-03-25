import 'package:flutter/material.dart';
import '../../data/remote/firestore_service.dart';

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

  Future<void> _saveTransaction() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (title.isEmpty || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập tên và số tiền hợp lệ")),
      );
      return;
    }

    try {
      await _firestoreService.addTransaction(
        title: title,
        amount: amount,
        category: _selectedCategory,
        date: DateTime.now(),
        note: _noteController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã lưu chi tiêu thành công!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Lỗi khi lưu: $e")));
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
      appBar: AppBar(title: const Text("Thêm chi tiêu")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Nội dung chi tiêu (VD: Ăn phở)",
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Số tiền (VNĐ)"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories
                    .map(
                      (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
                decoration: const InputDecoration(labelText: "Danh mục"),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: "Ghi chú (không bắt buộc)",
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("LƯU CHI TIÊU"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
