import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  final String id;
  final String userId;
  final String categoryId;
  final String categoryName;
  final String icon;
  final int month;
  final int year;
  final double limitAmount;
  final double spentAmount;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String status;

  Budget({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.month,
    required this.year,
    required num limitAmount,
    required num spentAmount,
    this.currency = 'VND',
    required dynamic createdAt,
    required dynamic updatedAt,
    this.isActive = true,
    required this.status,
  }) : limitAmount = limitAmount.toDouble(),
       spentAmount = spentAmount.toDouble(),
       createdAt = _parseDate(createdAt),
       updatedAt = _parseDate(updatedAt);

  double get remainingAmount {
    final value = limitAmount - spentAmount;
    return value < 0 ? 0.0 : value;
  }

  int get progressPercent {
    if (limitAmount <= 0) return 0;
    return ((spentAmount * 100) / limitAmount).floor();
  }

  Budget copyWith({
    String? id,
    String? userId,
    String? categoryId,
    String? categoryName,
    String? icon,
    int? month,
    int? year,
    double? limitAmount,
    double? spentAmount,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? status,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      icon: icon ?? this.icon,
      month: month ?? this.month,
      year: year ?? this.year,
      limitAmount: limitAmount ?? this.limitAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'icon': icon,
      'month': month,
      'year': year,
      'limitAmount': limitAmount,
      'spentAmount': spentAmount,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'status': status,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'userId': userId,
      'user_id': userId,
      'categoryId': categoryId,
      'category_id': categoryId,
      'categoryName': categoryName,
      'category_name': categoryName,
      'icon': icon,
      'month': month,
      'year': year,
      'limitAmount': limitAmount.round(),
      'limit_amount': limitAmount.round(),
      'spentAmount': spentAmount.round(),
      'spent_amount': spentAmount.round(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'status': status,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map, [String? docId]) {
    return Budget(
      id: docId ?? map['id'] ?? '',
      userId: map['userId'] ?? map['user_id'] ?? '',
      categoryId: map['categoryId'] ?? map['category_id'] ?? '',
      categoryName: map['categoryName'] ?? map['category_name'] ?? '',
      icon: map['icon'] ?? '',
      month: map['month'] ?? 1,
      year: map['year'] ?? DateTime.now().year,
      limitAmount: (map['limitAmount'] ?? map['limit_amount'] ?? 0).toDouble(),
      spentAmount: (map['spentAmount'] ?? map['spent_amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'VND',
      createdAt: map['createdAt'] ?? map['created_at'],
      updatedAt: map['updatedAt'] ?? map['updated_at'],
      isActive: map['isActive'] ?? true,
      status: map['status'] ?? 'active',
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
