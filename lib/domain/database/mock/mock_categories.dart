import 'package:flutter/material.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/category_model.dart';

class MockCategories {
  static final List<CategoryModel> items = [
    CategoryModel(
      id: 'cat_food',
      name: 'Ăn uống',
      iconData: Icons.restaurant, // Đã đổi từ '🍜'
      color: const Color(0xFFF97316),
      type: 'expense',
      group: 'Ăn uống',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_transport',
      name: 'Di chuyển',
      iconData: Icons.directions_car_filled, // Đã đổi từ '🚗'
      color: const Color(0xFF22C55E),
      type: 'expense',
      group: 'Đi lại',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_shopping',
      name: 'Mua sắm',
      iconData: Icons.shopping_bag, // Đã đổi từ '🛍️'
      color: const Color(0xFFEF4444),
      type: 'expense',
      group: 'Mua sắm',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_entertainment',
      name: 'Giải trí',
      iconData: Icons.sports_esports, // Đã đổi từ '🎮'
      color: const Color(0xFF8B5CF6),
      type: 'expense',
      group: 'Giải trí',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_bill',
      name: 'Hóa đơn',
      iconData: Icons.receipt_long, // Đã đổi từ '⚡'
      color: const Color(0xFFF59E0B),
      type: 'expense',
      group: 'Dịch vụ sinh hoạt',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_health',
      name: 'Sức khỏe',
      iconData: Icons.medical_services, // Đã đổi từ '💊'
      color: const Color(0xFFEC4899),
      type: 'expense',
      group: 'Sức khỏe',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_education',
      name: 'Giáo dục',
      iconData: Icons.school, // Đã đổi từ '📚'
      color: const Color(0xFF3B82F6),
      type: 'expense',
      group: 'Giáo dục',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
    CategoryModel(
      id: 'cat_travel',
      name: 'Du lịch',
      iconData: Icons.flight_takeoff, // Đã đổi từ '✈️'
      color: const Color(0xFF06B6D4),
      type: 'expense',
      group: 'Hưởng thụ',
      isDefault: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
  ];
}