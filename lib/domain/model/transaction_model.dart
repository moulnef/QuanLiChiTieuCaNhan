class TransactionModel {
  String id;
  double amount;
  String type; 
  String categoryId;
  String walletId;
  DateTime date;
  String note;
  String? person;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    required this.date,
    this.note = '',
    this.person,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'walletId': walletId,
      'date': date.toIso8601String(),
      'note': note,
      'person': person,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      amount: map['amount'],
      type: map['type'],
      categoryId: map['categoryId'],
      walletId: map['walletId'],
      date: DateTime.parse(map['date']),
      note: map['note'],
      person: map['person'],
    );
  }
}