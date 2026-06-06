import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/repository/finance_repository.dart';
import '../../domain/model/transaction_model.dart';
import '../../domain/model/wallet_model.dart';
import '../../domain/model/split_group.dart';
import '../../domain/model/split_expense.dart';
import '../../domain/model/split_payment.dart';
import '../../domain/model/split_debt.dart';
import '../../domain/model/split_member_info.dart';
import '../../domain/model/notification_model.dart';
import '../../services/split_service.dart';
import '../../services/notification_service.dart';
import 'auth_provider.dart';

class SplitProvider extends ChangeNotifier {
  final FinanceRepository _financeRepository;
  final AuthProvider _authProvider;
  final _uuid = const Uuid();

  List<SplitGroup> _myGroups = [];
  SplitGroup? _activeGroup;
  List<SplitExpense> _currentExpenses = [];
  List<SplitPayment> _currentPayments = [];
  List<SplitDebt> _currentDebts = [];
  final Map<String, SplitMemberInfo> _membersCache = {};
  final Map<String, double> _groupTotalSpent = {};

  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<List<SplitGroup>>? _groupsSub;
  StreamSubscription<List<SplitExpense>>? _expensesSub;
  StreamSubscription<List<SplitPayment>>? _paymentsSub;

  List<SplitExpense> _previousExpenses = [];
  List<SplitPayment> _previousPayments = [];

  SplitProvider(this._financeRepository, this._authProvider) {
    _authProvider.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  // Getters
  List<SplitGroup> get myGroups => _myGroups;
  SplitGroup? get activeGroup => _activeGroup;
  List<SplitExpense> get currentExpenses => _currentExpenses;
  List<SplitPayment> get currentPayments => _currentPayments;
  List<SplitDebt> get currentDebts => _currentDebts;
  Map<String, SplitMemberInfo> get membersCache => _membersCache;
  double getGroupTotalSpent(String groupId) => _groupTotalSpent[groupId] ?? 0.0;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get _currentUserId => _authProvider.currentUser?.uid ?? '';

  void _onAuthChanged() {
    if (_authProvider.isAuthenticated) {
      listenToMyGroups(_currentUserId);
    } else {
      _cleanup();
    }
  }

  void _cleanup() {
    _groupsSub?.cancel();
    _expensesSub?.cancel();
    _paymentsSub?.cancel();
    _myGroups = [];
    _activeGroup = null;
    _currentExpenses = [];
    _currentPayments = [];
    _currentDebts = [];
    _previousExpenses = [];
    _previousPayments = [];
    _membersCache.clear();
    _groupTotalSpent.clear();
  }

  // 1. Lắng nghe danh sách nhóm của user
  void listenToMyGroups(String uid) {
    _groupsSub?.cancel();
    _groupsSub = SplitService.instance
        .watchMyGroups(uid)
        .listen(
          (groups) {
            _myGroups = groups;

            // Nếu đang mở nhóm, cập nhật thông tin nhóm theo real-time
            if (_activeGroup != null) {
              final updatedActive = groups.firstWhere(
                (g) => g.id == _activeGroup!.id,
                orElse: () => _activeGroup!,
              );
              if (updatedActive != _activeGroup) {
                _activeGroup = updatedActive;
                _resolveMembers(updatedActive.memberUids);
              }
            }

            // Tải trước thông tin thành viên của tất cả các nhóm để hiển thị mượt mà
            // Đồng thời tải tổng chi tiêu của mỗi nhóm
            for (final g in groups) {
              _resolveMembers(g.memberUids);
              _fetchGroupTotalSpent(g.id);
            }

            notifyListeners();
          },
          onError: (e) {
            _errorMessage = 'Lỗi kết nối nhóm: $e';
            notifyListeners();
          },
        );
  }

  Future<void> _fetchGroupTotalSpent(String groupId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('split_groups')
          .doc(groupId)
          .collection('expenses')
          .get();
      final total = querySnapshot.docs.fold<double>(
        0.0,
        (sum, doc) => sum + ((doc.data()['amount'] as num?)?.toDouble() ?? 0.0),
      );
      _groupTotalSpent[groupId] = total;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching total spent for group $groupId: $e');
    }
  }

  // 2. Mở một nhóm để hiển thị chi tiết (lắng nghe chi tiêu, thanh toán)
  Future<void> openGroup(String groupId) async {
    _expensesSub?.cancel();
    _paymentsSub?.cancel();

    _activeGroup = _myGroups.firstWhere((g) => g.id == groupId);
    _currentExpenses = [];
    _currentPayments = [];
    _currentDebts = [];
    _previousExpenses = [];
    _previousPayments = [];

    // Tải profile các thành viên
    await _resolveMembers(_activeGroup!.memberUids);
    notifyListeners();

    // Lắng nghe chi tiêu
    _expensesSub = SplitService.instance.watchExpenses(groupId).listen((
      expenses,
    ) {
      // So sánh để phát hiện chi tiêu mới và push notification
      if (_previousExpenses.isNotEmpty) {
        for (final exp in expenses) {
          final exists = _previousExpenses.any((e) => e.id == exp.id);
          if (!exists && exp.createdByUid != _currentUserId) {
            _triggerPush(
              title: 'Khoản chi tiêu mới 💸',
              body:
                  'Thành viên ${_displayName(exp.paidByUid)} đã thêm "${exp.description}" số tiền ${_formatMoney(exp.amount)}.',
              relatedId: groupId,
            );
          }
        }
      }
      _previousExpenses = List.from(expenses);
      _currentExpenses = expenses;
      _recalculateDebts();
      notifyListeners();
    });

    // Lắng nghe thanh toán
    _paymentsSub = SplitService.instance.watchPayments(groupId).listen((
      payments,
    ) {
      if (_previousPayments.isNotEmpty) {
        for (final pay in payments) {
          final oldPayIdx = _previousPayments.indexWhere((p) => p.id == pay.id);

          if (oldPayIdx == -1) {
            // Thanh toán mới được ghi nhận
            if (pay.fromUid != _currentUserId && pay.toUid == _currentUserId) {
              _triggerPush(
                title: 'Yêu cầu xác nhận nhận tiền 💰',
                body:
                    'Thành viên ${_displayName(pay.fromUid)} đã gửi ${_formatMoney(pay.amount)} cho bạn. Vui lòng xác nhận.',
                relatedId: groupId,
              );
            }
          } else {
            // Thanh toán cũ thay đổi (ví dụ: chuyển từ chờ xác nhận sang đã nhận)
            final oldPay = _previousPayments[oldPayIdx];
            if (oldPay.confirmedByToUid == null &&
                pay.confirmedByToUid != null) {
              if (pay.fromUid == _currentUserId) {
                _triggerPush(
                  title: 'Thanh toán được xác nhận! ✅',
                  body:
                      'Thành viên ${_displayName(pay.toUid)} đã xác nhận nhận được ${_formatMoney(pay.amount)} từ bạn.',
                  relatedId: groupId,
                );
              }
            }
          }
        }
      }
      _previousPayments = List.from(payments);
      _currentPayments = payments;
      _recalculateDebts();
      notifyListeners();
    });
  }

  void closeGroup() {
    _expensesSub?.cancel();
    _paymentsSub?.cancel();
    _activeGroup = null;
    _currentExpenses = [];
    _currentPayments = [];
    _currentDebts = [];
    _previousExpenses = [];
    _previousPayments = [];
    notifyListeners();
  }

  // 3. Tính toán lại công nợ sau khi khấu trừ các khoản thanh toán ĐÃ XÁC NHẬN
  void _recalculateDebts() {
    if (_activeGroup == null) return;

    // Lấy danh sách nợ gốc từ các chi tiêu trong nhóm
    final rawDebts = SplitService.calculateDebts(
      _currentExpenses,
      _activeGroup!.memberUids,
    );

    final List<SplitDebt> adjustedDebts = [];

    for (final debt in rawDebts) {
      // Tìm các khoản thanh toán giữa 2 người này trong nhóm
      final paymentsBetween = _currentPayments.where(
        (p) => p.fromUid == debt.fromUid && p.toUid == debt.toUid,
      );

      // Tính tổng số tiền đã trả (đã được xác nhận)
      final confirmedPaid = paymentsBetween
          .where((p) => p.confirmedByToUid != null)
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      final remaining = debt.amount - confirmedPaid;
      if (remaining >= 1000) {
        adjustedDebts.add(
          SplitDebt(
            fromUid: debt.fromUid,
            toUid: debt.toUid,
            amount: remaining,
          ),
        );
      }
    }

    _currentDebts = adjustedDebts;
  }

  // 4. Lấy profile các thành viên và cache lại
  Future<void> _resolveMembers(List<String> uids) async {
    for (final uid in uids) {
      if (!_membersCache.containsKey(uid) && uid.isNotEmpty) {
        final info = await SplitService.instance.getUserProfile(uid);
        if (info != null) {
          _membersCache[uid] = info;
        }
      }
    }
  }

  String _displayName(String uid) {
    return _membersCache[uid]?.displayName ?? 'Thành viên';
  }

  String _formatMoney(double amount) {
    return '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} ₫';
  }

  // Gửi thông báo local
  void _triggerPush({
    required String title,
    required String body,
    required String relatedId,
  }) {
    NotificationService.instance.sendNotification(
      userId: _currentUserId,
      title: title,
      body: body,
      relatedId: relatedId,
      type: NotificationType.transactionExpense,
    );
  }

  // 5. Thêm nhóm mới
  Future<void> createGroup(String name, String description) async {
    if (_currentUserId.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = _uuid.v4();
      final newGroup = SplitGroup(
        id: id,
        name: name,
        description: description,
        createdAt: DateTime.now(),
        createdByUid: _currentUserId,
        status: SplitGroupStatus.active,
        memberUids: [_currentUserId],
      );

      await SplitService.instance.createGroup(newGroup);
    } catch (e) {
      _errorMessage = 'Lỗi tạo nhóm: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 6. Thêm thành viên bằng email
  Future<String?> addMemberByEmail(String groupId, String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final error = await SplitService.instance.addMemberByEmail(
        groupId,
        email,
      );
      if (error == null) {
        final member = await SplitService.instance.findUserByEmail(email);
        if (member != null) {
          _membersCache[member.uid] = member;

          // Gửi thông báo cho chính mình rằng đã thêm thành viên thành công
          _triggerPush(
            title: 'Thêm thành viên nhóm 👥',
            body: 'Thành viên ${member.displayName} đã được thêm vào nhóm.',
            relatedId: groupId,
          );
        }
      }
      return error;
    } catch (e) {
      return 'Lỗi thêm thành viên: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 7. Xóa thành viên
  Future<void> removeMember(String groupId, String uid) async {
    try {
      await SplitService.instance.removeMember(groupId, uid);
    } catch (e) {
      _errorMessage = 'Lỗi xóa thành viên: $e';
      notifyListeners();
    }
  }

  // 8. Thêm chi tiêu
  Future<void> addExpense(SplitExpense expense) async {
    if (_activeGroup?.status == SplitGroupStatus.settled) return;

    try {
      await SplitService.instance.addExpense(expense);
    } catch (e) {
      _errorMessage = 'Lỗi thêm chi tiêu: $e';
      notifyListeners();
    }
  }

  // 9. Xóa chi tiêu
  Future<void> deleteExpense(String expenseId) async {
    if (_activeGroup == null) return;
    if (_activeGroup!.status == SplitGroupStatus.settled) return;

    try {
      await SplitService.instance.deleteExpense(_activeGroup!.id, expenseId);
    } catch (e) {
      _errorMessage = 'Lỗi xóa chi tiêu: $e';
      notifyListeners();
    }
  }

  // 10. Ghi nhận thanh toán ("Tôi đã trả")
  Future<void> payDebt(
    String groupId,
    String fromUid,
    String toUid,
    double amount,
  ) async {
    if (_activeGroup?.status == SplitGroupStatus.settled) return;

    try {
      final paymentId = _uuid.v4();
      final newPayment = SplitPayment(
        id: paymentId,
        groupId: groupId,
        fromUid: fromUid,
        toUid: toUid,
        amount: amount,
        paidAt: DateTime.now(),
        confirmedByToUid: null, // Chờ xác nhận từ đầu nhận
      );

      await SplitService.instance.markAsPaid(newPayment);

      // Nếu người gửi tiền là tôi, tự động ghi nhận giao dịch cá nhân dạng chi tiêu
      if (fromUid == _currentUserId) {
        await _logPersonalTransaction(amount, toUid);
      }
    } catch (e) {
      _errorMessage = 'Lỗi thanh toán: $e';
      notifyListeners();
    }
  }

  // Ghi nhận giao dịch cá nhân trong sổ sách chi tiêu
  Future<void> _logPersonalTransaction(
    double amount,
    String recipientUid,
  ) async {
    try {
      final walletsRaw = await _financeRepository.getWalletsByUserId(
        _currentUserId,
      );
      final wallets = walletsRaw.map((w) => WalletModel.fromMap(w)).toList();

      final wallet = wallets.firstWhere(
        (w) => w.isDefault,
        orElse: () => wallets.isNotEmpty
            ? wallets.first
            : WalletModel(
                id: 'default',
                userId: _currentUserId,
                name: 'Ví mặc định',
                balance: 0.0,
              ),
      );

      final recipientName = _displayName(recipientUid);
      final tx = TransactionModel(
        id: '',
        userId: _currentUserId,
        walletId: wallet.id,
        categoryId: 'split_bill',
        categoryName: 'Chia tiền nhóm',
        type: 'expense',
        amount: amount,
        note:
            'Quyết toán trả tiền cho $recipientName (Nhóm: ${_activeGroup?.name ?? ""})',
        transactionDate: DateTime.now(),
      );

      await _financeRepository.upsertTransaction(tx);
    } catch (e) {
      debugPrint('Lỗi tự động tạo giao dịch cá nhân: $e');
    }
  }

  // 11. Xác nhận đã nhận tiền
  Future<void> confirmPayment(String paymentId) async {
    if (_activeGroup == null) return;
    if (_activeGroup!.status == SplitGroupStatus.settled) return;

    try {
      final paymentIndex = _currentPayments.indexWhere((p) => p.id == paymentId);
      SplitPayment? payment;
      if (paymentIndex != -1) {
        payment = _currentPayments[paymentIndex];
      }

      await SplitService.instance.confirmPayment(
        _activeGroup!.id,
        paymentId,
        _currentUserId,
      );

      // Nếu nhận tiền thành công và tôi là người nhận (chủ nợ), tự động ghi nhận giao dịch thu nhập cá nhân
      if (payment != null && payment.toUid == _currentUserId) {
        await _logPersonalIncomeTransaction(payment.amount, payment.fromUid);
      }
    } catch (e) {
      _errorMessage = 'Lỗi xác nhận nhận tiền: $e';
      notifyListeners();
    }
  }

  // Ghi nhận giao dịch cá nhân dạng thu nhập khi nhận tiền quyết toán
  Future<void> _logPersonalIncomeTransaction(
    double amount,
    String senderUid,
  ) async {
    try {
      final walletsRaw = await _financeRepository.getWalletsByUserId(
        _currentUserId,
      );
      final wallets = walletsRaw.map((w) => WalletModel.fromMap(w)).toList();

      final wallet = wallets.firstWhere(
        (w) => w.isDefault,
        orElse: () => wallets.isNotEmpty
            ? wallets.first
            : WalletModel(
                id: 'default',
                userId: _currentUserId,
                name: 'Ví mặc định',
                balance: 0.0,
              ),
      );

      final senderName = _displayName(senderUid);
      final tx = TransactionModel(
        id: '',
        userId: _currentUserId,
        walletId: wallet.id,
        categoryId: 'split_bill',
        categoryName: 'Chia tiền nhóm',
        type: 'income',
        amount: amount,
        note:
            'Quyết toán nhận tiền từ $senderName (Nhóm: ${_activeGroup?.name ?? ""})',
        transactionDate: DateTime.now(),
      );

      await _financeRepository.upsertTransaction(tx);
    } catch (e) {
      debugPrint('Lỗi tự động tạo giao dịch thu nhập cá nhân: $e');
    }
  }

  // 12. Chốt nhóm (Kết thúc nhóm)
  Future<void> settleGroup() async {
    if (_activeGroup == null) return;
    try {
      await SplitService.instance.settleGroup(_activeGroup!.id);

      _triggerPush(
        title: 'Nhóm đã tất toán! 🏁',
        body:
            'Nhóm "${_activeGroup!.name}" đã hoàn thành tất toán và được đóng.',
        relatedId: _activeGroup!.id,
      );
    } catch (e) {
      _errorMessage = 'Lỗi đóng nhóm: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _cleanup();
    super.dispose();
  }
}
