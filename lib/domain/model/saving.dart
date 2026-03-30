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
    };
  }

  factory SavingGoal.fromMap(Map<String, dynamic> map) {
    return SavingGoal(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      icon: map['icon'],
      currentAmount: map['currentAmount'],
      targetAmount: map['targetAmount'],
      targetDate: map['targetDate'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      status: map['status'],
    );
  }
}