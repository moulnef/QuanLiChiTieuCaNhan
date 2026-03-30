import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/debt_record.dart';

class MockDebts {
  static final List<DebtRecord> items = [
    DebtRecord(
      id: 'debt_001',
      userId: 'user_001',
      title: 'Vay mua xe đạp điện',
      lenderName: 'Ngân hàng ACB',
      totalAmount: 12000000,
      paidAmount: 4500000,
      monthlyPayment: 550000,
      interestRate: 8.5,
      nextDueDate: DateTime(2026, 4, 1).millisecondsSinceEpoch,
      createdAt: DateTime(2025, 12, 1).millisecondsSinceEpoch,
      updatedAt: DateTime(2026, 3, 24).millisecondsSinceEpoch,
      status: 'active',
    ),
  ];
}