import 'package:cloud_firestore/cloud_firestore.dart';

class SplitPayment {
  final String id;
  final String groupId;
  final String fromUid;
  final String toUid;
  final double amount;
  final DateTime paidAt;
  final String? confirmedByToUid;

  SplitPayment({
    required this.id,
    required this.groupId,
    required this.fromUid,
    required this.toUid,
    required this.amount,
    required this.paidAt,
    this.confirmedByToUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'fromUid': fromUid,
      'toUid': toUid,
      'amount': amount,
      'paidAt': Timestamp.fromDate(paidAt),
      'confirmedByToUid': confirmedByToUid,
    };
  }

  factory SplitPayment.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return SplitPayment(
      id: docId ?? map['id']?.toString() ?? '',
      groupId: map['groupId']?.toString() ?? '',
      fromUid: map['fromUid']?.toString() ?? '',
      toUid: map['toUid']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidAt: parseTime(map['paidAt']),
      confirmedByToUid: map['confirmedByToUid']?.toString(),
    );
  }
}
