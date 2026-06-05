import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/transaction_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/services/notification_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/services/sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionController extends ChangeNotifier {
  final TransactionRepository _repository = TransactionRepository();
  List<TransactionModel> transactions = [];

  String? _resolveUserId() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      return null;
    }
    return currentUid;
  }

  Future<void> fetchAllTransactions([String? userId]) async {
    try {
      final effectiveUserId = userId ?? _resolveUserId();
      if (effectiveUserId == null) {
        transactions = [];
        notifyListeners();
        return;
      }

      transactions = await _repository.getTransactions(effectiveUserId);
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi khi lấy danh sách giao dịch: $e');
    }
  }

  String? checkValidation(
    double amount,
    String categoryId,
    String type,
    String? person,
  ) {
    if (amount <= 0) {
      return 'Số tiền không được để trống hoặc bằng 0.';
    }
    if (categoryId.isEmpty) {
      return 'Hạng mục không được để trống.';
    }
    if ((type == 'borrow' || type == 'lend') &&
        (person == null || person.isEmpty)) {
      return 'Người tham gia giao dịch không được để trống.';
    }
    return null;
  }

  Future<void> createOrUpdateTransaction(TransactionModel tx) async {
    try {
      final effectiveUserId = _resolveUserId();
      if (effectiveUserId == null) {
        throw StateError('Người dùng chưa đăng nhập.');
      }

      final now = DateTime.now();
      final normalizedTx = tx.copyWith(
        id: tx.id.isNotEmpty ? tx.id : now.millisecondsSinceEpoch.toString(),
        userId: effectiveUserId,
        updatedAt: now,
      );
      await _repository.addTransaction(normalizedTx, effectiveUserId);
      await NotificationService.instance.notifyTransactionRecorded(
        effectiveUserId,
        normalizedTx,
      );
      SyncService().triggerImmediateSync();
      await fetchAllTransactions(effectiveUserId);
    } catch (e) {
      debugPrint('Lỗi khi lưu giao dịch: $e');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      final effectiveUserId = _resolveUserId();
      if (effectiveUserId == null) {
        throw StateError('Người dùng chưa đăng nhập.');
      }

      await _repository.deleteTransaction(transactionId, effectiveUserId);
      SyncService().triggerImmediateSync();
      await fetchAllTransactions(effectiveUserId);
    } catch (e) {
      debugPrint('Lỗi khi xóa giao dịch: $e');
      rethrow;
    }
  }
}

final transactionControllerProvider =
    ChangeNotifierProvider<TransactionController>((ref) {
      return TransactionController();
    });
