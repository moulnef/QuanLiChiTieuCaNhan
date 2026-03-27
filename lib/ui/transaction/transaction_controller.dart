import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/model/transaction_model.dart';
import '../../data/repository/transaction_repository.dart';

class TransactionController extends ChangeNotifier {
  final TransactionRepository _repository = TransactionRepository();
  List<TransactionModel> transactions = [];


  Future<void> fetchAllTransactions() async {
    transactions = await _repository.getTransactions();
    notifyListeners();
  }


  String? checkValidation(double amount, String categoryId, String type, String? person) {
    if (amount <= 0) return "Số tiền không được để trống hoặc bằng 0.";
    if (categoryId.isEmpty) return "Hạng mục không được để trống.";
    if ((type == 'borrow' || type == 'lend') && (person == null || person.isEmpty)) {
      return "Người tham gia giao dịch không được để trống.";
    }
    return null; 
  }


  Future<void> createOrUpdateTransaction(TransactionModel tx) async {
    await _repository.addTransaction(tx);
    await fetchAllTransactions();
  }
}


final transactionControllerProvider = ChangeNotifierProvider<TransactionController>((ref) {
  return TransactionController();
});