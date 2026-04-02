import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart'; // Thêm thư viện này
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

  // --- HÀM VẼ THÔNG BÁO NHỎ GỌN TRÊN TOPBAR ---
  void _showTopNotification(String message, Color bgColor, IconData icon) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7, // Bằng 2/3 màn hình
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(30), // Bo tròn mềm mại
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
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (title.isEmpty || amount == null) {
      // Thông báo cảnh báo màu cam
      _showTopNotification("Vui lòng nhập tên và số tiền hợp lệ", Colors.orange, Icons.warning_amber_rounded);
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
        // --- THÔNG BÁO THÀNH CÔNG: XANH LÁ + DẤU TICK ---
        _showTopNotification("Đã lưu chi tiêu thành công!", const Color(0xFF10B981), Icons.check_circle_outline);

        // Đợi 800 mili-giây cho người dùng kịp nhìn thông báo rồi mới thoát trang
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        // Thông báo lỗi màu đỏ
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
      backgroundColor: const Color(0xFFF4F7FB), // Thêm nền xám nhạt cho đồng bộ thiết kế
      appBar: AppBar(
        title: const Text("Thêm chi tiêu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: "Nội dung chi tiêu (VD: Ăn phở)", border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: "Số tiền (VNĐ)", border: InputBorder.none),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                  decoration: const InputDecoration(labelText: "Danh mục", border: InputBorder.none),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: "Ghi chú (không bắt buộc)", border: InputBorder.none),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Bo góc nút
                    elevation: 0,
                  ),
                  child: const Text("LƯU CHI TIÊU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}