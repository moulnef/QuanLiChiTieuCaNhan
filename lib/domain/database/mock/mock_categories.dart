import 'package:flutter/material.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/category_model.dart';

class MockCategories {
  static final List<CategoryModel> items = [
    CategoryModel(
      id: 'cat_food',
      name: 'Ăn uống',
      icon: '🍜',
      color: const Color(0xFFF97316),
      type: 'expense',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_transport',
      name: 'Di chuyển',
      icon: '🚗',
      color: const Color(0xFF22C55E),
      type: 'expense',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_shopping',
      name: 'Mua sắm',
      icon: '🛍️',
      color:const Color(0xFFEF4444),
      type: 'expense',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_entertainment',
      name: 'Giải trí',
      icon: '🎮',
      color:const Color(0xFF8B5CF6),
      type: 'expense',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_bill',
      name: 'Hóa đơn',
      icon: '⚡',
      color:const Color(0xFFF59E0B),
      type: 'expense',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_health',
      name: 'Sức khỏe',
      icon: '💊',
      color: const Color(0xFFEC4899),
      type: 'expense',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_education',
      name: 'Giáo dục',
      icon: '📚',
      color:const Color(0xFF3B82F6),
      type: 'expense',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_travel',
      name: 'Du lịch',
      icon: '✈️',
      color:const Color(0xFF06B6D4),
      type: 'expense',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
  ];
}