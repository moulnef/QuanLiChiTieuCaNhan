import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/add_budget_form_sheet.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/budget_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/finance_calculator.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_item_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_summary_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_vs_actual_chart.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/progress_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/budget_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/utils/snackbar_utils.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/utils/app_localizer.dart';

// ── Bảng màu chủ đạo: Trắng + Xanh nhạt ─────────────────
class _C {
  static const bg = Color(0xFFF0F5FF); // nền tổng — xanh cực nhạt
  static const surface = Colors.white;
  static const primary = Color(0xFF2563EB); // xanh chủ đạo
  static const primarySoft = Color(0xFFEEF4FF); // xanh nhạt cho chip/badge
  static const accent = Color(0xFF60A5FA); // xanh sáng hơn
  static const textDark = Color(0xFF0F172A);
  static const textLight = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);
  static const green = Color(0xFF10B981);
}

/// Màn hình tổng quan — kết hợp Home + Finance + Budget
class AllOverviewScreen extends StatefulWidget {
  final int initialIndex;
  const AllOverviewScreen({super.key, this.initialIndex = 0});

  @override
  State<AllOverviewScreen> createState() => _AllOverviewScreenState();
}

class _AllOverviewScreenState extends State<AllOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'user_001';
      final currentDate = DateTime.now();
      context.read<FinanceProvider>().loadFinanceData(userId);
      context.read<FinanceProvider>().refreshFinancialSummary(userId);
      context.read<BudgetProvider>().loadMonthlyBudgets(
        userId,
        currentDate.month,
        currentDate.year,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    return Consumer2<FinanceProvider, BudgetProvider>(
      builder: (context, financeProvider, budgetProvider, _) {
        return Scaffold(
          backgroundColor: _C.bg,
          body: NestedScrollView(
            headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
              _buildSliverAppBar(
                financeProvider: financeProvider,
                budgetProvider: budgetProvider,
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _HomeTab(
                  budgets: budgetProvider.budgets,
                  firestoreService: _firestoreService,
                ),
                _FinanceTab(),
                _BudgetTab(budgets: budgetProvider.budgets),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── SliverAppBar ──────────────────────────────────────────
  Widget _buildSliverAppBar({
    required FinanceProvider financeProvider,
    required BudgetProvider budgetProvider,
  }) {
    return SliverAppBar(
      // expandedHeight = SafeArea top + appBar row (56) + title block + stats + padding
      // Đặt đủ rộng để tránh overflow; NestedScrollView sẽ tự clip nếu dư
      expandedHeight: 240,
      pinned: true,
      stretch: false,
      elevation: 0,
      backgroundColor: _C.primary,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
          onPressed: () => FirebaseAuth.instance.signOut(),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _buildHeaderBackground(
          financeProvider: financeProvider,
          budgetProvider: budgetProvider,
        ),
        titlePadding: EdgeInsets.zero,
        title: null,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _buildTabBar(),
      ),
    );
  }

  /// Header: gradient xanh + title + 3 stat chip
  Widget _buildHeaderBackground({
    required FinanceProvider financeProvider,
    required BudgetProvider budgetProvider,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
      ),
      // padding top lớn để tránh đè lên appBar buttons
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize
                .min, // QUAN TRỌNG: không dùng MainAxisAlignment.spaceBetween
            children: [
              Text(
                'Tổng Quan Tài Chính'.xtr(context),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tháng '.xtr(context) + '${budgetProvider.selectedMonth}/${budgetProvider.selectedYear}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.72),
                ),
              ),
              const SizedBox(height: 14),
              // 3 stat chips — dùng IntrinsicHeight để chip không bị overflow
              IntrinsicHeight(
                child: Row(
                  children: [
                    _QuickStat(
                      label: 'Tổng thu'.xtr(context),
                      value:
                          financeProvider.totalIncome.toStringAsFixed(0),
                      icon: Icons.savings_outlined,
                      iconColor: const Color(0xFF4ADE80),
                    ),
                    const SizedBox(width: 8),
                    _QuickStat(
                      label: 'Tổng chi'.xtr(context),
                      value:
                          financeProvider.totalExpense.toStringAsFixed(0),
                      icon: Icons.credit_card_outlined,
                      iconColor: const Color(0xFF93C5FD),
                    ),
                    const SizedBox(width: 8),
                    _QuickStat(
                      label: 'Số dư'.xtr(context),
                      value:
                          financeProvider.totalBalance.toStringAsFixed(0),
                      icon: Icons.account_balance_outlined,
                      iconColor: const Color(0xFFFBBF24),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _C.primary,
        border: Border(
          bottom: BorderSide(color: Color(0x33FFFFFF), width: 0.5),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: _C.accent,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: [
          Tab(text: 'Trang Chủ'.xtr(context)),
          Tab(text: 'Tài Chính'.xtr(context)),
          Tab(text: 'Ngân Sách'.xtr(context)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TAB 1: TRANG CHỦ
// ─────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final List<Budget> budgets;
  final FirestoreService firestoreService;

  const _HomeTab({required this.budgets, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionModel>>(
      stream: firestoreService.streamTransactions(),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          children: [
            _AiAssistantBanner(),
            const SizedBox(height: 20),

            _SectionHeader(title: 'Ngân sách tháng này'.xtr(context)),
            const SizedBox(height: 10),
            ...budgets.take(3).map((b) => _BudgetMiniCard(budget: b)),
            if (budgets.length > 3)
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(foregroundColor: _C.primary),
                child: Text(
                  'Xem thêm '.xtr(context) + '${budgets.length - 3}' + ' ngân sách...'.xtr(context),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 20),

            _SectionHeader(title: 'Giao dịch gần đây'.xtr(context)),
            const SizedBox(height: 10),

            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: _C.primary),
                ),
              )
            else if (snapshot.hasError)
              _ErrorCard(message: 'Không thể tải giao dịch'.xtr(context))
            else if (transactions.isEmpty)
              _EmptyStateCard(
                icon: Icons.receipt_long_outlined,
                message: 'Chưa có giao dịch nào.\nHãy thêm giao dịch đầu tiên!'.xtr(context),
              )
            else
              ...transactions.take(5).map((tx) {
                return _TransactionCard(
                  transaction: tx,
                  onDelete: () => firestoreService.deleteTransaction(tx.id),
                );
              }),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// TAB 2: TÀI CHÍNH
// ─────────────────────────────────────────────────────────
class _FinanceTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, _) {
        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                color: _C.surface,
                child: TabBar(
                  labelColor: _C.primary,
                  unselectedLabelColor: _C.textLight,
                  indicatorColor: _C.primary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 14),
                  tabs: [
                    Tab(text: 'Tiết kiệm'.xtr(context)),
                    Tab(text: 'Trả góp'.xtr(context)),
                    Tab(text: 'Vay nợ'.xtr(context)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: _C.surface,
                  border: Border(bottom: BorderSide(color: _C.border)),
                ),
                child: Row(
                  children: [
                    _FinanceChip(
                      label: 'Đang tiết kiệm'.xtr(context),
                      value: _formatCompactMoney(
                        financeProvider.totalSavingAmount.toDouble(),
                      ),
                      color: _C.green,
                    ),
                    const SizedBox(width: 8),
                    _FinanceChip(
                      label: 'Còn trả góp'.xtr(context),
                      value: _formatCompactMoney(
                        financeProvider.totalInstallmentRemaining.toDouble(),
                      ),
                      color: _C.primary,
                    ),
                    const SizedBox(width: 8),
                    _FinanceChip(
                      label: 'Còn vay'.xtr(context),
                      value: _formatCompactMoney(
                        financeProvider.totalDebtRemaining.toDouble(),
                      ),
                      color: _C.orange,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _SavingTabContent(provider: financeProvider),
                    _InstallmentTabContent(provider: financeProvider),
                    _DebtTabContent(provider: financeProvider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FinanceChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FinanceChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingTabContent extends StatelessWidget {
  final FinanceProvider provider;

  const _SavingTabContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        if (provider.savings.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InlineFinanceEmptyState(
              message: 'Chưa có mục tiêu tiết kiệm'.xtr(context),
            ),
          ),
        ...provider.savings.map((item) {
          final progress = item.targetAmount <= 0
              ? 0
              : ((item.currentAmount * 100) / item.targetAmount).floor();
          final daysLeft = item.deadline.difference(DateTime.now()).inDays;
          return ProgressCard(
            icon: item.icon,
            title: item.title,
            subtitle: daysLeft >= 0
                ? 'Còn '.xtr(context) + '$daysLeft' + ' ngày'.xtr(context)
                : 'Đã quá hạn '.xtr(context) + '${daysLeft.abs()}' + ' ngày'.xtr(context),
            leftLabel: 'Hiện tại'.xtr(context),
            leftValue: _formatMoney(item.currentAmount.toDouble()),
            rightLabel: 'Mục tiêu'.xtr(context),
            rightValue: _formatMoney(item.targetAmount.toDouble()),
            progressPercent: progress.clamp(0, 100),
            progressColor: item.color,
            primaryButtonText: '+ Nạp tiền'.xtr(context),
            secondaryButtonText: 'Rút tiền'.xtr(context),
            onPrimaryPressed: () {},
            onSecondaryPressed: () {},
          );
        }),
        const SizedBox(height: 8),
        _AddButton(
          label: '+  Tạo mục tiêu mới'.xtr(context),
          borderColor: _C.green,
          textColor: _C.green,
          onPressed: () => _openCreateSavingGoalSheet(context, provider),
        ),
      ],
    );
  }
}

class _InstallmentTabContent extends StatelessWidget {
  final FinanceProvider provider;

  const _InstallmentTabContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        if (provider.installments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InlineFinanceEmptyState(
              message: 'Chưa có kế hoạch trả góp'.xtr(context),
            ),
          ),
        ...provider.installments.map((item) {
          final progress = item.totalAmount <= 0
              ? 0
              : ((item.paidAmount * 100) / item.totalAmount).floor();
          return ProgressCard(
            icon: item.icon,
            title: item.title,
            subtitle: 'Đã trả '.xtr(context) + '${item.currentPeriod}/${item.totalPeriods}' + ' kỳ'.xtr(context),
            leftLabel: 'Gốc + Lãi'.xtr(context),
            leftValue: _formatMoney(item.totalAmount.toDouble()),
            rightLabel: 'Còn nợ'.xtr(context),
            rightValue: _formatMoney(item.remainingAmount.toDouble()),
            progressPercent: progress.clamp(0, 100),
            progressColor: item.color,
            alertMessage:
                'Kỳ tiếp theo: '.xtr(context) + DateFormat('yyyy-MM-dd').format(item.nextDueDate),
            alertColor: AppColors.blue,
          );
        }),
        const SizedBox(height: 8),
        _AddButton(
          label: '+  Thêm kế hoạch trả góp'.xtr(context),
          borderColor: _C.primary,
          textColor: _C.primary,
          onPressed: () => _openCreateInstallmentPlanSheet(context, provider),
        ),
      ],
    );
  }
}

class _DebtTabContent extends StatelessWidget {
  final FinanceProvider provider;

  const _DebtTabContent({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        if (provider.debts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InlineFinanceEmptyState(message: 'Chưa có khoản vay nợ'.xtr(context)),
          ),
        ...provider.debts.map((item) {
          final progress = item.totalAmount <= 0
              ? 0
              : ((item.paidAmount * 100) / item.totalAmount).floor();
          return ProgressCard(
            icon: item.icon,
            title: item.title,
            subtitle: item.lender,
            leftLabel: 'Tổng vay'.xtr(context),
            leftValue: _formatMoney(item.totalAmount.toDouble()),
            rightLabel: 'Còn lại'.xtr(context),
            rightValue: _formatMoney(item.remainingAmount.toDouble()),
            progressPercent: progress.clamp(0, 100),
            progressColor: item.color,
            alertMessage:
                'Kỳ tiếp: '.xtr(context) + DateFormat('yyyy-MM-dd').format(item.dueDate) + ' • ' + item.interestText.xtr(context),
            alertColor: AppColors.warning,
          );
        }),
        const SizedBox(height: 8),
        _AddButton(
          label: '+  Thêm khoản vay'.xtr(context),
          borderColor: _C.orange,
          textColor: _C.orange,
          onPressed: () => _openCreateLoanSheet(context, provider),
        ),
      ],
    );
  }
}

class _InlineFinanceEmptyState extends StatelessWidget {
  final String message;

  const _InlineFinanceEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _C.textLight, fontSize: 14),
      ),
    );
  }
}

String _formatMoney(double amount) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  return '${formatter.format(amount.round())} đ';
}

String _formatCompactMoney(double amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}tr';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(0)}k';
  }
  return amount.toStringAsFixed(0);
}

const double _financeSheetBottomReserve = 128;

Future<void> _openCreateSavingGoalSheet(
  BuildContext context,
  FinanceProvider provider,
) async {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  DateTime selectedDate = DateTime(2026, 5, 1);
  bool isLoading = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setState) {
          final title = titleController.text.trim();
          final amount = int.tryParse(amountController.text.trim()) ?? 0;
          final isValid = title.isNotEmpty && amount > 0;
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom:
                  MediaQuery.of(sheetContext).viewInsets.bottom +
                  _financeSheetBottomReserve,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mục tiêu tiết kiệm mới'.xtr(context),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _C.textDark,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: _financeInputDecoration(
                      hintText: 'Tên mục tiêu'.xtr(context),
                      borderRadius: 12,
                      borderColor: const Color(0xFFD1D5DB),
                      fillColor: const Color(0xFFF4F6FA),
                      hintColor: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    decoration: _financeInputDecoration(
                      hintText: 'Số tiền cần tiết kiệm'.xtr(context),
                      borderRadius: 12,
                      borderColor: const Color(0xFFD1D5DB),
                      fillColor: const Color(0xFFF4F6FA),
                      hintColor: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ngày dự kiến hoàn thành'.xtr(context),
                        style: const TextStyle(
                          fontSize: 14,
                          color: _C.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 10),
                            ),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(selectedDate),
                          style: const TextStyle(
                            fontSize: 14,
                            color: _C.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isValid && !isLoading
                          ? () async {
                              setState(() => isLoading = true);
                              try {
                                await provider.addSavingGoal(
                                  title: title,
                                  targetAmount: amount,
                                  deadline: selectedDate,
                                );

                                if (context.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  SnackbarUtils.showError(
                                    context,
                                    'Lưu mục tiêu tiết kiệm thất bại: '.xtr(context) + '$e',
                                  );
                                }
                              } finally {
                                if (sheetContext.mounted) {
                                  setState(() => isLoading = false);
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValid && !isLoading
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFFD1D5DB),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFF9CA3AF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Tạo mục tiêu'.xtr(context),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _openCreateInstallmentPlanSheet(
  BuildContext context,
  FinanceProvider provider,
) async {
  final titleController = TextEditingController();
  final totalAmountController = TextEditingController();
  final periodsController = TextEditingController();
  final eachPeriodController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom:
              MediaQuery.of(sheetContext).viewInsets.bottom +
              _financeSheetBottomReserve,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kế hoạch trả góp mới'.xtr(context),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.textDark,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: titleController,
                decoration: _financeInputDecoration(
                  hintText: 'Tên khoản trả góp'.xtr(context),
                  borderRadius: 12,
                  borderColor: const Color(0xFFD1D5DB),
                  fillColor: Colors.white,
                  hintColor: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: totalAmountController,
                keyboardType: TextInputType.number,
                decoration: _financeInputDecoration(
                  hintText: 'Tổng số tiền'.xtr(context),
                  borderRadius: 12,
                  borderColor: const Color(0xFFD1D5DB),
                  fillColor: Colors.white,
                  hintColor: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: periodsController,
                      keyboardType: TextInputType.number,
                      decoration: _financeInputDecoration(
                        hintText: 'Số kỳ'.xtr(context),
                        borderRadius: 12,
                        borderColor: const Color(0xFFD1D5DB),
                        fillColor: Colors.white,
                        hintColor: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: eachPeriodController,
                      keyboardType: TextInputType.number,
                      decoration: _financeInputDecoration(
                        hintText: 'Mỗi kỳ'.xtr(context),
                        borderRadius: 12,
                        borderColor: const Color(0xFFD1D5DB),
                        fillColor: Colors.white,
                        hintColor: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final totalAmount =
                        int.tryParse(totalAmountController.text.trim()) ?? 0;
                    final periodInput =
                        int.tryParse(periodsController.text.trim()) ?? 0;
                    final eachPeriodAmount =
                        int.tryParse(eachPeriodController.text.trim()) ?? 0;

                    var totalPeriods = periodInput;
                    if (totalPeriods <= 0 && eachPeriodAmount > 0) {
                      totalPeriods = (totalAmount / eachPeriodAmount).ceil();
                    }

                    if (title.isEmpty ||
                        totalAmount <= 0 ||
                        totalPeriods <= 0) {
                      return;
                    }

                    await provider.addInstallmentPlan(
                      title: title,
                      totalAmount: totalAmount,
                      totalPeriods: totalPeriods,
                    );

                    if (context.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Lưu kế hoạch'.xtr(context),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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

Future<void> _openCreateLoanSheet(
  BuildContext context,
  FinanceProvider provider,
) async {
  final titleController = TextEditingController();
  final lenderController = TextEditingController();
  final totalAmountController = TextEditingController();
  final monthlyPaymentController = TextEditingController();
  final interestController = TextEditingController();
  DateTime selectedDueDate = DateTime.now().add(const Duration(days: 30));

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom:
                  MediaQuery.of(sheetContext).viewInsets.bottom +
                  _financeSheetBottomReserve,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Khoản vay mới'.xtr(context),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _C.textDark,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: titleController,
                    decoration: _financeInputDecoration(
                      hintText: 'Tên khoản vay'.xtr(context),
                      borderRadius: 12,
                      borderColor: const Color(0xFFD1D5DB),
                      fillColor: Colors.white,
                      hintColor: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lenderController,
                    decoration: _financeInputDecoration(
                      hintText: 'Nguồn vay / Người cho vay'.xtr(context),
                      borderRadius: 12,
                      borderColor: const Color(0xFFD1D5DB),
                      fillColor: Colors.white,
                      hintColor: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: totalAmountController,
                    keyboardType: TextInputType.number,
                    decoration: _financeInputDecoration(
                      hintText: 'Tổng số tiền'.xtr(context),
                      borderRadius: 12,
                      borderColor: const Color(0xFFD1D5DB),
                      fillColor: Colors.white,
                      hintColor: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: monthlyPaymentController,
                          keyboardType: TextInputType.number,
                          decoration: _financeInputDecoration(
                            hintText: 'Trả mỗi tháng'.xtr(context),
                            borderRadius: 12,
                            borderColor: const Color(0xFFD1D5DB),
                            fillColor: Colors.white,
                            hintColor: const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: interestController,
                          keyboardType: TextInputType.number,
                          decoration: _financeInputDecoration(
                            hintText: 'Lãi suất'.xtr(context),
                            borderRadius: 12,
                            borderColor: const Color(0xFFD1D5DB),
                            fillColor: Colors.white,
                            hintColor: const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ngày đến hạn tiếp theo'.xtr(context),
                        style: const TextStyle(
                          fontSize: 14,
                          color: _C.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: selectedDueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 10),
                            ),
                          );
                          if (picked != null) {
                            setState(() => selectedDueDate = picked);
                          }
                        },
                        child: Text(
                          'Chọn ngày'.xtr(context),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final lender = lenderController.text.trim();
                        final totalAmount =
                            int.tryParse(totalAmountController.text.trim()) ??
                            0;
                        final monthlyPayment =
                            int.tryParse(
                              monthlyPaymentController.text.trim(),
                            ) ??
                            0;
                        final interest = interestController.text.trim();

                        if (title.isEmpty ||
                            lender.isEmpty ||
                            totalAmount <= 0) {
                          return;
                        }

                        final interestText = interest.isEmpty
                            ? (monthlyPayment > 0
                                  ? 'Trả mỗi tháng '.xtr(context) + _formatMoney(monthlyPayment.toDouble())
                                  : 'Chưa cập nhật lãi suất'.xtr(context))
                            : 'Lãi suất '.xtr(context) + '$interest%';

                        await provider.addDebtRecord(
                          title: title,
                          lender: lender,
                          totalAmount: totalAmount,
                          dueDate: selectedDueDate,
                          interestText: interestText,
                        );

                        if (context.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Lưu khoản vay'.xtr(context),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

InputDecoration _financeInputDecoration({
  required String hintText,
  required double borderRadius,
  required Color borderColor,
  required Color fillColor,
  required Color hintColor,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: hintColor,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: fillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
    ),
  );
}

// ─────────────────────────────────────────────────────────
// TAB 3: NGÂN SÁCH
// ─────────────────────────────────────────────────────────
class _BudgetTab extends StatelessWidget {
  final List<Budget> budgets;

  const _BudgetTab({required this.budgets});

  @override
  Widget build(BuildContext context) {
    final totalSpent = BudgetService.getTotalSpent(budgets: budgets);
    final totalLimit = BudgetService.getTotalLimit(budgets: budgets);
    final totalProgress = FinanceCalculator.calculateBudgetProgress(
      spentAmount: totalSpent,
      limitAmount: totalLimit,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        BudgetSummaryCard(
          totalSpent: totalSpent,
          totalLimit: totalLimit,
          progressPercent: totalProgress,
        ),
        const SizedBox(height: 16),
        BudgetVsActualChart(budgets: budgets),
        const SizedBox(height: 16),
        ...budgets.map((b) => BudgetItemCard(budget: b)),
        const SizedBox(height: 8),
        _AddButton(
          label: '+  Thêm ngân sách mới'.xtr(context),
          borderColor: _C.orange,
          textColor: _C.orange,
          onPressed: () {
            final userId = FirebaseAuth.instance.currentUser?.uid ?? 'user_001';
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddBudgetFormSheet(
                userId: userId,
                onSubmit: (newBudget) async {
                  await context.read<BudgetProvider>().addBudget(newBudget);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(
                        'Đã thêm ngân sách '.xtr(context) + newBudget.categoryName.xtrCategory(context))),
                    );
                  }
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────

/// Chip stat nhỏ trong header (trắng mờ trên nền xanh gradient)
class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 15),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiAssistantBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Financial Assistant',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bạn đã chi quá '.xtr(context) + '71%' + ' ngân sách ăn uống'.xtr(context),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white70,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _C.textDark,
      ),
    );
  }
}

class _BudgetMiniCard extends StatelessWidget {
  final Budget budget;

  const _BudgetMiniCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final percent = budget.progressPercent.clamp(0, 100);
    final color = percent >= 100
        ? _C.red
        : percent >= 80
        ? _C.orange
        : _C.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.categoryName.xtrCategory(context),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _C.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: _C.primarySoft,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onDelete;

  const _TransactionCard({required this.transaction, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _C.primarySoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.money_off_rounded,
            color: _C.primary,
            size: 20,
          ),
        ),
        title: Text(
          transaction.note.isNotEmpty ? transaction.note : (transaction.categoryName.isNotEmpty ? transaction.categoryName.xtrCategory(context) : 'Không tên'.xtr(context)),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: _C.textDark,
          ),
        ),
        subtitle: Text(
          '${transaction.categoryName.isNotEmpty ? transaction.categoryName.xtrCategory(context) : (transaction.type == 'income' ? 'Thu nhập'.xtr(context) : 'Chi tiêu'.xtr(context))} • ${DateFormat('dd/MM/yyyy').format(transaction.transactionDate)}',
          style: const TextStyle(fontSize: 12, color: _C.textLight),
        ),
        trailing: Text(
          '${transaction.type == 'income' ? '+' : '-'}${transaction.amount.toStringAsFixed(0)} VNĐ',
          style: TextStyle(
            color: transaction.type == 'income' ? _C.green : _C.red,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        onLongPress: onDelete,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _C.red, size: 18),
          const SizedBox(width: 10),
          Text(message, style: const TextStyle(color: _C.red, fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyStateCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: _C.textLight),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _C.textLight,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút outline dùng chung cho tất cả tab
class _AddButton extends StatelessWidget {
  final String label;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onPressed;

  const _AddButton({
    required this.label,
    required this.borderColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: borderColor.withOpacity(0.05),
        side: BorderSide(color: borderColor.withOpacity(0.4), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
