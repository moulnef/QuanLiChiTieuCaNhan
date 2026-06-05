enum SplitType { equal, custom }

class SplitExpense {
  final String id;
  final String description;
  final double amount;
  final String paidBy; // memberId
  final SplitType splitType;
  final Map<String, double> shares; // memberId -> double
  final DateTime createdAt;

  SplitExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.splitType,
    required this.shares,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'splitType': splitType.name,
      'shares': shares,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SplitExpense.fromMap(Map<String, dynamic> map) {
    final rawShares = map['shares'];
    final Map<String, double> parsedShares = {};
    if (rawShares is Map) {
      rawShares.forEach((key, val) {
        parsedShares[key.toString()] = (val as num).toDouble();
      });
    }

    return SplitExpense(
      id: map['id']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidBy: map['paidBy']?.toString() ?? '',
      splitType: map['splitType']?.toString() == 'custom'
          ? SplitType.custom
          : SplitType.equal,
      shares: parsedShares,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }
}
