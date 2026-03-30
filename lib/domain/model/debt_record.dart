class DebtRecord {
  final String id;
  final String userId;
  final String title;
  final String lenderName;
  final int totalAmount;
  final int paidAmount;
  final int monthlyPayment;
  final double interestRate;
  final int nextDueDate;
  final int createdAt;
  final int updatedAt;
  final String status;

  const DebtRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.lenderName,
    required this.totalAmount,
    required this.paidAmount,
    required this.monthlyPayment,
    required this.interestRate,
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

  DebtRecord copyWith({
    String? id,
    String? userId,
    String? title,
    String? lenderName,
    int? totalAmount,
    int? paidAmount,
    int? monthlyPayment,
    double? interestRate,
    int? nextDueDate,
    int? createdAt,
    int? updatedAt,
    String? status,
  }) {
    return DebtRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      lenderName: lenderName ?? this.lenderName,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      interestRate: interestRate ?? this.interestRate,
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
      'lenderName': lenderName,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'monthlyPayment': monthlyPayment,
      'interestRate': interestRate,
      'nextDueDate': nextDueDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'status': status,
    };
  }

  factory DebtRecord.fromMap(Map<String, dynamic> map) {
    return DebtRecord(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      lenderName: map['lenderName'],
      totalAmount: map['totalAmount'],
      paidAmount: map['paidAmount'],
      monthlyPayment: map['monthlyPayment'],
      interestRate: (map['interestRate'] as num).toDouble(),
      nextDueDate: map['nextDueDate'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      status: map['status'],
    );
  }
}