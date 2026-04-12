import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/database_helper.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/database/mock/mock_transactions.dart';
import 'package:sqflite/sqflite.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  static const String _demoUserId = 'user_001';

  // Đã đồng bộ mã màu Tím Galaxy với toàn bộ App
  static const Color _primary = Color(0xFF6D28D9);

  static const List<Color> _chartColors = [
    Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFFA855F7), Color(0xFFF97316),
    Color(0xFF22C55E), Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF06B6D4),
    Color(0xFFEC4899), Color(0xFF84CC16),
  ];

  int _selectedTab = 2;
  final List<String> _tabs = ['Ngày', 'Tuần', 'Tháng', 'Năm'];

  bool _isLoading = true;
  List<TransactionModel> _allTransactions = [];

  double _totalIncome = 0;
  double _totalExpense = 0;
  List<MapEntry<String, double>> _topCategories = [];
  List<Map<String, double>> _monthlyData = [];
  List<double> _weeklyData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      await _ensureMockDataExists(db);

      final rows = await db.query(
        'transactions',
        where: 'userId = ?',
        whereArgs: [_demoUserId],
        orderBy: 'datetime(transactionDate) DESC',
      );
      final transactions = rows.map((r) => TransactionModel.fromMap(r)).toList();
      setState(() {
        _allTransactions = transactions;
        _computeStats();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('StatsPage _loadData error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureMockDataExists(Database db) async {
    for (final tx in MockTransactions.items) {
      final row = <String, Object?>{
        'id': tx.id,
        'userId': tx.userId,
        'walletId': tx.walletId,
        'categoryId': tx.categoryId,
        'categoryName': tx.categoryName,
        'type': tx.type,
        'amount': tx.amount,
        'note': tx.note,
        'transactionDate': tx.transactionDate.toIso8601String(),
        'createdAt': tx.createdAt.toIso8601String(),
        'updatedAt': tx.updatedAt.toIso8601String(),
      };
      await db.insert('transactions', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  void _computeStats() {
    final now = DateTime.now();
    List<TransactionModel> filtered;

    switch (_selectedTab) {
      case 0:
        filtered = _allTransactions.where((t) => t.transactionDate.year == now.year && t.transactionDate.month == now.month && t.transactionDate.day == now.day).toList();
        break;
      case 1:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        filtered = _allTransactions.where((t) => t.transactionDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) && t.transactionDate.isBefore(startOfWeek.add(const Duration(days: 7)))).toList();
        break;
      case 2:
        filtered = _allTransactions.where((t) => t.transactionDate.year == now.year && t.transactionDate.month == now.month).toList();
        break;
      case 3:
        filtered = _allTransactions.where((t) => t.transactionDate.year == now.year).toList();
        break;
      default:
        filtered = _allTransactions;
    }

    double income = 0, expense = 0;
    final catMap = <String, double>{};

    for (final t in filtered) {
      if (t.type == 'income') {
        income += t.amount;
      } else {
        expense += t.amount;
        final cat = t.categoryName.isEmpty ? 'Khác' : t.categoryName;
        catMap[cat] = (catMap[cat] ?? 0) + t.amount;
      }
    }

    final groupedMap = <String, double>{};
    for (final entry in catMap.entries) {
      final groupName = _mapToGroup(entry.key);
      groupedMap[groupName] = (groupedMap[groupName] ?? 0) + entry.value;
    }

    final sortedCats = groupedMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    _totalIncome = income;
    _totalExpense = expense;
    _topCategories = sortedCats.take(8).toList();
    _monthlyData = _computeMonthlyData();
    _weeklyData = _computeWeeklyData();
  }

  String _mapToGroup(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('ăn') || name.contains('cafe') || name.contains('bữa') || name.contains('chợ') || name.contains('siêu thị')) return 'Ăn uống';
    if (name.contains('xăng') || name.contains('taxi') || name.contains('xe') || name.contains('gửi xe') || name.contains('đi lại') || name.contains('di chuyển')) return 'Di chuyển';
    if (name.contains('quần') || name.contains('áo') || name.contains('giày') || name.contains('mua sắm') || name.contains('trang phục')) return 'Mua sắm';
    if (name.contains('giải trí') || name.contains('vui chơi') || name.contains('phim') || name.contains('game')) return 'Giải trí';
    if (name.contains('thuốc') || name.contains('bệnh') || name.contains('y tế') || name.contains('sức khỏe') || name.contains('thể thao')) return 'Sức khỏe';
    if (name.contains('học') || name.contains('giáo dục') || name.contains('sách') || name.contains('trường')) return 'Giáo dục';
    if (name.contains('điện') || name.contains('nước') || name.contains('internet') || name.contains('hóa đơn') || name.contains('gas') || name.contains('dịch vụ')) return 'Hóa đơn';
    if (name.contains('du lịch') || name.contains('travel')) return 'Du lịch';
    return categoryName.isEmpty ? 'Khác' : categoryName;
  }

  List<Map<String, double>> _computeMonthlyData() {
    final now = DateTime.now();
    final result = <Map<String, double>>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      double income = 0, expense = 0;
      for (final t in _allTransactions) {
        if (t.transactionDate.year == month.year && t.transactionDate.month == month.month) {
          if (t.type == 'income') income += t.amount;
          else expense += t.amount;
        }
      }
      result.add({'income': income, 'expense': expense});
    }
    return result;
  }

  List<double> _computeWeeklyData() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final result = <double>[];
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      double expense = 0;
      for (final t in _allTransactions) {
        if (t.transactionDate.year == day.year && t.transactionDate.month == day.month && t.transactionDate.day == day.day && t.type == 'expense') {
          expense += t.amount;
        }
      }
      result.add(expense);
    }
    return result;
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}tr';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}k';
    return NumberFormat('#,###', 'vi').format(amount);
  }

  String _formatMoneyFull(double amount) {
    return '${NumberFormat('#,###', 'vi').format(amount)} đ';
  }

  double get _savingPercent {
    if (_totalIncome <= 0) return 0;
    return ((_totalIncome - _totalExpense) / _totalIncome * 100).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthLabel = 'Tháng ${now.month}/${now.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(monthLabel)),
            SliverToBoxAdapter(child: _buildTabBar()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildDonutSection(),
                  const SizedBox(height: 16),
                  _buildMonthlyBarChart(),
                  const SizedBox(height: 16),
                  _buildWeeklyLineChart(),
                  const SizedBox(height: 16),
                  _buildTopCategoriesSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String monthLabel) {
    return Container(
      decoration: const BoxDecoration(
        // ĐỒNG BỘ: Gradient chuẩn Galaxy
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              right: -30, top: -20,
              child: Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
            ),
            Positioned(
              right: 40, top: 30,
              child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thống Kê & Báo Cáo', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  Text(monthLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildSummaryCard('Thu nhập', _formatMoney(_totalIncome)),
                      const SizedBox(width: 10),
                      _buildSummaryCard('Chi tiêu', _formatMoney(_totalExpense)),
                      const SizedBox(width: 10),
                      _buildSummaryCard('Tiết kiệm', '${_savingPercent.toStringAsFixed(0)}%'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _selectedTab = i; _computeStats(); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: selected ? _primary : Colors.transparent, borderRadius: BorderRadius.circular(26)),
                child: Text(_tabs[i], textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : Colors.grey.shade600, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDonutSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phân bố chi tiêu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text('Tổng: ${_formatMoneyFull(_totalExpense)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          if (_topCategories.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Chưa có dữ liệu chi tiêu', style: TextStyle(color: Colors.grey))))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 150, height: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2, centerSpaceRadius: 42, startDegreeOffset: -90,
                      sections: _buildPieSections(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      _topCategories.length,
                          (i) {
                        final entry = _topCategories[i];
                        final color = _chartColors[i % _chartColors.length];
                        final pct = _totalExpense > 0 ? (entry.value / _totalExpense * 100).toStringAsFixed(0) : '0';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                              Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    return List.generate(_topCategories.length, (i) {
      final entry = _topCategories[i];
      final pct = _totalExpense > 0 ? (entry.value / _totalExpense * 100) : 0.0;
      return PieChartSectionData(
        value: entry.value, color: _chartColors[i % _chartColors.length], radius: 40, showTitle: false,
        title: '${pct.toStringAsFixed(0)}%', titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      );
    });
  }

  Widget _buildMonthlyBarChart() {
    final now = DateTime.now();
    final monthLabels = List.generate(6, (i) {
      final m = DateTime(now.year, now.month - 5 + i, 1);
      return 'T${m.month}';
    });

    final maxVal = _monthlyData.fold<double>(0, (prev, m) {
      final v = [m['income']!, m['expense']!].reduce((a, b) => a > b ? a : b);
      return v > prev ? v : prev;
    });

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thu - Chi theo tháng', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(const Color(0xFF1D4ED8), 'Thu nhập'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFFB7185), 'Chi tiêu'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: _monthlyData.isEmpty
                ? const Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey)))
                : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal * 1.2 : 10,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(_formatMoney(rod.toY), const TextStyle(color: Colors.white, fontSize: 11));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= monthLabels.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(monthLabels[idx], style: const TextStyle(fontSize: 11, color: Colors.grey)));
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  _monthlyData.length,
                      (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(toY: _monthlyData[i]['income']!, color: const Color(0xFF1D4ED8), width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      BarChartRodData(toY: _monthlyData[i]['expense']!, color: const Color(0xFFFB7185), width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildWeeklyLineChart() {
    final dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final maxVal = _weeklyData.isEmpty ? 10.0 : _weeklyData.reduce((a, b) => a > b ? a : b);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi tiêu trong tuần', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0, maxX: 6, minY: 0, maxY: maxVal > 0 ? maxVal * 1.3 : 10,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(_formatMoney(s.y), const TextStyle(color: Colors.white, fontSize: 11))).toList(),
                  ),
                ),
                gridData: FlGridData(
                  show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= dayLabels.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(dayLabels[idx], style: const TextStyle(fontSize: 11, color: Colors.grey)));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(_weeklyData.length, (i) => FlSpot(i.toDouble(), _weeklyData[i])),
                    isCurved: true, curveSmoothness: 0.35, color: _primary, barWidth: 2.5,
                    dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: _primary, strokeWidth: 2, strokeColor: Colors.white)),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(colors: [_primary.withValues(alpha: 0.2), _primary.withValues(alpha: 0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategoriesSection() {
    final topFive = _topCategories.take(5).toList();

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top danh mục chi tiêu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          if (topFive.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey))))
          else
            ...List.generate(topFive.length, (i) {
              final entry = topFive[i];
              final color = _chartColors[i % _chartColors.length];
              final ratio = _totalExpense > 0 ? (entry.value / _totalExpense).clamp(0.0, 1.0) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('#${i + 1}', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 10),
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                        Text(_formatMoneyFull(entry.value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation<Color>(color)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: child,
    );
  }
}