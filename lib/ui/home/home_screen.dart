import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/ai_chat/chatbot.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/all_overview_screen.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/budget_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/transaction/transaction_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  static HomePageState? _activeInstance;

  final FinanceRepository _financeRepository = FinanceRepository();
  StreamSubscription<void>? _transactionChangedSubscription;
  final ScrollController _scrollController = ScrollController();
  bool _isBalanceVisible = true;

  static void scrollToTopActive() {
    _activeInstance?.scrollToTop();
  }

  Future<void> _reloadHomeData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'user_001';
    final currentDate = DateTime.now();

    await context.read<FinanceProvider>().refreshFinancialSummary(userId);
    await context.read<BudgetProvider>().loadMonthlyBudgets(
      userId,
      currentDate.month,
      currentDate.year,
    );
  }

  @override
  void initState() {
    super.initState();
    _activeInstance = this;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadHomeData();

      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'user_001';
      _transactionChangedSubscription = _financeRepository
          .watchTransactions(userId)
          .listen((_) {
            if (mounted) {
              _reloadHomeData();
            }
          });
    });
  }

  @override
  void dispose() {
    _transactionChangedSubscription?.cancel();
    _scrollController.dispose();
    if (_activeInstance == this) {
      _activeInstance = null;
    }
    super.dispose();
  }

  void scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,###', 'vi_VN');
    final user = FirebaseAuth.instance.currentUser;
    final String fullName =
        (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : 'Bạn';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Consumer2<FinanceProvider, BudgetProvider>(
        builder: (context, financeProvider, budgetProvider, _) {
          final recentTransactions = financeProvider.recentTransactions
              .take(5)
              .toList();
          final chartData = _buildMonthlySeries(
            financeProvider.recentTransactions,
          );
          final budgets = budgetProvider.budgets.take(3).toList();

          final displayBalance = _isBalanceVisible
              ? '${currency.format(financeProvider.cashBalance)} đ'
              : '••••••••';
          final displayIncome = _isBalanceVisible
              ? '${currency.format(financeProvider.totalIncome)} đ'
              : '••••••';
          final displayExpense = _isBalanceVisible
              ? '${currency.format(financeProvider.totalExpense)} đ'
              : '••••••';

          return RefreshIndicator(
            onRefresh: _reloadHomeData,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 124),
              children: [
                _buildHeader(
                  context,
                  fullName: fullName,
                  displayBalance: displayBalance,
                  displayIncome: displayIncome,
                  displayExpense: displayExpense,
                ),
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildCashflowCard(chartData),
                        const SizedBox(height: 12),
                        _buildAiPreview(context),
                        const SizedBox(height: 12),
                        _buildBudgetCard(
                          context,
                          budgets,
                          budgetProvider.isLoading,
                          currency,
                        ),
                        const SizedBox(height: 12),
                        _buildRecentTransactions(
                          context,
                          recentTransactions,
                          currency,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String fullName,
    required String displayBalance,
    required String displayIncome,
    required String displayExpense,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -52,
            left: 40,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 56),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin chào,',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$fullName 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 21,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.wifi_rounded,
                              color: Color(0xFF86EFAC),
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Online',
                              style: TextStyle(
                                color: Color(0xFF86EFAC),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Số dư khả dụng',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayBalance,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 31,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => setState(
                          () => _isBalanceVisible = !_isBalanceVisible,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _isBalanceVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MM/yyyy').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _headerStatCard(
                          icon: Icons.trending_up_rounded,
                          iconColor: const Color(0xFF86EFAC),
                          label: 'Thu nhập',
                          value: displayIncome,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _headerStatCard(
                          icon: Icons.trending_down_rounded,
                          iconColor: const Color(0xFFFCA5A5),
                          label: 'Chi tiêu',
                          value: displayExpense,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowCard(List<_MonthlyCashflow> chartData) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thu - Chi 6 tháng',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _legendDot(const Color(0xFF3B82F6), 'Thu'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFFF87171), 'Chi'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: 0,
                lineTouchData: LineTouchData(enabled: true),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFE5E7EB), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= chartData.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            chartData[index].label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < chartData.length; i++)
                        FlSpot(i.toDouble(), chartData[i].income),
                    ],
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF3B82F6).withValues(alpha: 0.28),
                          const Color(0xFF3B82F6).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < chartData.length; i++)
                        FlSpot(i.toDouble(), chartData[i].expense),
                    ],
                    isCurved: true,
                    color: const Color(0xFFF87171),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildAiPreview(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('🤖', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Financial Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Gợi ý tối ưu chi tiêu của bạn hôm nay',
                      style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFE9D5FF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    List<dynamic> budgets,
    bool isLoading,
    NumberFormat currency,
  ) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ngân sách tháng này',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllOverviewScreen(),
                    ),
                  );
                },
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (budgets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Bạn chưa thiết lập ngân sách.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            )
          else
            ...budgets.map((budget) {
              final spent = (budget.spentAmount as int).toDouble();
              final limit = (budget.limitAmount as int).toDouble();
              final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
              final progressColor = ratio >= 0.9
                  ? const Color(0xFFEF4444)
                  : ratio >= 0.7
                  ? const Color(0xFFF97316)
                  : const Color(0xFF22C55E);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          (budget.icon as String).isEmpty
                              ? '💰'
                              : budget.icon as String,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            budget.categoryName as String,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${currency.format(budget.spentAmount)} / ${currency.format(budget.limitAmount)} đ',
                          style: TextStyle(
                            fontSize: 11,
                            color: progressColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: ratio,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    List<TransactionModel> tx,
    NumberFormat currency,
  ) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Giao dịch gần đây',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const TransactionListPage(forceShowBackButton: true),
                    ),
                  );
                },
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tx.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Bạn chưa có giao dịch nào.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            )
          else
            ...tx.map((item) {
              final isExpense = item.type == 'expense';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isExpense
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.categoryName.isEmpty
                            ? '💸'
                            : item.categoryName.characters.first,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.note.isNotEmpty
                                ? item.note
                                : item.categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.categoryName} · ${DateFormat('dd/MM').format(item.transactionDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isExpense ? '-' : '+'}${currency.format(item.amount)} đ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isExpense
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  List<_MonthlyCashflow> _buildMonthlySeries(
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();
    final monthKeys = <String>[];
    final monthLabel = <String, String>{};

    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      monthKeys.add(key);
      monthLabel[key] = DateFormat('MM').format(d);
    }

    final incomeByMonth = <String, double>{for (final key in monthKeys) key: 0};
    final expenseByMonth = <String, double>{
      for (final key in monthKeys) key: 0,
    };

    for (final tx in transactions) {
      final key =
          '${tx.transactionDate.year}-${tx.transactionDate.month.toString().padLeft(2, '0')}';
      if (!incomeByMonth.containsKey(key)) continue;

      if (tx.type == 'income') {
        incomeByMonth[key] = (incomeByMonth[key] ?? 0) + tx.amount;
      } else {
        expenseByMonth[key] = (expenseByMonth[key] ?? 0) + tx.amount;
      }
    }

    return monthKeys
        .map(
          (key) => _MonthlyCashflow(
            label: monthLabel[key] ?? key,
            income: incomeByMonth[key] ?? 0,
            expense: expenseByMonth[key] ?? 0,
          ),
        )
        .toList();
  }
}

class _MonthlyCashflow {
  const _MonthlyCashflow({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final double income;
  final double expense;
}
