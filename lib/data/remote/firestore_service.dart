import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Lưu ý: Kiểm tra lại đường dẫn import TransactionModel cho đúng với thư mục của bạn
import '../../domain/model/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================================================================
  // 1. HÀM TRỢ GIÚP: Xác định đúng "kho" chứa dữ liệu
  // =========================================================================
  CollectionReference _getUserTransactionsCollection() {
    final userId = _auth.currentUser?.uid;

    if (userId != null) {
      // Nếu user ĐÃ đăng nhập: Lưu vào nhánh users -> [UID] -> transactions
      return _db.collection('users').doc(userId).collection('transactions');
    } else {
      // Nếu user CHƯA đăng nhập (đang code test): Lưu tạm vào bảng chung
      return _db.collection('test_transactions');
    }
  }

  // =========================================================================
  // 2. HÀM LẤY DỮ LIỆU (READ)
  // =========================================================================
  Stream<QuerySnapshot> getTransactionsStream() {
    final collection = _getUserTransactionsCollection();
    // Tự động sắp xếp giao dịch theo ngày, mới nhất xếp trên cùng
    return collection.orderBy('date', descending: true).snapshots();
  }

  // Lấy dữ liệu dạng Future (Dùng cho Repository của bạn)
  Future<List<TransactionModel>> getTransactions() async {
    final collection = _getUserTransactionsCollection();
    final snapshot = await collection.orderBy('date', descending: true).get();

    return snapshot.docs.map((doc) {
      return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  // =========================================================================
  // 3. HÀM THÊM VÀ CẬP NHẬT (CREATE / UPDATE)
  // =========================================================================
  Future<void> createOrUpdateTransaction(TransactionModel transaction) async {
    final collection = _getUserTransactionsCollection();
    // Dùng .set() với ID truyền vào.
    // Nếu ID đã tồn tại -> Cập nhật. Nếu ID chưa có -> Tạo mới.
    await collection.doc(transaction.id).set(transaction.toMap());
  }

  // =========================================================================
  // 4. HÀM XÓA (DELETE)
  // =========================================================================
  Future<void> deleteTransaction(String transactionId) async {
    final collection = _getUserTransactionsCollection();
    await collection.doc(transactionId).delete();
  }
}