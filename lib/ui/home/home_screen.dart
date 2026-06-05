import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/category_data.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/ai_chat/chatbot.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/all_overview_screen.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/main_screen.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/budget_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/notification_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/notification/notification_screen.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/transaction/create_transaction_page.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/utils/app_localizer.dart';

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
  bool _isReloadingHomeData = false;

  static void scrollToTopActive() {
    _activeInstance?.scrollToTop();
  }

  Future<void> _reloadHomeData() async {
    if (_isReloadingHomeData) return;
    _isReloadingHomeData = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isReloadingHomeData = false;
      return;
    }
    final userId = user.uid;
    final currentDate = DateTime.now();

    try {
      await Future.wait([
        context.read<FinanceProvider>().refreshFinancialSummary(userId),
        context.read<BudgetProvider>().loadMonthlyBudgets(
          userId,
          currentDate.month,
          currentDate.year,
        ),
      ]);
    } finally {
      _isReloadingHomeData = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _activeInstance = this;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _reloadHomeData();

      if (!mounted) {
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }
      final userId = user.uid;

      // Trigger warnings check
      if (mounted) {
        context.read<NotificationProvider>().checkNewNotifications(userId);
      }

      _transactionChangedSubscription = _financeRepository
          .watchTransactions(userId)
          .listen((_) {
            if (mounted && !_isReloadingHomeData) {
              _reloadHomeData();
              context.read<NotificationProvider>().checkNewNotifications(
                userId,
              );
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
        : 'B\u1ea1n'.xtr(context);

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
              ? '${currency.format(financeProvider.cashBalance)} \u0111'
              : '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022';
          final displayIncome = _isBalanceVisible
              ? '${currency.format(financeProvider.totalIncome)} \u0111'
              : '\u2022\u2022\u2022\u2022\u2022\u2022';
          final displayExpense = _isBalanceVisible
              ? '${currency.format(financeProvider.totalExpense)} \u0111'
              : '\u2022\u2022\u2022\u2022\u2022\u2022';

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
                        _buildBudgetCard(context, budgets, currency),
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
          colors: [Color(0xFF1D4ED8), Color(0xFF4F46E5), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin ch\u00e0o,'.xtr(context),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 23,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Online'.xtr(context),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Consumer<NotificationProvider>(
                        builder: (context, provider, _) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const NotificationScreen(),
                                      ),
                                    );
                                  },
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              if (provider.unreadCount > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${provider.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Glassmorphism Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.18),
                          Colors.white.withOpacity(0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.24),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D28D9).withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'S\u1ed1 d\u01b0 kh\u1ea3 d\u1ee5ng'
                                  .xtr(context)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              DateFormat('MM/yyyy').format(DateTime.now()),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                displayBalance,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(
                                  () => _isBalanceVisible = !_isBalanceVisible,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    _isBalanceVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _headerStatCard(
                          icon: Icons.trending_up_rounded,
                          iconColor: const Color(0xFF4ADE80),
                          label: 'Thu nh\u1eadp'.xtr(context),
                          value: displayIncome,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _headerStatCard(
                          icon: Icons.trending_down_rounded,
                          iconColor: const Color(0xFFF87171),
                          label: 'Chi ti\u00eau'.xtr(context),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
              Expanded(
                child: Text(
                  'Thu - Chi 6 th\u00e1ng'.xtr(context),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _legendDot(const Color(0xFF3B82F6), 'Thu'.xtr(context)),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFFF87171), 'Chi'.xtr(context)),
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
    return _ScaleOnTap(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatbotScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D28D9).withOpacity(0.25),
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
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Financial Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'G\u1ee3i \u00fd t\u1ed1i \u01b0u chi ti\u00eau c\u1ee7a b\u1ea1n h\u00f4m nay'
                        .xtr(context),
                    style: const TextStyle(
                      color: Color(0xFFE9D5FF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFE9D5FF)),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    List<dynamic> budgets,
    NumberFormat currency,
  ) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ng\u00e2n s\u00e1ch th\u00e1ng n\u00e0y'.xtr(context),
                  style: const TextStyle(
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
                child: Text('Xem t\u1ea5t c\u1ea3'.xtr(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (budgets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'B\u1ea1n ch\u01b0a thi\u1ebft l\u1eadp ng\u00e2n s\u00e1ch.'
                      .xtr(context),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            )
          else
            ...budgets.map((budget) {
              final spent = budget.spentAmount;
              final limit = budget.limitAmount;
              final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
              final progressColor = ratio >= 0.9
                  ? const Color(0xFFEF4444)
                  : ratio >= 0.7
                  ? const Color(0xFFF97316)
                  : const Color(0xFF22C55E);

              return _ScaleOnTap(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllOverviewScreen(initialIndex: 2),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          (budget.icon as String).isEmpty
                              ? const Icon(
                                  Icons.savings_outlined,
                                  size: 18,
                                  color: Color(0xFF4B5563),
                                )
                              : () {
                                  final clean = (budget.icon as String).trim();
                                  int? codePoint = int.tryParse(clean);
                                  if (codePoint == null) {
                                    var hexStr = clean;
                                    if (hexStr.toLowerCase().startsWith('0x')) {
                                      hexStr = hexStr.substring(2);
                                    }
                                    codePoint = int.tryParse(hexStr, radix: 16);
                                  }
                                  if (codePoint != null) {
                                    final category = CategoryData.findById(budget.categoryId) ??
                                        CategoryData.findByName(budget.categoryName);
                                    return Icon(
                                      IconData(codePoint, fontFamily: 'MaterialIcons'),
                                      size: 18,
                                      color: category?.color ?? const Color(0xFF4B5563),
                                    );
                                  }
                                  return Text(
                                    budget.icon as String,
                                    style: const TextStyle(fontSize: 16),
                                  );
                                }(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (budget.categoryName as String).xtrCategory(
                                context,
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${currency.format(budget.spentAmount)} / ${currency.format(budget.limitAmount)} \u0111',
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
              Expanded(
                child: Text(
                  'Giao d\u1ecbch g\u1ea7n \u0111\u00e2y'.xtr(context),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Chuyển sang tab Giao dịch thay vì push lồng nhau
                  final mainScreen = MainScreen.of(context);
                  if (mainScreen != null) {
                    mainScreen.setSelectedIndex(1);
                  }
                },
                child: Text('Xem t\u1ea5t c\u1ea3'.xtr(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tx.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'B\u1ea1n ch\u01b0a c\u00f3 giao d\u1ecbch n\u00e0o.'.xtr(
                    context,
                  ),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            )
          else
            ...tx.map((item) {
              final isExpense = item.type == 'expense';
              final categoryName = CategoryData.resolveDisplayName(
                item.categoryId,
                item.categoryName,
              );
              return _ScaleOnTap(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTransactionPage(editData: item),
                    ),
                  );
                },
                child: Padding(
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
                        child: categoryName.isEmpty
                            ? const Icon(
                                Icons.payments_outlined,
                                size: 18,
                                color: Color(0xFF4B5563),
                              )
                            : Text(
                                categoryName.characters.first,
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
                                  ? CategoryData.normalizeLabel(item.note)
                                  : categoryName.xtrCategory(context),
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
                              '${categoryName.xtrCategory(context)} - ${DateFormat('dd/MM').format(item.transactionDate)}',
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
                        '${isExpense ? '-' : '+'}${currency.format(item.amount)} \u0111',
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

class _ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ScaleOnTap({required this.child, this.onTap});

  @override
  State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
