  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/ai_chat/chatbot.dart';
  
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/database/mock/mock_budgets.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/database/mock/mock_transactions.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/budget_service.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/finance_calculator.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_item_card.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_summary_card.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/budget/budget_vs_actual_chart.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/finance_stat_card.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/progress_card.dart';
  import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/transaction/add_transaction_screen.dart';
  
  // ── Bảng màu chủ đạo: Trắng + Xanh nhạt ─────────────────
  class _C {
    static const bg          = Color(0xFFF0F5FF);   // nền tổng — xanh cực nhạt
    static const surface     = Colors.white;
    static const primary     = Color(0xFF2563EB);   // xanh chủ đạo
    static const primarySoft = Color(0xFFEEF4FF);   // xanh nhạt cho chip/badge
    static const accent      = Color(0xFF60A5FA);   // xanh sáng hơn
    static const textDark    = Color(0xFF0F172A);
    static const textMid     = Color(0xFF475569);
    static const textLight   = Color(0xFF94A3B8);
    static const border      = Color(0xFFE2E8F0);
    static const red         = Color(0xFFEF4444);
    static const orange      = Color(0xFFF59E0B);
    static const green       = Color(0xFF10B981);
  }
  
  /// Màn hình tổng quan — kết hợp Home + Finance + Budget
  class AllOverviewScreen extends StatefulWidget {
    const AllOverviewScreen({super.key});
  
    @override
    State<AllOverviewScreen> createState() => _AllOverviewScreenState();
  }
  
  class _AllOverviewScreenState extends State<AllOverviewScreen>
      with SingleTickerProviderStateMixin {
    late TabController _tabController;
    final FirestoreService _firestoreService = FirestoreService();
    late List<Budget> _budgets;
  
    @override
    void initState() {
      super.initState();
      _tabController = TabController(length: 3, vsync: this);
      _budgets = BudgetService.getMonthlyBudgetStatus(
        transactions: MockTransactions.items,
        budgets: MockBudgets.items,
        month: 3,
        year: 2026,
      );
    }
  
    @override
    void dispose() {
      _tabController.dispose();
      super.dispose();
    }
  
    @override
    Widget build(BuildContext context) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ));
  
      return Scaffold(
        backgroundColor: _C.bg,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, innerBoxIsScrolled) =>
          [_buildSliverAppBar()],
          body: TabBarView(
            controller: _tabController,
            children: [
              _HomeTab(
                  budgets: _budgets, firestoreService: _firestoreService),
              _FinanceTab(),
              _BudgetTab(budgets: _budgets),
            ],
          ),
        ),
        floatingActionButton: _buildFAB(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      );
    }
  
    // ── SliverAppBar ──────────────────────────────────────────
    Widget _buildSliverAppBar() {
      return SliverAppBar(
        // expandedHeight = SafeArea top + appBar row (56) + title block + stats + padding
        // Đặt đủ rộng để tránh overflow; NestedScrollView sẽ tự clip nếu dư
        expandedHeight: 240,
        pinned: true,
        stretch: false,
        elevation: 0,
        backgroundColor: _C.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 24),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: Colors.white, size: 22),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.pin,
          background: _buildHeaderBackground(),
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
    Widget _buildHeaderBackground() {
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
              mainAxisSize: MainAxisSize.min, // QUAN TRỌNG: không dùng MainAxisAlignment.spaceBetween
              children: [
                const Text(
                  'Tổng Quan Tài Chính',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tháng 3/2026',
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
                        label: 'Tiết kiệm',
                        value: '58.5tr',
                        icon: Icons.savings_outlined,
                        iconColor: const Color(0xFF4ADE80),
                      ),
                      const SizedBox(width: 8),
                      _QuickStat(
                        label: 'Trả góp',
                        value: '23.5tr',
                        icon: Icons.credit_card_outlined,
                        iconColor: const Color(0xFF93C5FD),
                      ),
                      const SizedBox(width: 8),
                      _QuickStat(
                        label: 'Còn vay',
                        value: '7.5tr',
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
          labelStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: const [
            Tab(text: 'Trang Chủ'),
            Tab(text: 'Tài Chính'),
            Tab(text: 'Ngân Sách'),
          ],
        ),
      );
    }
  
    Widget _buildFAB(BuildContext context) {
      return FloatingActionButton.extended(
        heroTag: 'overview_fab',
        backgroundColor: _C.primary,
        elevation: 4,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Thêm giao dịch',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
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
      return StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getTransactions(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
  
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            children: [
              _AiAssistantBanner(),
              const SizedBox(height: 20),
  
              _SectionHeader(title: 'Ngân sách tháng này'),
              const SizedBox(height: 10),
              ...budgets.take(3).map((b) => _BudgetMiniCard(budget: b)),
              if (budgets.length > 3)
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(foregroundColor: _C.primary),
                  child: Text(
                    'Xem thêm ${budgets.length - 3} ngân sách...',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 20),
  
              _SectionHeader(title: 'Giao dịch gần đây'),
              const SizedBox(height: 10),
  
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: CircularProgressIndicator(color: _C.primary)),
                )
              else if (snapshot.hasError)
                _ErrorCard(message: 'Không thể tải giao dịch')
              else if (docs.isEmpty)
                  _EmptyStateCard(
                    icon: Icons.receipt_long_outlined,
                    message:
                    'Chưa có giao dịch nào.\nHãy thêm giao dịch đầu tiên!',
                  )
                else
                  ...docs.take(5).map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _TransactionCard(
                      data: data,
                      onDelete: () =>
                          firestoreService.deleteTransaction(doc.id),
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
      return DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // Sub-tabbar trắng
            Container(
              color: _C.surface,
              child: TabBar(
                labelColor: _C.primary,
                unselectedLabelColor: _C.textLight,
                indicatorColor: _C.primary,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 14),
                tabs: const [
                  Tab(text: 'Tiết kiệm'),
                  Tab(text: 'Trả góp'),
                  Tab(text: 'Vay nợ'),
                ],
              ),
            ),
            // 3 stat chips — nền trắng
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: _C.surface,
                border: Border(bottom: BorderSide(color: _C.border)),
              ),
              child: Row(
                children: [
                  _FinanceChip(
                      label: 'Đang tiết kiệm',
                      value: '58.5tr',
                      color: _C.green),
                  const SizedBox(width: 8),
                  _FinanceChip(
                      label: 'Còn trả góp',
                      value: '23.5tr',
                      color: _C.primary),
                  const SizedBox(width: 8),
                  _FinanceChip(
                      label: 'Còn vay',
                      value: '7.5tr',
                      color: _C.orange),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _SavingTabContent(),
                  _InstallmentTabContent(),
                  _DebtTabContent(),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
  
  class _FinanceChip extends StatelessWidget {
    final String label;
    final String value;
    final Color color;
  
    const _FinanceChip(
        {required this.label, required this.value, required this.color});
  
    @override
    Widget build(BuildContext context) {
      return Expanded(
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                    color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.75),
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }
  }
  
  class _SavingTabContent extends StatelessWidget {
    const _SavingTabContent();
  
    @override
    Widget build(BuildContext context) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          ProgressCard(
            icon: '🏍️',
            title: 'Mua xe máy mới',
            subtitle: 'Còn 281 ngày',
            leftLabel: 'Hiện tại',
            leftValue: '18.500.000 đ',
            rightLabel: 'Mục tiêu',
            rightValue: '35.000.000 đ',
            progressPercent: 53,
            progressColor: AppColors.blue,
            primaryButtonText: '+ Nạp tiền',
            secondaryButtonText: 'Rút tiền',
            onPrimaryPressed: () {},
            onSecondaryPressed: () {},
          ),
          ProgressCard(
            icon: '🗾',
            title: 'Du lịch Nhật Bản',
            subtitle: 'Còn 433 ngày',
            leftLabel: 'Hiện tại',
            leftValue: '8.000.000 đ',
            rightLabel: 'Mục tiêu',
            rightValue: '25.000.000 đ',
            progressPercent: 32,
            progressColor: AppColors.purple,
            primaryButtonText: '+ Nạp tiền',
            secondaryButtonText: 'Rút tiền',
            onPrimaryPressed: () {},
            onSecondaryPressed: () {},
          ),
          ProgressCard(
            icon: '🛡️',
            title: 'Quỹ khẩn cấp',
            subtitle: 'Còn 97 ngày',
            leftLabel: 'Hiện tại',
            leftValue: '32.000.000 đ',
            rightLabel: 'Mục tiêu',
            rightValue: '50.000.000 đ',
            progressPercent: 64,
            progressColor: AppColors.teal,
            primaryButtonText: '+ Nạp tiền',
            secondaryButtonText: 'Rút tiền',
            onPrimaryPressed: () {},
            onSecondaryPressed: () {},
          ),
          const SizedBox(height: 8),
          _AddButton(
            label: '+  Tạo mục tiêu mới',
            borderColor: _C.green,
            textColor: _C.green,
            onPressed: () {},
          ),
        ],
      );
    }
  }
  
  class _InstallmentTabContent extends StatelessWidget {
    const _InstallmentTabContent();
  
    @override
    Widget build(BuildContext context) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          ProgressCard(
            icon: '📱',
            title: 'Điện thoại iPhone 15',
            subtitle: 'Đã trả 4/12 kỳ',
            leftLabel: 'Gốc + Lãi',
            leftValue: '27.500.000 đ',
            rightLabel: 'Còn nợ',
            rightValue: '18.500.000 đ',
            progressPercent: 33,
            progressColor: AppColors.blue,
            alertMessage: 'Kỳ tiếp theo: 2026-04-05',
            alertColor: AppColors.blue,
          ),
          ProgressCard(
            icon: '💻',
            title: 'Máy tính xách tay',
            subtitle: 'Đã trả 11/12 kỳ',
            leftLabel: 'Gốc + Lãi',
            leftValue: '19.260.000 đ',
            rightLabel: 'Còn nợ',
            rightValue: '5.000.000 đ',
            progressPercent: 74,
            progressColor: AppColors.purple,
            alertMessage: 'Kỳ tiếp theo: 2026-04-10',
            alertColor: AppColors.blue,
          ),
          const SizedBox(height: 8),
          _AddButton(
            label: '+  Thêm kế hoạch trả góp',
            borderColor: _C.primary,
            textColor: _C.primary,
            onPressed: () {},
          ),
        ],
      );
    }
  }
  
  class _DebtTabContent extends StatelessWidget {
    const _DebtTabContent();
  
    @override
    Widget build(BuildContext context) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          ProgressCard(
            icon: '💳',
            title: 'Vay mua xe đạp điện',
            subtitle: 'Ngân hàng ACB',
            leftLabel: 'Tổng vay',
            leftValue: '12.000.000 đ',
            rightLabel: 'Còn lại',
            rightValue: '7.500.000 đ',
            progressPercent: 38,
            progressColor: AppColors.safe,
            alertMessage: 'Kỳ tiếp: 2026-04-01 • 8.5%/năm',
            alertColor: AppColors.warning,
          ),
          const SizedBox(height: 8),
          _AddButton(
            label: '+  Thêm khoản vay',
            borderColor: _C.orange,
            textColor: _C.orange,
            onPressed: () {},
          ),
        ],
      );
    }
  }
  
  // ─────────────────────────────────────────────────────────
  // TAB 3: NGÂN SÁCH
  // ─────────────────────────────────────────────────────────
  class _BudgetTab extends StatefulWidget {
    final List<Budget> budgets;
    const _BudgetTab({required this.budgets});
  
    @override
    State<_BudgetTab> createState() => _BudgetTabState();
  }
  
  class _BudgetTabState extends State<_BudgetTab> {
    late List<Budget> _budgets;
  
    @override
    void initState() {
      super.initState();
      _budgets = widget.budgets;
    }
  
    @override
    Widget build(BuildContext context) {
      final totalSpent = BudgetService.getTotalSpent(budgets: _budgets);
      final totalLimit = BudgetService.getTotalLimit(budgets: _budgets);
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
          BudgetVsActualChart(budgets: _budgets),
          const SizedBox(height: 16),
          ..._budgets.map((b) => BudgetItemCard(budget: b)),
          const SizedBox(height: 8),
          _AddButton(
            label: '+  Thêm ngân sách mới',
            borderColor: _C.orange,
            textColor: _C.orange,
            onPressed: () {},
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
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
            // ĐÃ SỬA: Thay Text('🤖') bằng Image.asset để load file GIF
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'lib/ui/ai_chat/robot.gif', // Đảm bảo đường dẫn này khớp với vị trí file
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.smart_toy, color: Colors.white);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Financial Assistant',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Bạn đã chi quá 71% ngân sách ăn uống',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white70, size: 20),
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
                  budget.categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _C.textDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
    final Map<String, dynamic> data;
    final VoidCallback onDelete;
  
    const _TransactionCard({required this.data, required this.onDelete});
  
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
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.money_off_rounded,
                color: _C.primary, size: 20),
          ),
          title: Text(
            data['title'] ?? 'Không tên',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _C.textDark,
            ),
          ),
          subtitle: Text(
            '${data['category'] ?? ''}${data['note'] != null ? " • ${data['note']}" : ""}',
            style: const TextStyle(fontSize: 12, color: _C.textLight),
          ),
          trailing: Text(
            '-${data['amount']} VNĐ',
            style: const TextStyle(
              color: _C.red,
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
            Text(message,
                style: const TextStyle(color: _C.red, fontSize: 13)),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
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