import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Test budget spent amount updates on transaction insert', () async {
    final repo = FinanceRepository();
    
    final userId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Create a budget
    final budget = Budget(
      id: 'test_budget_1_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      categoryId: 'e4',
      categoryName: 'Đi chợ/Siêu thị',
      icon: '🛒',
      month: 6,
      year: 2026,
      limitAmount: 300000.0,
      spentAmount: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: 'safe',
    );

    await repo.createBudget(budget);
    
    // Check budget limit in database
    var budgets = await repo.getBudgets(userId, 6, 2026);
    expect(budgets.length, 1);
    expect(budgets.first.spentAmount, 0.0);

    // 2. Insert a transaction
    final tx = TransactionModel(
      id: 'test_tx_1_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      walletId: 'test_wallet',
      categoryId: 'e4',
      categoryName: 'Đi chợ/Siêu thị',
      type: 'expense',
      amount: 50000.0,
      transactionDate: DateTime(2026, 6, 5, 12, 0, 0),
    );

    await repo.upsertTransaction(tx);

    // 3. Check if budget spent is updated
    budgets = await repo.getBudgets(userId, 6, 2026);
    print('DEBUG: Budgets count after transaction: ${budgets.length}');
    if (budgets.isNotEmpty) {
      print('DEBUG: Budget spentAmount: ${budgets.first.spentAmount}');
    }
    expect(budgets.first.spentAmount, 50000.0);
  });
}
