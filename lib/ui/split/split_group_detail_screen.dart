import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../domain/model/split_group.dart';
import '../../domain/model/split_expense.dart';
import '../../domain/model/split_payment.dart';
import '../../domain/model/split_debt.dart';
import '../../domain/model/split_member_info.dart';
import '../providers/split_provider.dart';
import '../providers/auth_provider.dart';
import 'add_expense_sheet.dart';

class SplitGroupDetailScreen extends StatefulWidget {
  final String groupId;

  const SplitGroupDetailScreen({super.key, required this.groupId});

  @override
  State<SplitGroupDetailScreen> createState() => _SplitGroupDetailScreenState();
}

class _SplitGroupDetailScreenState extends State<SplitGroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update floatingActionButton visibility
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SplitProvider>().openGroup(widget.groupId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    // Đóng listener và reset state của nhóm khi thoát
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SplitProvider>().closeGroup();
    });
    super.dispose();
  }

  void _showAddExpenseSheet(SplitGroup group) {
    if (group.status == SplitGroupStatus.settled) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(group: group),
    );
  }

  Future<void> _settleGroup(SplitProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc nhóm chia tiền?'),
        content: const Text(
          'Sau khi kết thúc, tất cả các thành viên sẽ không thể thêm khoản chi mới hoặc thay đổi trạng thái quyết toán nữa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.settleGroup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đóng nhóm chia tiền thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _markDebtAsPaid(SplitProvider provider, SplitDebt debt) async {
    final fromName = provider.membersCache[debt.fromUid]?.displayName ?? 'Thành viên';
    final toName = provider.membersCache[debt.toUid]?.displayName ?? 'Thành viên';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thanh toán?'),
        content: Text(
          'Đánh dấu đã trả cho khoản nợ: $fromName trả cho $toName số tiền ${_currencyFormat.format(debt.amount)}?\n'
          '(Trạng thái sẽ chuyển thành "Chờ xác nhận" cho đến khi bên nhận bấm đồng ý)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tôi đã trả'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.payDebt(widget.groupId, debt.fromUid, debt.toUid, debt.amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi yêu cầu xác nhận trả ${_currencyFormat.format(debt.amount)}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _confirmPayment(SplitProvider provider, SplitPayment payment) async {
    final fromName = provider.membersCache[payment.fromUid]?.displayName ?? 'Thành viên';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận nhận tiền?'),
        content: Text(
          'Bạn xác nhận đã nhận đủ số tiền ${_currencyFormat.format(payment.amount)} từ $fromName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.confirmPayment(payment.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận thanh toán!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _addMemberDirect(SplitProvider provider) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    final error = await provider.addMemberByEmail(widget.groupId, email);
    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm thành viên thành công!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Widget _buildAvatar(SplitMemberInfo? info, {double radius = 20}) {
    if (info != null && info.photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(info.photoUrl),
      );
    }
    final char = info != null && info.displayName.isNotEmpty
        ? info.displayName[0].toUpperCase()
        : 'U';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEDF2FF),
      child: Text(
        char,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF4F46E5),
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final splitProvider = context.watch<SplitProvider>();
    final group = splitProvider.activeGroup;
    final currentUserId = context.watch<AuthProvider>().currentUser?.uid ?? '';

    if (group == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isSettled = group.status == SplitGroupStatus.settled;
    final isOwner = group.createdByUid == currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF6D28D9),
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 62),
                title: Text(
                  group.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6D28D9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -10,
                        child: Icon(
                          LucideIcons.users,
                          size: 150,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 96,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSettled
                                ? Colors.white.withOpacity(0.25)
                                : Colors.amber.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSettled
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.amber.withOpacity(0.6),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSettled ? LucideIcons.lock : LucideIcons.unlock,
                                size: 12,
                                color: isSettled ? Colors.white : Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSettled ? 'ĐÃ KHÓA NHÓM' : 'ĐANG HOẠT ĐỘNG',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isSettled ? Colors.white : Colors.amber,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (!isSettled && isOwner && splitProvider.currentDebts.isEmpty)
                  IconButton(
                    onPressed: () => _settleGroup(splitProvider),
                    icon: const Icon(LucideIcons.checkCircle),
                    tooltip: 'Kết thúc nhóm',
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF6D28D9),
                    labelColor: const Color(0xFF6D28D9),
                    unselectedLabelColor: const Color(0xFF94A3B8),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    tabs: const [
                      Tab(text: 'CHI TIÊU'),
                      Tab(text: 'QUYẾT TOÁN'),
                      Tab(text: 'THÀNH VIÊN'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildExpensesTab(group, splitProvider, currentUserId),
            _buildSettlementTab(group, splitProvider, currentUserId),
            _buildMembersTab(group, splitProvider, isOwner, currentUserId),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0 && !isSettled
          ? FloatingActionButton(
              onPressed: () => _showAddExpenseSheet(group),
              backgroundColor: const Color(0xFF6D28D9),
              foregroundColor: Colors.white,
              child: const Icon(LucideIcons.plus),
            )
          : null,
    );
  }

  // 1. Tab Chi tiêu
  Widget _buildExpensesTab(SplitGroup group, SplitProvider provider, String currentUserId) {
    final expenses = provider.currentExpenses;

    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.receipt, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Chưa có khoản chi nào',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              if (group.status == SplitGroupStatus.active)
                const Text(
                  'Nhấn nút "+" bên dưới để bắt đầu ghi nhận các khoản chi tiêu chung.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(expense.createdAt);
        final payerInfo = provider.membersCache[expense.paidByUid];
        final payerName = payerInfo?.displayName ?? 'Thành viên';
        
        // Chỉ cho phép người tạo chi tiêu hoặc chủ nhóm xóa chi tiêu
        final canDelete = (expense.createdByUid == currentUserId || group.createdByUid == currentUserId) && !isSettled(group);

        Widget cardContent = Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: _buildAvatar(payerInfo),
            title: Text(
              expense.description,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Trả bởi: $payerName',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currencyFormat.format(expense.amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (canDelete)
                  IconButton(
                    onPressed: () => provider.deleteExpense(expense.id),
                    icon: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444), size: 18),
                  ),
              ],
            ),
          ),
        );

        if (canDelete) {
          return Dismissible(
            key: Key(expense.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(LucideIcons.trash2, color: Colors.white),
            ),
            onDismissed: (_) {
              provider.deleteExpense(expense.id);
            },
            child: cardContent,
          );
        }

        return cardContent;
      },
    );
  }

  bool isSettled(SplitGroup group) => group.status == SplitGroupStatus.settled;

  // 2. Tab Quyết toán
  Widget _buildSettlementTab(SplitGroup group, SplitProvider provider, String currentUserId) {
    final debts = provider.currentDebts;
    final payments = provider.currentPayments;
    final isGroupClosed = group.status == SplitGroupStatus.settled;

    // Tính toán tổng quan tài chính của nhóm
    final totalSpent = provider.getGroupTotalSpent(group.id);
    final averageSpent = group.memberUids.isNotEmpty ? totalSpent / group.memberUids.length : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Báo cáo nhanh
          Card(
            elevation: 0,
            color: const Color(0xFFEDF2FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFD0E0FF), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng chi tiêu nhóm:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      Text(_currencyFormat.format(totalSpent), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF4F46E5))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Trung bình mỗi người:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      Text(_currencyFormat.format(averageSpent), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF4F46E5))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Banner hoàn thành quyết toán
          if (debts.isEmpty && payments.every((p) => p.confirmedByToUid != null))
            Card(
              elevation: 0,
              color: const Color(0xFFF0FDF4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFBBF7D0), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(LucideIcons.smile, size: 48, color: Color(0xFF10B981)),
                    const SizedBox(height: 12),
                    const Text(
                      'Tất cả đã quyết toán xong! 🎉',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Nhóm này không còn nợ nần gì nữa.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                    ),
                    if (group.createdByUid == currentUserId && !isGroupClosed) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _settleGroup(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Kết thúc & Khóa nhóm'),
                      ),
                    ]
                  ],
                ),
              ),
            ),

          // Danh sách công nợ chưa trả
          if (debts.isNotEmpty) ...[
            const Text(
              'Danh sách nợ cần trả',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            ...debts.map((debt) {
              final fromInfo = provider.membersCache[debt.fromUid];
              final toInfo = provider.membersCache[debt.toUid];
              final fromName = fromInfo?.displayName ?? 'Thành viên';
              final toName = toInfo?.displayName ?? 'Thành viên';

              // Tìm xem đã có giao dịch chuyển khoản nào đang chờ duyệt hay chưa
              final pendingPayment = payments.firstWhere(
                (p) => p.fromUid == debt.fromUid && p.toUid == debt.toUid && p.confirmedByToUid == null,
                orElse: () => SplitPayment(id: '', groupId: '', fromUid: '', toUid: '', amount: 0, paidAt: DateTime.now()),
              );
              final hasPending = pendingPayment.id.isNotEmpty;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _buildAvatar(fromInfo, radius: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    fromName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Column(
                              children: [
                                Text(
                                  _currencyFormat.format(debt.amount),
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                                ),
                                const Icon(LucideIcons.arrowRight, size: 16, color: Color(0xFF94A3B8)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    toName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildAvatar(toInfo, radius: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (hasPending)
                        if (currentUserId == debt.toUid)
                          ElevatedButton.icon(
                            onPressed: () => _confirmPayment(provider, pendingPayment),
                            icon: const Icon(LucideIcons.checkSquare, size: 16),
                            label: const Text('Xác nhận đã nhận tiền'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              'Đang chờ xác nhận từ $toName',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          )
                      else if (currentUserId == debt.fromUid)
                        OutlinedButton.icon(
                          onPressed: isGroupClosed ? null : () => _markDebtAsPaid(provider, debt),
                          icon: const Icon(LucideIcons.send, size: 16),
                          label: const Text('Tôi đã trả'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6D28D9),
                            side: const BorderSide(color: Color(0xFF6D28D9)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 40),
                          ),
                        )
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 24),

          // Lịch sử chuyển tiền/thanh toán
          if (payments.isNotEmpty) ...[
            const Text(
              'Lịch sử thanh toán',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            ...payments.map((payment) {
              final fromName = provider.membersCache[payment.fromUid]?.displayName ?? 'Thành viên';
              final toName = provider.membersCache[payment.toUid]?.displayName ?? 'Thành viên';
              final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(payment.paidAt);
              final isConfirmed = payment.confirmedByToUid != null;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFF1F5F9)),
                ),
                color: isConfirmed ? Colors.white : const Color(0xFFFFFBEB),
                child: ListTile(
                  dense: true,
                  title: Text(
                    '$fromName trả cho $toName',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  subtitle: Text(
                    '$dateStr${isConfirmed ? " • Đã xác nhận" : " • Chờ xác nhận"}',
                    style: TextStyle(color: isConfirmed ? const Color(0xFF64748B) : const Color(0xFFD97706), fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    _currencyFormat.format(payment.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isConfirmed ? const Color(0xFF10B981) : const Color(0xFFD97706),
                    ),
                  ),
                ),
              );
            }),
          ]
        ],
      ),
    );
  }

  // 3. Tab Thành viên
  Widget _buildMembersTab(SplitGroup group, SplitProvider provider, bool isOwner, String currentUserId) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thêm thành viên trực tiếp
          if (!isSettled(group)) ...[
            const Text(
              'Thêm thành viên bằng Email',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Nhập email...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                      ),
                      prefixIcon: const Icon(LucideIcons.mail, size: 16, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addMemberDirect(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  child: const Text('Thêm'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          const Text(
            'Thành viên nhóm',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),

          // Danh sách thành viên
          ...group.memberUids.map((uid) {
            final memberInfo = provider.membersCache[uid];
            final name = memberInfo?.displayName ?? 'Thành viên';
            final email = memberInfo?.email ?? '';
            final isCreator = uid == group.createdByUid;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFF1F5F9)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildAvatar(memberInfo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isCreator) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Trưởng nhóm',
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (isOwner && uid != currentUserId && !isSettled(group)) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.userMinus,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Xóa thành viên?'),
                              content: Text(
                                'Bạn có chắc chắn muốn xóa $name khỏi nhóm?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Hủy'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                  ),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.removeMember(group.id, uid);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
