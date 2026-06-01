import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/model/transaction_model.dart';
import '../../domain/model/wallet_model.dart';
import '../../domain/model/budget.dart';
import '../../domain/model/category_model.dart';
import '../../domain/model/saving.dart';
import '../../domain/model/debt_record.dart';
import '../../domain/model/installment_plan.dart';

class FirestoreException implements Exception {
  final String message;
  final dynamic originalError;
  FirestoreException(this.message, [this.originalError]);

  @override
  String toString() => "FirestoreException: $message (${originalError ?? ''})";
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw FirestoreException("Người dùng chưa đăng nhập.");
    }
    return uid;
  }

  // Helper collection references
  DocumentReference _userDocRef() => _db.collection('users').doc(userId);

  CollectionReference _walletsRef() => _userDocRef().collection('wallets');
  CollectionReference _categoriesRef() =>
      _userDocRef().collection('categories');
  CollectionReference _transactionsRef() =>
      _userDocRef().collection('transactions');
  CollectionReference _budgetsRef() => _userDocRef().collection('budgets');
  CollectionReference _savingsRef() => _userDocRef().collection('savings');
  CollectionReference _debtsRef() => _userDocRef().collection('debts');
  CollectionReference _installmentsRef() =>
      _userDocRef().collection('installments');

  // ==================== 1. WALLET CRUD ====================

  Stream<List<WalletModel>> streamWallets() {
    try {
      return _walletsRef().orderBy('name').snapshots().map((snapshot) {
        return snapshot.docs
            .map(
              (doc) => WalletModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();
      });
    } catch (e) {
      print("Lỗi streamWallets: $e");
      throw FirestoreException("Không thể theo dõi ví: $e", e);
    }
  }

  Future<List<WalletModel>> getWallets() async {
    try {
      final snapshot = await _walletsRef().orderBy('name').get();
      return snapshot.docs
          .map(
            (doc) =>
                WalletModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print("Lỗi getWallets: $e");
      throw FirestoreException("Không thể lấy danh sách ví: $e", e);
    }
  }

  Future<void> addWallet(WalletModel wallet) async {
    try {
      final docId = wallet.id.isNotEmpty ? wallet.id : _walletsRef().doc().id;
      final docRef = _walletsRef().doc(docId);
      final data = wallet.copyWith(id: docId, userId: userId).toMap();
      await docRef.set(data);
    } catch (e) {
      print("Lỗi addWallet: $e");
      throw FirestoreException("Không thể thêm ví: $e", e);
    }
  }

  Future<void> updateWallet(WalletModel wallet) async {
    try {
      final docRef = _walletsRef().doc(wallet.id);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw FirestoreException("Không tìm thấy ví cần cập nhật.");
      }
      final data = wallet.copyWith(updatedAt: DateTime.now()).toMap();
      await docRef.update(data);
    } catch (e) {
      print("Lỗi updateWallet: $e");
      throw FirestoreException("Không thể cập nhật ví: $e", e);
    }
  }

  Future<void> deleteWallet(String walletId) async {
    try {
      final docRef = _walletsRef().doc(walletId);
      await docRef.delete();
    } catch (e) {
      print("Lỗi deleteWallet: $e");
      throw FirestoreException("Không thể xóa ví: $e", e);
    }
  }

  // ==================== 2. CATEGORY CRUD ====================

  Stream<List<CategoryModel>> streamCategories() {
    try {
      return _categoriesRef().orderBy('name').snapshots().map((snapshot) {
        return snapshot.docs
            .map(
              (doc) => CategoryModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();
      });
    } catch (e) {
      print("Lỗi streamCategories: $e");
      throw FirestoreException("Không thể theo dõi danh mục: $e", e);
    }
  }

  Future<List<CategoryModel>> getCategories() async {
    try {
      final snapshot = await _categoriesRef().orderBy('name').get();
      return snapshot.docs
          .map(
            (doc) => CategoryModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print("Lỗi getCategories: $e");
      throw FirestoreException("Không thể lấy danh sách danh mục: $e", e);
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    try {
      final docId = category.id.isNotEmpty
          ? category.id
          : _categoriesRef().doc().id;
      final docRef = _categoriesRef().doc(docId);
      final data = category.copyWith(id: docId, userId: userId).toMap();
      await docRef.set(data);
    } catch (e) {
      print("Lỗi addCategory: $e");
      throw FirestoreException("Không thể thêm danh mục: $e", e);
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    try {
      final docRef = _categoriesRef().doc(category.id);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw FirestoreException("Không tìm thấy danh mục cần cập nhật.");
      }
      final data = category.toMap();
      await docRef.update(data);
    } catch (e) {
      print("Lỗi updateCategory: $e");
      throw FirestoreException("Không thể cập nhật danh mục: $e", e);
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      final docRef = _categoriesRef().doc(categoryId);
      await docRef.delete();
    } catch (e) {
      print("Lỗi deleteCategory: $e");
      throw FirestoreException("Không thể xóa danh mục: $e", e);
    }
  }

  // ==================== 3. TRANSACTION CRUD ====================

  Stream<List<TransactionModel>> streamTransactions() {
    try {
      return _transactionsRef()
          .where('isDeleted', isEqualTo: false)
          .orderBy('transactionDate', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map(
                  (doc) => TransactionModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ),
                )
                .toList();
          });
    } catch (e) {
      print("Lỗi streamTransactions: $e");
      throw FirestoreException("Không thể theo dõi giao dịch: $e", e);
    }
  }

  Future<List<TransactionModel>> getTransactions() async {
    try {
      final snapshot = await _transactionsRef()
          .where('isDeleted', isEqualTo: false)
          .orderBy('transactionDate', descending: true)
          .get();
      return snapshot.docs
          .map(
            (doc) => TransactionModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print("Lỗi getTransactions: $e");
      throw FirestoreException("Không thể lấy danh sách giao dịch: $e", e);
    }
  }

  Future<void> addTransaction(TransactionModel tx) async {
    try {
      final docId = tx.id.isNotEmpty ? tx.id : _transactionsRef().doc().id;
      final docRef = _transactionsRef().doc(docId);
      final data = tx
          .copyWith(id: docId, userId: userId, isDeleted: false)
          .toMap();
      await docRef.set(data);

      // Recalculations
      await _recalculateWalletBalance(tx.walletId);
      await _recalculateBudgetSpent(
        tx.categoryId,
        tx.transactionDate.month,
        tx.transactionDate.year,
      );
    } catch (e) {
      print("Lỗi addTransaction: $e");
      throw FirestoreException("Không thể thêm giao dịch: $e", e);
    }
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    try {
      final docRef = _transactionsRef().doc(tx.id);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw FirestoreException("Không tìm thấy giao dịch cần cập nhật.");
      }

      final oldTx = TransactionModel.fromMap(
        docSnap.data() as Map<String, dynamic>,
        docSnap.id,
      );
      final data = tx.copyWith(updatedAt: DateTime.now()).toMap();
      await docRef.update(data);

      // Recalculate balances for both old and new wallets
      await _recalculateWalletBalance(tx.walletId);
      if (tx.walletId != oldTx.walletId) {
        await _recalculateWalletBalance(oldTx.walletId);
      }

      // Recalculate budget spent for both old and new categories / dates
      await _recalculateBudgetSpent(
        tx.categoryId,
        tx.transactionDate.month,
        tx.transactionDate.year,
      );
      if (tx.categoryId != oldTx.categoryId ||
          tx.transactionDate.month != oldTx.transactionDate.month ||
          tx.transactionDate.year != oldTx.transactionDate.year) {
        await _recalculateBudgetSpent(
          oldTx.categoryId,
          oldTx.transactionDate.month,
          oldTx.transactionDate.year,
        );
      }
    } catch (e) {
      print("Lỗi updateTransaction: $e");
      throw FirestoreException("Không thể cập nhật giao dịch: $e", e);
    }
  }

  Future<void> deleteTransaction(String txId) async {
    try {
      final docRef = _transactionsRef().doc(txId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      final tx = TransactionModel.fromMap(
        docSnap.data() as Map<String, dynamic>,
        docSnap.id,
      );

      // Perform soft delete
      await docRef.update({'isDeleted': true, 'updatedAt': Timestamp.now()});

      // Recalculations
      await _recalculateWalletBalance(tx.walletId);
      await _recalculateBudgetSpent(
        tx.categoryId,
        tx.transactionDate.month,
        tx.transactionDate.year,
      );
    } catch (e) {
      print("Lỗi deleteTransaction: $e");
      throw FirestoreException("Không thể xóa giao dịch: $e", e);
    }
  }

  // ==================== 4. BUDGET CRUD ====================

  Stream<List<Budget>> streamBudgets() {
    try {
      return _budgetsRef().where('isActive', isEqualTo: true).snapshots().map((
        snapshot,
      ) {
        return snapshot.docs
            .map(
              (doc) =>
                  Budget.fromMap(doc.data() as Map<String, dynamic>, doc.id),
            )
            .toList();
      });
    } catch (e) {
      print("Lỗi streamBudgets: $e");
      throw FirestoreException("Không thể theo dõi ngân sách: $e", e);
    }
  }

  Future<List<Budget>> getBudgets() async {
    try {
      final snapshot = await _budgetsRef()
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map(
            (doc) => Budget.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print("Lỗi getBudgets: $e");
      throw FirestoreException("Không thể lấy danh sách ngân sách: $e", e);
    }
  }

  Future<void> addBudget(Budget budget) async {
    try {
      final docId = budget.id.isNotEmpty ? budget.id : _budgetsRef().doc().id;
      final docRef = _budgetsRef().doc(docId);

      // Recalculate spentAmount first
      final spent = await _sumExpenseByCategory(
        budget.categoryId,
        budget.month,
        budget.year,
      );

      final data = budget
          .copyWith(
            id: docId,
            userId: userId,
            spentAmount: spent,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
          .toMap();

      // Đảm bảo isActive luôn được set
      data['isActive'] = true;

      await docRef.set(data);
    } catch (e) {
      print("Lỗi addBudget: $e");
      throw FirestoreException("Không thể thêm ngân sách: $e", e);
    }
  }

  Future<void> updateBudget(Budget budget) async {
    try {
      final docRef = _budgetsRef().doc(budget.id);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw FirestoreException("Không tìm thấy ngân sách cần cập nhật.");
      }

      final spent = await _sumExpenseByCategory(
        budget.categoryId,
        budget.month,
        budget.year,
      );
      final data = budget
          .copyWith(spentAmount: spent, updatedAt: DateTime.now())
          .toMap();
      await docRef.update(data);
    } catch (e) {
      print("Lỗi updateBudget: $e");
      throw FirestoreException("Không thể cập nhật ngân sách: $e", e);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    try {
      // Soft-deactivation or hard delete. Let's update isActive = false
      final docRef = _budgetsRef().doc(budgetId);
      await docRef.update({'isActive': false, 'updatedAt': Timestamp.now()});
    } catch (e) {
      print("Lỗi deleteBudget: $e");
      throw FirestoreException("Không thể xóa ngân sách: $e", e);
    }
  }

  // ==================== 5. SAVINGS CRUD ====================

  Stream<List<SavingGoal>> streamSavings() {
    try {
      return _savingsRef().snapshots().map((snapshot) {
        return snapshot.docs
            .map(
              (doc) => SavingGoal.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();
      });
    } catch (e) {
      print("Lỗi streamSavings: $e");
      throw FirestoreException("Không thể theo dõi tiết kiệm: $e", e);
    }
  }

  Future<List<SavingGoal>> getSavings() async {
    try {
      final snapshot = await _savingsRef().get();
      return snapshot.docs
          .map((doc) => SavingGoal.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Lỗi getSavings: $e");
      throw FirestoreException("Không thể lấy mục tiêu tiết kiệm: $e", e);
    }
  }

  Future<void> addSaving(SavingGoal saving) async {
    try {
      final docId = saving.id.isNotEmpty ? saving.id : _savingsRef().doc().id;
      final docRef = _savingsRef().doc(docId);
      final data = saving
          .copyWith(
            id: docId,
            userId: userId,
            createdAt: saving.createdAt == 0
                ? DateTime.now().millisecondsSinceEpoch
                : saving.createdAt,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )
          .toMap();
      await docRef.set(data);
    } catch (e) {
      print("Lỗi addSaving: $e");
      throw FirestoreException("Không thể thêm tiết kiệm: $e", e);
    }
  }

  Future<void> updateSaving(SavingGoal saving) async {
    try {
      final docRef = _savingsRef().doc(saving.id);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw FirestoreException("Không tìm thấy mục tiêu tiết kiệm.");
      }
      final data = saving
          .copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch)
          .toMap();
      await docRef.update(data);
    } catch (e) {
      print("Lỗi updateSaving: $e");
      throw FirestoreException("Không thể cập nhật tiết kiệm: $e", e);
    }
  }

  Future<void> deleteSaving(String savingId) async {
    try {
      await _savingsRef().doc(savingId).delete();
    } catch (e) {
      print("Lỗi deleteSaving: $e");
      throw FirestoreException("Không thể xóa tiết kiệm: $e", e);
    }
  }

  // ==================== 6. DEBTS CRUD ====================

  Stream<List<DebtRecord>> streamDebts() {
    try {
      return _debtsRef().snapshots().map((snapshot) {
        return snapshot.docs
            .map(
              (doc) => DebtRecord.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();
      });
    } catch (e) {
      print("Lỗi streamDebts: $e");
      throw FirestoreException("Không thể theo dõi nợ: $e", e);
    }
  }

  Future<List<DebtRecord>> getDebts() async {
    try {
      final snapshot = await _debtsRef().get();
      return snapshot.docs
          .map((doc) => DebtRecord.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Lỗi getDebts: $e");
      throw FirestoreException("Không thể lấy khoản nợ: $e", e);
    }
  }

  Future<void> addDebt(DebtRecord debt) async {
    try {
      final docId = debt.id.isNotEmpty ? debt.id : _debtsRef().doc().id;
      final docRef = _debtsRef().doc(docId);
      final data = debt
          .copyWith(
            id: docId,
            userId: userId,
            createdAt: debt.createdAt == 0
                ? DateTime.now().millisecondsSinceEpoch
                : debt.createdAt,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )
          .toMap();
      await docRef.set(data);
    } catch (e) {
      print("Lỗi addDebt: $e");
      throw FirestoreException("Không thể thêm khoản nợ: $e", e);
    }
  }

  Future<void> updateDebt(DebtRecord debt) async {
    try {
      final docRef = _debtsRef().doc(debt.id);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw FirestoreException("Không tìm thấy khoản nợ.");
      }
      final data = debt
          .copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch)
          .toMap();
      await docRef.update(data);
    } catch (e) {
      print("Lỗi updateDebt: $e");
      throw FirestoreException("Không thể cập nhật khoản nợ: $e", e);
    }
  }

  Future<void> deleteDebt(String debtId) async {
    try {
      await _debtsRef().doc(debtId).delete();
    } catch (e) {
      print("Lỗi deleteDebt: $e");
      throw FirestoreException("Không thể xóa khoản nợ: $e", e);
    }
  }

  // ==================== 7. INSTALLMENTS CRUD ====================

  Stream<List<InstallmentPlan>> streamInstallments() {
    try {
      return _installmentsRef().snapshots().map((snapshot) {
        return snapshot.docs
            .map(
              (doc) =>
                  InstallmentPlan.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();
      });
    } catch (e) {
      print("Lỗi streamInstallments: $e");
      throw FirestoreException("Không thể theo dõi trả góp: $e", e);
    }
  }

  Future<List<InstallmentPlan>> getInstallments() async {
    try {
      final snapshot = await _installmentsRef().get();
      return snapshot.docs
          .map(
            (doc) =>
                InstallmentPlan.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print("Lỗi getInstallments: $e");
      throw FirestoreException("Không thể lấy khoản trả góp: $e", e);
    }
  }

  Future<void> addInstallment(InstallmentPlan plan) async {
    try {
      final docId = plan.id.isNotEmpty ? plan.id : _installmentsRef().doc().id;
      final docRef = _installmentsRef().doc(docId);
      final data = plan
          .copyWith(
            id: docId,
            userId: userId,
            createdAt: plan.createdAt == 0
                ? DateTime.now().millisecondsSinceEpoch
                : plan.createdAt,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          )
          .toMap();
      await docRef.set(data);
    } catch (e) {
      print("Lỗi addInstallment: $e");
      throw FirestoreException("Không thể thêm trả góp: $e", e);
    }
  }

  Future<void> updateInstallment(InstallmentPlan plan) async {
    try {
      final docRef = _installmentsRef().doc(plan.id);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw FirestoreException("Không tìm thấy khoản trả góp.");
      }
      final data = plan
          .copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch)
          .toMap();
      await docRef.update(data);
    } catch (e) {
      print("Lỗi updateInstallment: $e");
      throw FirestoreException("Không thể cập nhật trả góp: $e", e);
    }
  }

  Future<void> deleteInstallment(String planId) async {
    try {
      await _installmentsRef().doc(planId).delete();
    } catch (e) {
      print("Lỗi deleteInstallment: $e");
      throw FirestoreException("Không thể xóa trả góp: $e", e);
    }
  }

  // ==================== 8. SETTINGS & PROFILE ====================

  Future<Map<String, dynamic>?> getSettings() async {
    try {
      final docSnap = await _userDocRef()
          .collection('settings')
          .doc('app_settings')
          .get();
      if (docSnap.exists) {
        return docSnap.data();
      }
      return null;
    } catch (e) {
      print("Lỗi getSettings: $e");
      throw FirestoreException("Không thể lấy cài đặt: $e", e);
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      final data = Map<String, dynamic>.from(settings);
      data['userId'] = userId;
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _userDocRef()
          .collection('settings')
          .doc('app_settings')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print("Lỗi updateSettings: $e");
      throw FirestoreException("Không thể cập nhật cài đặt: $e", e);
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final docSnap = await _userDocRef()
          .collection('profile')
          .doc('user_profile')
          .get();
      if (docSnap.exists) {
        return docSnap.data();
      }
      return null;
    } catch (e) {
      print("Lỗi getProfile: $e");
      throw FirestoreException("Không thể lấy profile: $e", e);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> profile) async {
    try {
      final data = Map<String, dynamic>.from(profile);
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _userDocRef()
          .collection('profile')
          .doc('user_profile')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print("Lỗi updateProfile: $e");
      throw FirestoreException("Không thể cập nhật profile: $e", e);
    }
  }

  // ==================== 9. BATCH SYNC ENGINE WRITE ====================

  Future<void> batchWrite({
    List<TransactionModel>? transactions,
    List<WalletModel>? wallets,
    List<Budget>? budgets,
    List<CategoryModel>? categories,
    List<SavingGoal>? savings,
    List<DebtRecord>? debts,
    List<InstallmentPlan>? installments,
  }) async {
    try {
      final batch = _db.batch();

      if (wallets != null) {
        for (final item in wallets) {
          final docRef = _walletsRef().doc(item.id);
          batch.set(
            docRef,
            item.copyWith(userId: userId).toMap(),
            SetOptions(merge: true),
          );
        }
      }

      if (categories != null) {
        for (final item in categories) {
          final docRef = _categoriesRef().doc(item.id);
          batch.set(
            docRef,
            item.copyWith(userId: userId).toMap(),
            SetOptions(merge: true),
          );
        }
      }

      if (transactions != null) {
        for (final item in transactions) {
          final docRef = _transactionsRef().doc(item.id);
          batch.set(
            docRef,
            item.copyWith(userId: userId).toMap(),
            SetOptions(merge: true),
          );
        }
      }

      if (budgets != null) {
        for (final item in budgets) {
          final docRef = _budgetsRef().doc(item.id);
          batch.set(
            docRef,
            item.copyWith(userId: userId).toMap(),
            SetOptions(merge: true),
          );
        }
      }

      if (savings != null) {
        for (final item in savings) {
          final docRef = _savingsRef().doc(item.id);
          batch.set(
            docRef,
            item.copyWith(userId: userId).toMap(),
            SetOptions(merge: true),
          );
        }
      }

      if (debts != null) {
        for (final item in debts) {
          final docRef = _debtsRef().doc(item.id);
          batch.set(
            docRef,
            item.copyWith(userId: userId).toMap(),
            SetOptions(merge: true),
          );
        }
      }

      if (installments != null) {
        for (final item in installments) {
          final docRef = _installmentsRef().doc(item.id);
          batch.set(
            docRef,
            item.copyWith(userId: userId).toMap(),
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();

      // Run bulk recalculations for wallets and budgets impacted
      final Set<String> walletIdsToRecalc = {};
      final Set<String> categoryIdsToRecalc = {};

      if (transactions != null) {
        for (final tx in transactions) {
          walletIdsToRecalc.add(tx.walletId);
          categoryIdsToRecalc.add(tx.categoryId);
        }
      }

      for (final wId in walletIdsToRecalc) {
        await _recalculateWalletBalance(wId);
      }

      if (transactions != null) {
        for (final tx in transactions) {
          await _recalculateBudgetSpent(
            tx.categoryId,
            tx.transactionDate.month,
            tx.transactionDate.year,
          );
        }
      }
    } catch (e) {
      print("Lỗi batchWrite: $e");
      throw FirestoreException("Đồng bộ dữ liệu hàng loạt thất bại: $e", e);
    }
  }

  // ==================== INTERNAL RECALCULATION HELPERS ====================

  Future<void> _recalculateWalletBalance(String walletId) async {
    if (walletId.isEmpty) return;
    try {
      final txSnapshot = await _transactionsRef()
          .where('walletId', isEqualTo: walletId)
          .where('isDeleted', isEqualTo: false)
          .get();

      double balance = 0;
      for (final doc in txSnapshot.docs) {
        final txData = doc.data() as Map<String, dynamic>;
        final amount = (txData['amount'] ?? 0).toDouble();
        final type = txData['type'] ?? 'expense';
        if (type == 'income') {
          balance += amount;
        } else if (type == 'expense') {
          balance -= amount;
        }
      }

      await _walletsRef().doc(walletId).update({
        'balance': balance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Không thể tự động cập nhật số dư ví $walletId: $e");
    }
  }

  Future<void> _recalculateBudgetSpent(
    String categoryId,
    int month,
    int year,
  ) async {
    if (categoryId.isEmpty) return;
    try {
      final spent = await _sumExpenseByCategory(categoryId, month, year);

      final budgetSnapshot = await _budgetsRef()
          .where('categoryId', isEqualTo: categoryId)
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .get();

      for (final doc in budgetSnapshot.docs) {
        final budgetData = doc.data() as Map<String, dynamic>;
        final limitAmount = (budgetData['limitAmount'] ?? budgetData['limit_amount'] ?? 0).toDouble();
        final ratio = limitAmount > 0 ? spent / limitAmount : 0.0;
        String status = 'safe';
        if (ratio >= 1.0) {
          status = 'danger';
        } else if (ratio >= 0.9) {
          status = 'warning';
        }

        await doc.reference.update({
          'spentAmount': spent,
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print(
        "Không thể tự động cập nhật tổng chi ngân sách cho danh mục $categoryId: $e",
      );
    }
  }

  Future<double> _sumExpenseByCategory(
    String categoryId,
    int month,
    int year,
  ) async {
    final start = DateTime(year, month, 1);
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final end = DateTime(
      nextYear,
      nextMonth,
      1,
    ).subtract(const Duration(milliseconds: 1));

    final txSnapshot = await _transactionsRef()
        .where('categoryId', isEqualTo: categoryId)
        .where('type', isEqualTo: 'expense')
        .where('isDeleted', isEqualTo: false)
        .where(
          'transactionDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('transactionDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    double spent = 0;
    for (final doc in txSnapshot.docs) {
      final txData = doc.data() as Map<String, dynamic>;
      spent += (txData['amount'] ?? 0).toDouble();
    }
    return spent;
  }
}
