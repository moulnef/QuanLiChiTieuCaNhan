import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitType { equal, custom }

class SplitExpense {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String paidByUid;
  final String createdByUid;
  final DateTime createdAt;
  final SplitType splitType;
  final Map<String, double> shares; // uid -> double

  SplitExpense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidByUid,
    required this.createdByUid,
    required this.splitType,
    required this.shares,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'paidByUid': paidByUid,
      'createdByUid': createdByUid,
      'splitType': splitType.name,
      'shares': shares,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SplitExpense.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawShares = map['shares'];
    final Map<String, double> parsedShares = {};
    if (rawShares is Map) {
      rawShares.forEach((key, val) {
        parsedShares[key.toString()] = (val as num).toDouble();
      });
    }

    DateTime parseTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return SplitExpense(
      id: docId ?? map['id']?.toString() ?? '',
      groupId: map['groupId']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidByUid: map['paidByUid']?.toString() ?? map['paidBy']?.toString() ?? '',
      createdByUid: map['createdByUid']?.toString() ?? '',
      splitType: map['splitType']?.toString() == 'custom'
          ? SplitType.custom
          : SplitType.equal,
      shares: parsedShares,
      createdAt: parseTime(map['createdAt']),
    );
  }
}
