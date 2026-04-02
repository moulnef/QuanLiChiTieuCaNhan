import '../../domain/model/transaction_model.dart';
import '../remote/firestore_service.dart';

class TransactionRepository {
  final FirestoreService _firestoreService = FirestoreService();

  // 1. LẤY DANH SÁCH GIAO DỊCH (FUTURE)
  Future<List<TransactionModel>> getTransactions() async {
    return await _firestoreService.getTransactionsOnce();
  }

  // 2. LẤY DANH SÁCH GIAO DỊCH (STREAM)
  Stream<List<TransactionModel>> getTransactionsStream() {
    return _firestoreService.getTransactionsStream();
  }

  // 3. THÊM HOẶC CẬP NHẬT GIAO DỊCH
  Future<void> addTransaction(TransactionModel transaction) async {
    await _firestoreService.createOrUpdateTransaction(transaction);
  }

  // 4. XÓA GIAO DỊCH
  Future<void> deleteTransaction(String transactionId) async {
    await _firestoreService.deleteTransaction(transactionId);
  }
}
