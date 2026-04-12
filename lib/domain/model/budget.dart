class Budget {
  final String id;
  final String userId;
  final String categoryId;
  final String categoryName;
  final String icon;
  final int month;
  final int year;
  final int limitAmount;
  final int spentAmount;
  final int createdAt;
  final int updatedAt;
  final String status;

  const Budget({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.month,
    required this.year,
    required this.limitAmount,
    required this.spentAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  int get remainingAmount {
    final value = limitAmount - spentAmount;
    return value < 0 ? 0 : value;
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
    int? limitAmount,
    int? spentAmount,
    int? createdAt,
    int? updatedAt,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'status': status,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      userId: map['userId'],
      categoryId: map['categoryId'],
      categoryName: map['categoryName'],
      icon: map['icon'],
      month: map['month'],
      year: map['year'],
      limitAmount: map['limitAmount'],
      spentAmount: map['spentAmount'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      status: map['status'],
    );
  }
}