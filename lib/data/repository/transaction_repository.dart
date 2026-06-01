import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';

class TransactionRepository {
  final FinanceRepository _financeRepository;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  TransactionRepository([FinanceRepository? repository])
      : _financeRepository = repository ?? FinanceRepository();

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

  Stream<List<TransactionModel>> streamTransactions([String? requestedUserId]) {
    final userId = _resolveUserId(requestedUserId);
    return _financeRepository.streamTransactions(userId);
  }

  Future<List<TransactionModel>> getTransactions([String? requestedUserId]) {
    final userId = _resolveUserId(requestedUserId);
    return _financeRepository.getAllTransactionsByUserId(userId);
  }

  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime start,
    DateTime end, [
    String? requestedUserId,
  ]) {
    final userId = _resolveUserId(requestedUserId);
    return _financeRepository.getTransactionsByDateRange(userId, start, end);
  }

  Future<Map<String, double>> getMonthlyStats(
    int month,
    int year, [
    String? requestedUserId,
  ]) {
    final userId = _resolveUserId(requestedUserId);
    return _financeRepository.getMonthlyStats(userId, month, year);
  }

  Future<List<Map<String, dynamic>>> getCategoryStats(
    int month,
    int year, [
    String? requestedUserId,
  ]) {
    final userId = _resolveUserId(requestedUserId);
    return _financeRepository.getCategoryStats(userId, month, year);
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

  Future<void> syncOfflineData([String? requestedUserId]) async {
    final userId = _resolveUserId(requestedUserId);
    await _financeRepository.syncWithFirebase(userId);
  }
}
