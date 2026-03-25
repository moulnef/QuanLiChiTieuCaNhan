import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy ID của người dùng hiện tại
  String? get userId => _auth.currentUser?.uid;

  // 1. Thêm giao dịch chi tiêu mới
  Future<void> addTransaction({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    if (userId == null) return;

    try {
      await _db.collection('users').doc(userId).collection('transactions').add({
        'title': title,
        'amount': amount,
        'category': category,
        'date': Timestamp.fromDate(date),
        'note': note ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // 2. Lấy danh sách giao dịch của người dùng (Sắp xếp theo ngày mới nhất)
  Stream<QuerySnapshot> getTransactions() {
    if (userId == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  // 3. Xóa một giao dịch
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
