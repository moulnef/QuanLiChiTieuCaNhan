class SavingGoal {
  final String id;
  final String userId;
  final String title;
  final String icon;
  final int currentAmount;
  final int targetAmount;
  final int targetDate;
  final int createdAt;
  final int updatedAt;
  final String status;
  final int? colorValue;

  const SavingGoal({
    required this.id,
    required this.userId,
    required this.title,
    required this.icon,
    required this.currentAmount,
    required this.targetAmount,
    required this.targetDate,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.colorValue,
  });

  int get remainingAmount {
    final value = targetAmount - currentAmount;
    return value < 0 ? 0 : value;
  }

  int get progressPercent {
    if (targetAmount <= 0) return 0;
    return ((currentAmount * 100) / targetAmount).floor();
  }

  int get daysLeft {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = targetDate - now;
    return (diff / (1000 * 60 * 60 * 24)).floor();
  }

  SavingGoal copyWith({
    String? id,
    String? userId,
    String? title,
    String? icon,
    int? currentAmount,
    int? targetAmount,
    int? targetDate,
    int? createdAt,
    int? updatedAt,
    String? status,
    int? colorValue,
  }) {
    return SavingGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'icon': icon,
      'currentAmount': currentAmount,
      'targetAmount': targetAmount,
      'targetDate': targetDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'status': status,
      'colorValue': colorValue,
      'color_value': colorValue,
    };
  }

  factory SavingGoal.fromMap(Map<String, dynamic> map) {
    return SavingGoal(
      id: map['id'] ?? '',
      userId: map['userId'] ?? map['user_id'] ?? '',
      title: map['title'] ?? '',
      icon: map['icon'] ?? '🎯',
      currentAmount: map['currentAmount'] ?? map['current_amount'] ?? 0,
      targetAmount: map['targetAmount'] ?? map['target_amount'] ?? 0,
      targetDate: map['targetDate'] ?? map['target_date'] ?? 0,
      createdAt: map['createdAt'] ?? map['created_at'] ?? 0,
      updatedAt: map['updatedAt'] ?? map['updated_at'] ?? 0,
      status: map['status'] ?? 'active',
      colorValue: map['colorValue'] ?? map['color_value'],
    );
  }
}