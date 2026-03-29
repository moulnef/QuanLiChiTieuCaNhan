import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final double amount;
  final String type; // 'expense' hoặc 'income'
  final String categoryId; // Tên danh mục (vd: 'Ăn sáng')
  final DateTime date;
  final String note;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.date,
    this.note = '',
  });

  // Đóng gói dữ liệu để đẩy lên Firebase
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'date': Timestamp.fromDate(date), // Firebase dùng kiểu Timestamp thay vì DateTime
      'note': note,
    };
  }

  // Giải mã dữ liệu từ Firebase tải về
  factory TransactionModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TransactionModel(
      id: documentId,
      amount: (map['amount'] ?? 0).toDouble(),
      type: map['type'] ?? 'expense',
      categoryId: map['categoryId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'] ?? '',
    );
  }
}