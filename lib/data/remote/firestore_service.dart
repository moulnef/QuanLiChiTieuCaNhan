import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  Future<void> addTransaction({
    required String title,
    required double amount,
    required String category,
    required String categoryId, // Thêm categoryId
    required DateTime date,
    String? note,
  }) async {
    if (userId == null) return;

    try {
      await _db.collection('users').doc(userId).collection('transactions').add({
        'title': title,
        'amount': amount,
        'category': category,
        'categoryId': categoryId, // Lưu categoryId để khớp với ngân sách
        'date': Timestamp.fromDate(date),
        'note': note ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getTransactions() {
    if (userId == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> deleteTransaction(String docId) async {
    if (userId == null) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(docId)
        .delete();
  }
}
