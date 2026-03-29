import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/model/transaction_model.dart';
import '../../data/repository/transaction_repository.dart';
import 'package:flutter_riverpod/legacy.dart';

class TransactionController extends ChangeNotifier {
  final TransactionRepository _repository = TransactionRepository();
  List<TransactionModel> transactions = [];

  // 1. LẤY DANH SÁCH GIAO DỊCH
  Future<void> fetchAllTransactions() async {
    transactions = await _repository.getTransactions();
    notifyListeners(); // Thông báo cho UI cập nhật lại danh sách
  }

  // 2. KIỂM TRA TÍNH HỢP LỆ (Validation)
  String? checkValidation(double amount, String categoryId, String type, String? person) {
    if (amount <= 0) return "Số tiền không được để trống hoặc bằng 0.";
    if (categoryId.isEmpty) return "Hạng mục không được để trống.";
    if ((type == 'borrow' || type == 'lend') && (person == null || person.isEmpty)) {
      return "Người tham gia giao dịch không được để trống.";
    }
    return null;
  }

  // 3. THÊM HOẶC CẬP NHẬT GIAO DỊCH
  Future<void> createOrUpdateTransaction(TransactionModel tx) async {
    try {
      await _repository.addTransaction(tx);
      await fetchAllTransactions(); // Gọi lại hàm fetch để UI có dữ liệu mới nhất
    } catch (e) {
      debugPrint("Lỗi khi lưu giao dịch: $e");
      rethrow;
    }
  }

  // 4. BỔ SUNG: XÓA GIAO DỊCH
  Future<void> deleteTransaction(String transactionId) async {
    try {
      // Đảm bảo trong TransactionRepository của bạn đã có hàm deleteTransaction(id) nhé
      await _repository.deleteTransaction(transactionId);
      await fetchAllTransactions(); // Gọi lại hàm fetch để xóa item đó khỏi UI
    } catch (e) {
      debugPrint("Lỗi khi xóa giao dịch: $e");
      rethrow;
    }
  }
}

// Provider cung cấp Controller cho toàn bộ App
final transactionControllerProvider = ChangeNotifierProvider<TransactionController>((ref) {
  return TransactionController();
});