import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';

class TransactionRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  Future<List<TransactionModel>> getTransactions() async {
    final userId = _userId;
    if (userId == null) return [];

    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> addTransaction(TransactionModel tx) async {
    final userId = _userId;
    if (userId == null) return;

    final payload = tx.toMap();
    final docRef = _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(tx.id.isEmpty ? null : tx.id);

    if (tx.id.isEmpty) {
      await _db
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .add(payload);
    } else {
      await docRef.set(payload, SetOptions(merge: true));
    }
  }

  Future<void> deleteTransaction(String id) async {
    final userId = _userId;
    if (userId == null || id.isEmpty) return;

    await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(id)
        .delete();
  }
}
