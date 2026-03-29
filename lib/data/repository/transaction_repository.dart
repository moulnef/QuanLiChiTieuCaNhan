import '../../domain/model/transaction_model.dart';
import '../remote/firestore_service.dart';

class TransactionRepository {
  final FirestoreService _firestoreService = FirestoreService();

  // 1. LẤY DANH SÁCH GIAO DỊCH
  Future<List<TransactionModel>> getTransactions() async {
    // Không dùng .first nữa vì _firestoreService.getTransactions()
    // giờ đã trả về thẳng Future<List<TransactionModel>> rồi
    return await _firestoreService.getTransactions();
  }

  // 2. THÊM HOẶC CẬP NHẬT GIAO DỊCH
  Future<void> addTransaction(TransactionModel transaction) async {
    await _firestoreService.createOrUpdateTransaction(transaction);
  }

  // 3. XÓA GIAO DỊCH
  Future<void> deleteTransaction(String transactionId) async {
    await _firestoreService.deleteTransaction(transactionId);
  }
}