import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String? icon;
  final IconData? iconData;
  final Color color;
  final String type; // 'income' | 'expense'
  final String? group;
  final bool isDefault;
  final String? parentId;
  final DateTime createdAt;

  CategoryModel({
    this.id = '',
    this.userId = '',
    required this.name,
    this.icon,
    this.iconData,
    required this.color,
    required this.type,
    this.group,
    this.isDefault = false,
    this.parentId,
    dynamic createdAt,
  }) : createdAt = _parseDate(createdAt);

  String get colorHex => _colorToHex(color);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'icon': icon ?? (iconData != null ? iconData!.codePoint.toString() : ''),
      'iconCodePoint': iconData?.codePoint,
      'color': color.value,
      'colorHex': colorHex,
      'type': type,
      'group': group,
      'isDefault': isDefault,
      'parentId': parentId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawColor = map['color'];
    Color parsedColor = Colors.blue;
    if (rawColor is int) {
      parsedColor = Color(rawColor);
    } else if (map['colorHex'] != null) {
      parsedColor = _colorFromHex(map['colorHex']);
    }

    IconData? parsedIconData;
    if (map['iconCodePoint'] != null) {
      parsedIconData = _iconDataFromMap(map['iconCodePoint']);
    } else if (map['icon'] != null) {
      final code = int.tryParse(map['icon'].toString());
      if (code != null) {
        parsedIconData = IconData(code, fontFamily: 'MaterialIcons');
      }
    }

    return CategoryModel(
      id: docId ?? map['id'] ?? '',
      userId: map['userId'] ?? map['user_id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon']?.toString(),
      iconData: parsedIconData,
      color: parsedColor,
      type: map['type'] ?? 'expense',
      group: map['group'],
      isDefault: map['isDefault'] ?? false,
      parentId: map['parentId'],
      createdAt: map['createdAt'],
    );
  }

  CategoryModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? icon,
    IconData? iconData,
    Color? color,
    String? type,
    String? group,
    bool? isDefault,
    String? parentId,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      iconData: iconData ?? this.iconData,
      color: color ?? this.color,
      type: type ?? this.type,
      group: group ?? this.group,
      isDefault: isDefault ?? this.isDefault,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static String _colorToHex(Color color) {
    final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${hex.substring(2)}';
  }

  static Color _colorFromHex(dynamic hex) {
    if (hex == null) return Colors.blue;

    String value = hex.toString().replaceAll('#', '').toUpperCase();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return Colors.blue;

    return Color(int.parse(value, radix: 16));
  }

  static IconData? _iconDataFromMap(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return IconData(value, fontFamily: 'MaterialIcons');
    }
    final parsed = int.tryParse(value.toString());
    if (parsed != null) {
      return IconData(parsed, fontFamily: 'MaterialIcons');
    }
    return null;
  }
}