import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference expenses = FirebaseFirestore.instance.collection(
    'expenses',
  );

  Future<void> addExpense(String title, double amount) {
    return expenses.add({
      'title': title,
      'amount': amount,
      'timestamp': Timestamp.now(), // Lưu thời gian thực
    });
  }

  Stream<QuerySnapshot> getExpensesStream() {
    return expenses.orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> deleteExpense(String docID) {
    return expenses.doc(docID).delete();
  }
}
