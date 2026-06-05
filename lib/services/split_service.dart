import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/model/split_group.dart';
import '../domain/model/split_expense.dart';
import '../domain/model/split_payment.dart';
import '../domain/model/split_debt.dart';
import '../domain/model/split_member_info.dart';

class SplitService {
  SplitService._();
  static final SplitService instance = SplitService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Tìm kiếm user theo email
  Future<SplitMemberInfo?> findUserByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return SplitMemberInfo.fromMap(query.docs.first.data());
  }

  // 2. Stream danh sách nhóm của tôi
  Stream<List<SplitGroup>> watchMyGroups(String uid) {
    return _firestore
        .collection('split_groups')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SplitGroup.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // 3. Tạo nhóm mới
  Future<void> createGroup(SplitGroup group) async {
    await _firestore
        .collection('split_groups')
        .doc(group.id)
        .set(group.toMap());
  }

  // 4. Thêm thành viên vào nhóm bằng email
  Future<String?> addMemberByEmail(String groupId, String email) async {
    final member = await findUserByEmail(email);
    if (member == null) {
      return 'Không tìm thấy tài khoản với email này.';
    }

    final groupDoc = await _firestore.collection('split_groups').doc(groupId).get();
    if (!groupDoc.exists) {
      return 'Không tìm thấy nhóm.';
    }

    final group = SplitGroup.fromMap(groupDoc.data()!, groupDoc.id);
    if (group.memberUids.contains(member.uid)) {
      return 'Thành viên đã ở trong nhóm.';
    }

    final updatedMembers = List<String>.from(group.memberUids)..add(member.uid);
    await _firestore.collection('split_groups').doc(groupId).update({
      'memberUids': updatedMembers,
    });
    return null;
  }

  // 5. Xóa thành viên khỏi nhóm
  Future<void> removeMember(String groupId, String uid) async {
    final groupDoc = await _firestore.collection('split_groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final group = SplitGroup.fromMap(groupDoc.data()!, groupDoc.id);
    final updatedMembers = List<String>.from(group.memberUids)..remove(uid);
    await _firestore.collection('split_groups').doc(groupId).update({
      'memberUids': updatedMembers,
    });
  }

  // 6. Thêm chi tiêu mới
  Future<void> addExpense(SplitExpense expense) async {
    await _firestore
        .collection('split_groups')
        .doc(expense.groupId)
        .collection('expenses')
        .doc(expense.id)
        .set(expense.toMap());
  }

  // 7. Xóa chi tiêu
  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _firestore
        .collection('split_groups')
        .doc(groupId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  // 8. Stream danh sách chi tiêu của nhóm
  Stream<List<SplitExpense>> watchExpenses(String groupId) {
    return _firestore
        .collection('split_groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SplitExpense.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // 9. Ghi nhận thanh toán ("Tôi đã trả")
  Future<void> markAsPaid(SplitPayment payment) async {
    await _firestore
        .collection('split_groups')
        .doc(payment.groupId)
        .collection('payments')
        .doc(payment.id)
        .set(payment.toMap());
  }

  // 10. Xác nhận đã nhận tiền
  Future<void> confirmPayment(String groupId, String paymentId, String confirmerUid) async {
    await _firestore
        .collection('split_groups')
        .doc(groupId)
        .collection('payments')
        .doc(paymentId)
        .update({
          'confirmedByToUid': confirmerUid,
        });
  }

  // 11. Stream danh sách thanh toán của nhóm
  Stream<List<SplitPayment>> watchPayments(String groupId) {
    return _firestore
        .collection('split_groups')
        .doc(groupId)
        .collection('payments')
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SplitPayment.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // 12. Chốt nhóm (Quyết toán xong, không cho chỉnh sửa nữa)
  Future<void> settleGroup(String groupId) async {
    await _firestore.collection('split_groups').doc(groupId).update({
      'status': SplitGroupStatus.settled.name,
    });
  }

  // 13. Lấy thông tin chi tiết user theo UID
  Future<SplitMemberInfo?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return SplitMemberInfo.fromMap(doc.data()!);
  }

  // 14. Tính toán nợ nần tối ưu (Greedy Debt Simplification rounded to 1000 VND)
  static List<SplitDebt> calculateDebts(List<SplitExpense> expenses, List<String> memberUids) {
    if (memberUids.isEmpty) return [];

    final Map<String, double> netBalances = { for (var uid in memberUids) uid: 0.0 };
    
    for (final expense in expenses) {
      final payer = expense.paidByUid;
      if (netBalances.containsKey(payer)) {
        netBalances[payer] = netBalances[payer]! + expense.amount;
      }
      expense.shares.forEach((uid, share) {
        if (netBalances.containsKey(uid)) {
          netBalances[uid] = netBalances[uid]! - share;
        }
      });
    }

    // Làm tròn mỗi balance về bội số của 1000 gần nhất
    final Map<String, double> roundedBalances = {};
    double sum = 0;
    netBalances.forEach((uid, balance) {
      final rounded = (balance / 1000.0).roundToDouble() * 1000.0;
      roundedBalances[uid] = rounded;
      sum += rounded;
    });

    // Bù trừ chênh lệch làm tròn để tổng balance vẫn bằng 0
    if (sum != 0) {
      String? bestUid;
      double maxDiscrepancy = -1;
      netBalances.forEach((uid, rawBal) {
        final roundedBal = roundedBalances[uid]!;
        final discrepancy = (rawBal - roundedBal).abs();
        if (discrepancy > maxDiscrepancy) {
          maxDiscrepancy = discrepancy;
          bestUid = uid;
        }
      });
      if (bestUid != null) {
        roundedBalances[bestUid!] = roundedBalances[bestUid]! - sum;
      }
    }

    // Phân loại con nợ (bal < 0) và chủ nợ (bal > 0)
    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];

    roundedBalances.forEach((uid, bal) {
      if (bal < -0.1) {
        debtors.add(MapEntry(uid, bal));
      } else if (bal > 0.1) {
        creditors.add(MapEntry(uid, bal));
      }
    });

    // Sắp xếp giảm dần/tăng dần để khớp nợ tham lam
    debtors.sort((a, b) => a.value.compareTo(b.value)); // nợ nhiều nhất lên trước
    creditors.sort((a, b) => b.value.compareTo(a.value)); // chủ nợ nhiều nhất lên trước

    final List<SplitDebt> debts = [];
    int debtorIdx = 0;
    int creditorIdx = 0;

    while (debtorIdx < debtors.length && creditorIdx < creditors.length) {
      final debtor = debtors[debtorIdx];
      final creditor = creditors[creditorIdx];

      final debtorOwed = -debtor.value;
      final creditorCredit = creditor.value;

      final amount = debtorOwed < creditorCredit ? debtorOwed : creditorCredit;

      if (amount >= 1000) {
        debts.add(SplitDebt(
          fromUid: debtor.key,
          toUid: creditor.key,
          amount: amount,
        ));
      }

      debtors[debtorIdx] = MapEntry(debtor.key, debtor.value + amount);
      creditors[creditorIdx] = MapEntry(creditor.key, creditor.value - amount);

      if (debtors[debtorIdx].value.abs() < 0.1) {
        debtorIdx++;
      }
      if (creditors[creditorIdx].value.abs() < 0.1) {
        creditorIdx++;
      }
    }

    return debts;
  }
}
