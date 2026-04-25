import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart'
    hide TransactionRepository;

class TransactionRepository {
  final FinanceRepository _financeRepository = FinanceRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  String _resolveUserId([String? userId]) {
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }
    return _userId ?? FinanceRepository.demoUserId;
  }

  Stream<void> watchTransactions([String? userId]) {
    final effectiveUserId = _resolveUserId(userId);
    return _financeRepository.watchTransactions(effectiveUserId);
  }

  Future<List<TransactionModel>> getTransactions([String? requestedUserId]) {
    final userId = _resolveUserId(requestedUserId);
    return _financeRepository.getAllTransactionsByUserId(userId);
  }

  Future<void> addTransaction(
    TransactionModel tx, [
    String? requestedUserId,
  ]) async {
    final userId = _resolveUserId(
      tx.userId.isNotEmpty ? tx.userId : requestedUserId,
    );
    final now = DateTime.now();
    final normalized = tx.copyWith(
      id: tx.id.isNotEmpty ? tx.id : now.millisecondsSinceEpoch.toString(),
      userId: userId,
      updatedAt: now,
    );

    await _financeRepository.upsertTransaction(normalized);
  }

  Future<void> deleteTransaction(String id, [String? requestedUserId]) async {
    final userId = _resolveUserId(requestedUserId);
    if (id.isEmpty) return;

    await _financeRepository.deleteTransaction(userId, id);
  }
}
