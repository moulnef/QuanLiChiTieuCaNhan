import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/model/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 💡 ĐÃ SỬA: Lấy ID người dùng. Nếu chưa làm chức năng đăng nhập thì dùng tạm 'test_user'
  String get userId => _auth.currentUser?.uid ?? 'test_user';

  // 💡 NƠI CHỨA DỮ LIỆU ĐÃ ĐƯỢC CHUẨN HÓA
  CollectionReference _getTransactionsRef() {
    return _db.collection('users').doc(userId).collection('transactions');
  }

  // 1. Thêm hoặc cập nhật giao dịch sử dụng TransactionModel
  Future<void> createOrUpdateTransaction(TransactionModel transaction) async {
    final ref = _getTransactionsRef();
    final data = transaction.toMap();

    if (transaction.id.isNotEmpty) {
      await ref.doc(transaction.id).set(data, SetOptions(merge: true));
    } else {
      final docRef = await ref.add(data);
      // Cập nhật lại ID tự động từ Firestore vào document
      await docRef.update({'id': docRef.id});
    }
  }

  // 2. Lấy danh sách giao dịch một lần (Future)
  Future<List<TransactionModel>> getTransactionsOnce() async {
    final snapshot = await _getTransactionsRef()
        .orderBy('transactionDate', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  // 3. Lấy danh sách giao dịch thời gian thực (Stream của Huy Hoàng)
  Stream<List<TransactionModel>> getTransactionsStream() {
    return _getTransactionsRef()
        .orderBy('transactionDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // 4. 💡 ĐÃ SỬA LỖI TÀNG HÌNH: Đổi điểm đến của hàm cũ cho trùng khớp với hàm mới!
  Stream<QuerySnapshot> getTransactions() {
    return _getTransactionsRef()
        .orderBy('transactionDate', descending: true)
        .snapshots();
  }

  // (Hàm cũ) Đã điều hướng nó lưu vào đúng phòng của người dùng
  Future<void> addTransaction({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    required String note,
  }) async {
    try {
      await _getTransactionsRef().add({
        'title': title,
        'amount': amount,
        'category': category,
        'date': date,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Lỗi khi thêm giao dịch: $e");
    }
  }

  // 5. Xóa một giao dịch
  Future<void> deleteTransaction(String docId) async {
    await _getTransactionsRef().doc(docId).delete();
  }
}