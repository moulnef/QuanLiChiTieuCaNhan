class TransactionEntity {
  final String id;
  final double amount;
  final String type;
  final String categoryId;
  final String walletId;
  final String date;
  final String note;
  final String? person;

  TransactionEntity({
    required this.id, required this.amount, required this.type,
    required this.categoryId, required this.walletId, required this.date,
    required this.note, this.person,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'amount': amount, 'type': type, 'categoryId': categoryId,
      'walletId': walletId, 'date': date, 'note': note, 'person': person,
    };
  }

  factory TransactionEntity.fromMap(Map<String, dynamic> map) {
    return TransactionEntity(
      id: map['id'], amount: map['amount'], type: map['type'],
      categoryId: map['categoryId'], walletId: map['walletId'],
      date: map['date'], note: map['note'], person: map['person'],
    );
  }
}