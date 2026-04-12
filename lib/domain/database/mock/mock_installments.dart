import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/installment_plan.dart';

class MockInstallments {
  static final List<InstallmentPlan> items = [
    InstallmentPlan(
      id: 'installment_001',
      userId: 'user_001',
      title: 'Điện thoại iPhone 15',
      icon: '📱',
      totalAmount: 27500000,
      paidAmount: 9166664,
      monthlyPayment: 2291666,
      paidPeriods: 4,
      totalPeriods: 12,
      nextDueDate: DateTime(2026, 4, 5).millisecondsSinceEpoch,
      createdAt: DateTime(2026, 1, 5).millisecondsSinceEpoch,
      updatedAt: DateTime(2026, 3, 24).millisecondsSinceEpoch,
      status: 'active',
    ),
    InstallmentPlan(
      id: 'installment_002',
      userId: 'user_001',
      title: 'Máy tính xách tay',
      icon: '💻',
      totalAmount: 19260000,
      paidAmount: 14260000,
      monthlyPayment: 1596666,
      paidPeriods: 11,
      totalPeriods: 12,
      nextDueDate: DateTime(2026, 4, 10).millisecondsSinceEpoch,
      createdAt: DateTime(2025, 5, 10).millisecondsSinceEpoch,
      updatedAt: DateTime(2026, 3, 24).millisecondsSinceEpoch,
      status: 'active',
    ),
  ];
}