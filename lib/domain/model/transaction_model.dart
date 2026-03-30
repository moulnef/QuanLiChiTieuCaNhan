import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String walletId;
  final String categoryId;
  final String categoryName;
  final String type;
  final double amount;
  final String note;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    this.id = '',
    this.userId = '',
    this.walletId = '',
    required this.categoryId,
    this.categoryName = '',
    required this.type,
    required this.amount,
    this.note = '',
    required this.transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? transactionDate,
        updatedAt = updatedAt ?? transactionDate;

  DateTime get date => transactionDate;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'walletId': walletId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'type': type,
      'amount': amount,
      'note': note,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, [String? documentId]) {
    return TransactionModel(
      id: documentId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      walletId: map['walletId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      type: map['type'] ?? 'expense',
      amount: (map['amount'] ?? 0).toDouble(),
      note: map['note'] ?? '',
      transactionDate: _parseDate(map['transactionDate'] ?? map['date']),
      createdAt: _parseDate(map['createdAt'] ?? map['transactionDate'] ?? map['date']),
      updatedAt: _parseDate(map['updatedAt'] ?? map['transactionDate'] ?? map['date']),
    );
  }

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? walletId,
    String? categoryId,
    String? categoryName,
    String? type,
    double? amount,
    String? note,
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}