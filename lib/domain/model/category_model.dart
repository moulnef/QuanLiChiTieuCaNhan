import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final IconData? iconData;
  final Color color;
  final String type;
  final String? group;
  final bool isDefault;
  final int createdAt;

  CategoryModel({
    this.id = '',
    required this.name,
    this.icon,
    this.iconData,
    required this.color,
    required this.type,
    this.group,
    this.isDefault = false,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  String get colorHex => _colorToHex(color);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'iconCodePoint': iconData?.codePoint,
      'colorHex': colorHex,
      'type': type,
      'group': group,
      'isDefault': isDefault,
      'createdAt': createdAt,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'],
      iconData: _iconDataFromMap(map['iconCodePoint']),
      color: _colorFromHex(map['colorHex']),
      type: map['type'] ?? 'expense',
      group: map['group'],
      isDefault: map['isDefault'] ?? false,
      createdAt: map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    IconData? iconData,
    Color? color,
    String? type,
    String? group,
    bool? isDefault,
    int? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      iconData: iconData ?? this.iconData,
      color: color ?? this.color,
      type: type ?? this.type,
      group: group ?? this.group,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
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