class InstallmentPlan {
  final String id;
  final String userId;
  final String title;
  final String icon;
  final int totalAmount;
  final int paidAmount;
  final int monthlyPayment;
  final int paidPeriods;
  final int totalPeriods;
  final int nextDueDate;
  final int createdAt;
  final int updatedAt;
  final String status;

  const InstallmentPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.icon,
    required this.totalAmount,
    required this.paidAmount,
    required this.monthlyPayment,
    required this.paidPeriods,
    required this.totalPeriods,
    required this.nextDueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  int get remainingAmount {
    final value = totalAmount - paidAmount;
    return value < 0 ? 0 : value;
  }

  int get progressPercent {
    if (totalAmount <= 0) return 0;
    return ((paidAmount * 100) / totalAmount).floor();
  }

  int get daysLeft {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = nextDueDate - now;
    return (diff / (1000 * 60 * 60 * 24)).floor();
  }

  InstallmentPlan copyWith({
    String? id,
    String? userId,
    String? title,
    String? icon,
    int? totalAmount,
    int? paidAmount,
    int? monthlyPayment,
    int? paidPeriods,
    int? totalPeriods,
    int? nextDueDate,
    int? createdAt,
    int? updatedAt,
    String? status,
  }) {
    return InstallmentPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      paidPeriods: paidPeriods ?? this.paidPeriods,
      totalPeriods: totalPeriods ?? this.totalPeriods,
      nextDueDate: nextDueDate ?? this.nextDueDate,
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
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'monthlyPayment': monthlyPayment,
      'paidPeriods': paidPeriods,
      'totalPeriods': totalPeriods,
      'nextDueDate': nextDueDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'status': status,
    };
  }

  factory InstallmentPlan.fromMap(Map<String, dynamic> map) {
    return InstallmentPlan(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      icon: map['icon'],
      totalAmount: map['totalAmount'],
      paidAmount: map['paidAmount'],
      monthlyPayment: map['monthlyPayment'],
      paidPeriods: map['paidPeriods'],
      totalPeriods: map['totalPeriods'],
      nextDueDate: map['nextDueDate'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      status: map['status'],
    );
  }
}