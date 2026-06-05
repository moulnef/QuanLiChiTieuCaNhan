import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_group.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_member.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_expense.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_debt.dart';
import '../providers/split_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _settleGroup(SplitGroup group) async {
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
      await context.read<SplitProvider>().updateGroupStatus(group.id, SplitGroupStatus.settled);
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

  Future<void> _markDebtAsPaid(SplitGroup group, SplitDebt debt) async {
    final fromMember = group.members.firstWhere((m) => m.id == debt.from);
    final toMember = group.members.firstWhere((m) => m.id == debt.to);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thanh toán?'),
        content: Text(
          'Đánh dấu đã trả cho khoản nợ: ${fromMember.name} trả cho ${toMember.name} số tiền ${_currencyFormat.format(debt.amount)}?',
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
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<SplitProvider>().settleDebt(group, debt, fromMember, toMember);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã ghi nhận thanh toán ${_currencyFormat.format(debt.amount)}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final splitProvider = context.watch<SplitProvider>();
    final groupIndex = splitProvider.groups.indexWhere((g) => g.id == widget.groupId);
    
    if (groupIndex == -1) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy nhóm này.')),
      );
    }

    final group = splitProvider.groups[groupIndex];
    final totalSpent = group.expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final isSettled = group.status == SplitGroupStatus.settled;

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
                          LucideIcons.wallet,
                          size: 150,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 96,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSettled
                                ? Colors.white.withValues(alpha: 0.25)
                                : Colors.amber.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSettled
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.amber.withValues(alpha: 0.6),
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
                if (!isSettled)
                  IconButton(
                    onPressed: () => _settleGroup(group),
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
            _buildExpensesTab(group),
            _buildSettlementTab(group, splitProvider),
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

  Widget _buildExpensesTab(SplitGroup group) {
    if (group.expenses.isEmpty) {
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

    final listExpenses = List<SplitExpense>.from(group.expenses)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: listExpenses.length,
      itemBuilder: (context, index) {
        final expense = listExpenses[index];
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(expense.createdAt);
        final payer = group.members.firstWhere((m) => m.id == expense.paidBy, orElse: () => SplitMember(id: '', name: 'Không rõ'));
        final isRepayment = expense.description.startsWith('Quyết toán:');

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: isRepayment ? const Color(0xFFF0FDF4) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isRepayment ? const Color(0xFFBBF7D0) : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isRepayment
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFF6D28D9).withValues(alpha: 0.1),
              child: Icon(
                isRepayment ? LucideIcons.check : LucideIcons.receipt,
                color: isRepayment ? const Color(0xFF10B981) : const Color(0xFF6D28D9),
                size: 20,
              ),
            ),
            title: Text(
              expense.description,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: const Color(0xFF1E293B),
                decoration: isRepayment ? TextDecoration.none : TextDecoration.none,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Trả bởi: ${payer.name}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            trailing: Text(
              _currencyFormat.format(expense.amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isRepayment ? const Color(0xFF10B981) : const Color(0xFF0F172A),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettlementTab(SplitGroup group, SplitProvider provider) {
    final debts = provider.calculateDebts(group);
    final isSettled = group.status == SplitGroupStatus.settled;

    if (debts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.smile, size: 48, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tất cả đã sòng phẳng!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Không còn khoản nợ nào cần thanh toán.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: debts.length,
      itemBuilder: (context, index) {
        final debt = debts[index];
        final fromMember = group.members.firstWhere((m) => m.id == debt.from);
        final toMember = group.members.firstWhere((m) => m.id == debt.to);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    // Debtor
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cần trả',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fromMember.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Arrow and amount indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Text(
                            _currencyFormat.format(debt.amount),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Icon(LucideIcons.arrowRight, color: Color(0xFFEF4444), size: 16),
                        ],
                      ),
                    ),
                    // Creditor
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Nhận từ',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            toMember.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isSettled ? null : () => _markDebtAsPaid(group, debt),
                    icon: const Icon(LucideIcons.checkSquare, size: 16),
                    label: const Text('Đánh dấu đã trả'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6D28D9),
                      side: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
