import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String type; // 'expense' (chi) hoặc 'income' (thu)
  final String? group;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.group,
  });
}