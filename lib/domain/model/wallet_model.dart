import 'package:cloud_firestore/cloud_firestore.dart';

class WalletModel {
  final String id;
  final String userId;
  final String name;
  final double balance;
  final String currency; // 'VND', 'USD'...
  final String type; // 'cash' | 'bank' | 'ewallet' | 'credit'
  final int color; // Color value
  final String icon;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    this.currency = 'VND',
    this.type = 'cash',
    this.color = 0xFF4CAF50,
    this.icon = 'wallet',
    this.isDefault = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  WalletModel copyWith({
    String? id,
    String? userId,
    String? name,
    double? balance,
    String? currency,
    String? type,
    int? color,
    String? icon,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'balance': balance,
      'currency': currency,
      'type': type,
      'color': color,
      'icon': icon,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'userId': userId,
      'user_id': userId,
      'name': name,
      'balance': balance,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'status': isDefault ? 'default' : 'active',
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map, [String? documentId]) {
    DateTime parseTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    int parseColor(dynamic value) {
      if (value is int) return value;
      if (value == null) return 0xFF4CAF50;
      final parsed = int.tryParse(value.toString());
      return parsed ?? 0xFF4CAF50;
    }

    return WalletModel(
      id: documentId ?? map['id'] ?? '',
      userId: map['userId'] ?? map['user_id'] ?? '',
      name: map['name'] ?? '',
      balance: (map['balance'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'VND',
      type: map['type'] ?? 'cash',
      color: parseColor(map['color']),
      icon: map['icon'] ?? 'wallet',
      isDefault: map['isDefault'] ?? (map['status'] == 'default'),
      createdAt: parseTime(map['createdAt'] ?? map['created_at']),
      updatedAt: parseTime(map['updatedAt'] ?? map['updated_at']),
    );
  }
}
