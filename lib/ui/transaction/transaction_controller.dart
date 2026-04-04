import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 💡 ĐÃ SỬA: Chỉ cần import gói chính này

// Đảm bảo đường dẫn import đúng với cấu trúc dự án của bạn
import '../../domain/model/transaction_model.dart';
import '../../data/repository/transaction_repository.dart';

class TransactionController extends ChangeNotifier {
  final TransactionRepository _repository = TransactionRepository();
  List<TransactionModel> transactions = [];

  // 1. LẤY DANH SÁCH GIAO DỊCH
  Future<void> fetchAllTransactions() async {
    try {
      transactions = await _repository.getTransactions();
      notifyListeners(); // Thông báo cho UI cập nhật lại danh sách
    } catch (e) {
      debugPrint("Lỗi khi lấy danh sách: $e");
    }
  }

  // 2. KIỂM TRA TÍNH HỢP LỆ (Validation)
  String? checkValidation(
      double amount,
      String categoryId,
      String type,
      String? person,
      ) {
    if (amount <= 0) return "Số tiền không được để trống hoặc bằng 0.";
    if (categoryId.isEmpty) return "Hạng mục không được để trống.";
    if ((type == 'borrow' || type == 'lend') &&
        (person == null || person.isEmpty)) {
      return "Người tham gia giao dịch không được để trống.";
    }
    return null;
  }

  // 3. THÊM HOẶC CẬP NHẬT GIAO DỊCH
  Future<void> createOrUpdateTransaction(TransactionModel tx) async {
    try {
      await _repository.addTransaction(tx);
      await fetchAllTransactions(); // Cập nhật lại dữ liệu mới nhất
    } catch (e) {
      debugPrint("Lỗi khi lưu giao dịch: $e");
      rethrow;
    }
  }

  // 4. XÓA GIAO DỊCH
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _repository.deleteTransaction(transactionId);
      await fetchAllTransactions();
    } catch (e) {
      debugPrint("Lỗi khi xóa giao dịch: $e");
      rethrow;
    }
  }
}

// 💡 ĐÃ VÁ: Khai báo Provider sử dụng gói flutter_riverpod chuẩn
final transactionControllerProvider =
ChangeNotifierProvider<TransactionController>((ref) {
  return TransactionController();
});