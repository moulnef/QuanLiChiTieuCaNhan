import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String walletId;
  final String categoryId;
  final String categoryName;
  final String type; // 'income' | 'expense' | 'transfer'
  final double amount;
  final String note;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String? receiptImageUrl;
  final List<String>? tags;
  final String? recurringId;

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
    this.isDeleted = false,
    this.receiptImageUrl,
    this.tags,
    this.recurringId,
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
      'date': Timestamp.fromDate(transactionDate),
      'transactionDate': Timestamp.fromDate(transactionDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'receiptImageUrl': receiptImageUrl,
      'tags': tags,
      'recurringId': recurringId,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, [String? documentId]) {
    final rawTags = map['tags'];
    List<String>? parsedTags;
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }

    return TransactionModel(
      id: documentId ?? map['id'] ?? '',
      userId: map['userId'] ?? map['user_id'] ?? '',
      walletId: map['walletId'] ?? map['wallet_id'] ?? '',
      categoryId: map['categoryId'] ?? map['category_id'] ?? '',
      categoryName: map['categoryName'] ?? map['category_name'] ?? '',
      type: map['type'] ?? 'expense',
      amount: (map['amount'] ?? 0).toDouble(),
      note: map['note'] ?? '',
      transactionDate: _parseDate(map['date'] ?? map['transactionDate'] ?? map['transaction_date']),
      createdAt: _parseDate(map['createdAt'] ?? map['created_at'] ?? map['date'] ?? map['transactionDate']),
      updatedAt: _parseDate(map['updatedAt'] ?? map['updated_at'] ?? map['date'] ?? map['transactionDate']),
      isDeleted: map['isDeleted'] ?? false,
      receiptImageUrl: map['receiptImageUrl'],
      tags: parsedTags,
      recurringId: map['recurringId'],
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
    bool? isDeleted,
    String? receiptImageUrl,
    List<String>? tags,
    String? recurringId,
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
      isDeleted: isDeleted ?? this.isDeleted,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      tags: tags ?? this.tags,
      recurringId: recurringId ?? this.recurringId,
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