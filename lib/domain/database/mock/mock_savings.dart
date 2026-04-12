import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/saving.dart';

class MockSavings {
  static final List<SavingGoal> items = [
    SavingGoal(
      id: 'saving_001',
      userId: 'user_001',
      title: 'Mua xe máy mới',
      icon: '🏍️',
      currentAmount: 18500000,
      targetAmount: 35000000,
      targetDate: DateTime(2026, 12, 31).millisecondsSinceEpoch,
      createdAt: DateTime(2026, 3, 1).millisecondsSinceEpoch,
      updatedAt: DateTime(2026, 3, 24).millisecondsSinceEpoch,
      status: 'active',
    ),
    SavingGoal(
      id: 'saving_002',
      userId: 'user_001',
      title: 'Du lịch Nhật Bản',
      icon: '🗾',
      currentAmount: 8000000,
      targetAmount: 25000000,
      targetDate: DateTime(2027, 6, 1).millisecondsSinceEpoch,
      createdAt: DateTime(2026, 3, 1).millisecondsSinceEpoch,
      updatedAt: DateTime(2026, 3, 24).millisecondsSinceEpoch,
      status: 'active',
    ),
    SavingGoal(
      id: 'saving_003',
      userId: 'user_001',
      title: 'Quỹ khẩn cấp',
      icon: '🛡️',
      currentAmount: 32000000,
      targetAmount: 50000000,
      targetDate: DateTime(2026, 6, 30).millisecondsSinceEpoch,
      createdAt: DateTime(2026, 3, 1).millisecondsSinceEpoch,
      updatedAt: DateTime(2026, 3, 24).millisecondsSinceEpoch,
      status: 'active',
    ),
  ];
}