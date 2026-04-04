import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/remote/firestore_service.dart';
import '../providers/budget_provider.dart';

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

  String? _selectedCategoryId;
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();
    // Khởi tạo giá trị mặc định từ provider ở frame đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final budgets = context.read<BudgetProvider>().budgets;
      if (budgets.isNotEmpty) {
        setState(() {
          _selectedCategoryId = budgets.first.categoryId;
          _selectedCategoryName = budgets.first.categoryName;
        });
      }
    });
  }

  Future<void> _saveTransaction() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (title.isEmpty || amount == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin và chọn danh mục")),
      );
      return;
    }

    try {
      await _firestoreService.addTransaction(
        title: title,
        amount: amount,
        category: _selectedCategoryName!,
        categoryId: _selectedCategoryId!,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi lưu: $e")),
        );
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
      body: Consumer<BudgetProvider>(
        builder: (context, budgetProvider, child) {
          final budgets = budgetProvider.budgets;

          return Padding(
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
                  
                  // Dropdown lấy dữ liệu từ BudgetProvider
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    hint: const Text("Chọn danh mục"),
                    items: budgets.map((b) {
                      return DropdownMenuItem(
                        value: b.categoryId,
                        child: Text("${b.icon} ${b.categoryName}"),
                      );
                    }).toList(),
                    onChanged: (val) {
                      final selectedBudget = budgets.firstWhere((b) => b.categoryId == val);
                      setState(() {
                        _selectedCategoryId = val;
                        _selectedCategoryName = selectedBudget.categoryName;
                      });
                    },
                    decoration: const InputDecoration(labelText: "Danh mục ngân sách"),
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
          );
        },
      ),
    );
  }
}
