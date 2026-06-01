import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../domain/model/transaction_model.dart';
import '../../../ui/providers/auth_provider.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _currentTab = 0;
  String _userSearch = '';
  String _categoryFilter = 'all';
  bool _notifOpen = false;

  final _menu = const [
    _AdminMenuItem('Tổng quan', Icons.dashboard_rounded),
    _AdminMenuItem('Người dùng', Icons.groups_rounded),
    _AdminMenuItem('Danh mục', Icons.sell_rounded),
    _AdminMenuItem('Phân tích', Icons.stacked_line_chart_rounded),
    _AdminMenuItem('Cài đặt', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots();
    final txStream = FirebaseFirestore.instance
        .collectionGroup('transactions')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: Drawer(
        child: SafeArea(
          child: _AdminSideMenu(
            items: _menu,
            selectedIndex: _currentTab,
            onSelect: (index) {
              Navigator.pop(context);
              setState(() => _currentTab = index);
            },
            onSignOut: () => context.read<AuthProvider>().signOut(),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: usersStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _errorView(userSnapshot.error.toString());
          }
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: txStream,
            builder: (context, txSnapshot) {
              if (txSnapshot.hasError) {
                return _errorView(txSnapshot.error.toString());
              }
              if (!txSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = userSnapshot.data!.docs;
              final transactions = txSnapshot.data!.docs
                  .map(
                    (doc) => TransactionModel.fromMap(
                      Map<String, dynamic>.from(doc.data()),
                      doc.id,
                    ),
                  )
                  .toList();

              final data = _AdminData.from(users, transactions);

              return SafeArea(
                top: true,
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 1024;
                    return Row(
                      children: [
                        if (desktop)
                          SizedBox(
                            width: 240,
                            child: _AdminSideMenu(
                              items: _menu,
                              selectedIndex: _currentTab,
                              onSelect: (index) =>
                                  setState(() => _currentTab = index),
                              onSignOut: () =>
                                  context.read<AuthProvider>().signOut(),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            children: [
                              _AdminTopBar(
                                title: _menu[_currentTab].label,
                                desktop: desktop,
                                notifOpen: _notifOpen,
                                onNotifToggle: () =>
                                    setState(() => _notifOpen = !_notifOpen),
                                onNotifClose: () =>
                                    setState(() => _notifOpen = false),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.fromLTRB(
                                    desktop ? 20 : 14,
                                    16,
                                    desktop ? 20 : 14,
                                    desktop ? 24 : 120,
                                  ),
                                  child: _buildTabContent(context, data)
                                      .animate()
                                      .fadeIn(duration: 220.ms)
                                      .slideY(begin: 0.04, end: 0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, _AdminData data) {
    switch (_currentTab) {
      case 0:
        return _buildOverview(context, data);
      case 1:
        return _buildUsersTab(context, data);
      case 2:
        return _buildCategoriesTab(data);
      case 3:
        return _buildAnalyticsTab(data);
      case 4:
        return const _AdminSettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverview(BuildContext context, _AdminData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(data),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080
                ? 3
                : constraints.maxWidth >= 720
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;

            final kpis = [
              _KpiUi(
                title: 'Tổng người dùng',
                value: NumberFormat('#,###', 'vi').format(data.totalUsers),
                subtitle: 'Đang tồn tại trong hệ thống',
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFF3B82F6),
                iconBg: const Color(0xFFEFF6FF),
                deltaText:
                    '${data.userGrowthPct >= 0 ? '+' : ''}${data.userGrowthPct.toStringAsFixed(1)}%',
                deltaPositive: data.userGrowthPct >= 0,
              ),
              _KpiUi(
                title: 'Tổng giao dịch',
                value: NumberFormat(
                  '#,###',
                  'vi',
                ).format(data.totalTransactions),
                subtitle: 'Tổng số giao dịch theo dõi',
                icon: Icons.swap_horiz_rounded,
                iconColor: const Color(0xFF8B5CF6),
                iconBg: const Color(0xFFF5F3FF),
                deltaText:
                    '${data.transactionGrowthPct >= 0 ? '+' : ''}${data.transactionGrowthPct.toStringAsFixed(1)}%',
                deltaPositive: data.transactionGrowthPct >= 0,
              ),
              _KpiUi(
                title: 'Tổng thu nhập',
                value: _money(data.totalIncome),
                subtitle: 'Cộng dồn từ giao dịch income',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF16A34A),
                iconBg: const Color(0xFFF0FDF4),
                deltaText:
                    '${data.incomeGrowthPct >= 0 ? '+' : ''}${data.incomeGrowthPct.toStringAsFixed(1)}%',
                deltaPositive: data.incomeGrowthPct >= 0,
              ),
            ];

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kpis
                  .asMap()
                  .entries
                  .map(
                    (entry) => SizedBox(
                      width: width,
                      child: _KpiCard(item: entry.value)
                          .animate()
                          .fadeIn(duration: (220 + (entry.key * 60)).ms)
                          .slideY(begin: 0.1, end: 0),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 980) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _panel(
                      title: 'Khối lượng giao dịch',
                      subtitle: 'Thu nhập và chi tiêu theo 6 tháng gần nhất',
                      child: _monthlyBarChart(data.monthly),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _panel(
                      title: 'Hoạt động gần đây',
                      subtitle: 'Từ các giao dịch mới nhất',
                      child: _activityList(data.recentTransactions),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _panel(
                  title: 'Khối lượng giao dịch',
                  subtitle: 'Thu nhập và chi tiêu theo 6 tháng gần nhất',
                  child: _monthlyBarChart(data.monthly),
                ),
                const SizedBox(height: 12),
                _panel(
                  title: 'Hoạt động gần đây',
                  subtitle: 'Từ các giao dịch mới nhất',
                  child: _activityList(data.recentTransactions),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildUsersTab(BuildContext context, _AdminData data) {
    final normalized = _userSearch.trim().toLowerCase();
    final users = data.users.where((u) {
      if (normalized.isEmpty) return true;
      final email = (u['email'] ?? '').toString().toLowerCase();
      final name = (u['displayName'] ?? '').toString().toLowerCase();
      return email.contains(normalized) || name.contains(normalized);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          title: 'Quản lý người dùng',
          subtitle: '${users.length} tài khoản hiển thị',
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc email...',
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (value) => setState(() => _userSearch = value),
              ),
              const SizedBox(height: 12),
              if (users.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Text(
                    'Không có người dùng phù hợp.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              else
                ...users.take(80).map((user) {
                  final email = (user['email'] ?? 'Chưa có email').toString();
                  final role = (user['role'] ?? 'user').toString();
                  final name = _displayName(user);
                  final createdAt = _formatDate(user['createdAt']);
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFDBEAFE),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Đăng ký: $createdAt',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _roleBadge(role),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () => _openUserSheet(context, user),
                            child: const Text('Chi tiết'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(_AdminData data) {
    final categories = data.categories.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    final filtered = categories.where((entry) {
      if (_categoryFilter == 'all') return true;
      return entry.value.type == _categoryFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          title: 'Danh mục',
          subtitle: 'Tổng hợp tự động từ transactions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('all', 'Tất cả'),
                  _filterChip('expense', 'Chi tiêu'),
                  _filterChip('income', 'Thu nhập'),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Chưa có dữ liệu danh mục.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              else
                ...filtered.take(80).map((entry) {
                  final stat = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: stat.type == 'income'
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              stat.type == 'income'
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: stat.type == 'income'
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB91C1C),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${stat.count} lượt • ${_money(stat.total)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _typeBadge(stat.type),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab(_AdminData data) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 920) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _panel(
                      title: 'Tăng trưởng người dùng',
                      subtitle: 'So sánh tháng này với tháng trước',
                      child: _lineUsersChart(data.monthly),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _panel(
                      title: 'Top danh mục',
                      subtitle: 'Theo số lượt giao dịch',
                      child: _topCategoryChart(data.categories),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _panel(
                  title: 'Tăng trưởng người dùng',
                  subtitle: 'So sánh tháng này với tháng trước',
                  child: _lineUsersChart(data.monthly),
                ),
                const SizedBox(height: 12),
                _panel(
                  title: 'Top danh mục',
                  subtitle: 'Theo số lượt giao dịch',
                  child: _topCategoryChart(data.categories),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Tóm tắt hiệu suất',
          subtitle: 'Từ dữ liệu thực trong Firestore',
          child: Column(
            children: [
              _summaryRow(
                'Người dùng mới 30 ngày',
                '${data.newUsersLast30Days}',
              ),
              _summaryRow(
                'Giao dịch 30 ngày',
                '${data.last30DaysTransactions}',
              ),
              _summaryRow('Thu nhập 30 ngày', _money(data.last30DaysIncome)),
              _summaryRow('Chi tiêu 30 ngày', _money(data.last30DaysExpense)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String text) {
    final active = _categoryFilter == value;
    return InkWell(
      onTap: () => setState(() => _categoryFilter = value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _heroCard(_AdminData data) {
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    final name = (currentUser?.displayName?.trim().isNotEmpty == true)
        ? currentUser!.displayName!.trim()
        : 'Admin';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Panel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Xin chào, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hệ thống đang theo dõi ${data.totalUsers} người dùng và ${data.totalTransactions} giao dịch.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _monthlyBarChart(List<_MonthlyStat> monthly) {
    if (monthly.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Chưa có dữ liệu')),
      );
    }

    final maxY = monthly.fold<double>(
      0,
      (prev, e) => math.max(prev, math.max(e.income, e.expense)),
    );

    return SizedBox(
      height: 230,
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= monthly.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      monthly[index].label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < monthly.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: monthly[i].income,
                    width: 8,
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: monthly[i].expense,
                    width: 8,
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _lineUsersChart(List<_MonthlyStat> monthly) {
    if (monthly.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Chưa có dữ liệu')),
      );
    }

    final maxY = monthly.fold<int>(0, (prev, m) => math.max(prev, m.userCount));

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY * 1.25,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= monthly.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      monthly[index].label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
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
                for (var i = 0; i < monthly.length; i++)
                  FlSpot(i.toDouble(), monthly[i].userCount.toDouble()),
              ],
              isCurved: true,
              color: const Color(0xFF2563EB),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.24),
                    const Color(0xFF2563EB).withValues(alpha: 0.03),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topCategoryChart(Map<String, _CategoryStat> categories) {
    final top = categories.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    if (top.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Chưa có dữ liệu')),
      );
    }

    final topFive = top.take(5).toList();
    final maxCount = topFive.first.value.count.toDouble();

    return Column(
      children: topFive.map((entry) {
        final pct = maxCount <= 0
            ? 0.0
            : (entry.value.count / maxCount).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value.count}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: pct,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    entry.value.type == 'income'
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _activityList(List<TransactionModel> tx) {
    if (tx.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Chưa có hoạt động mới',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Column(
      children: tx.take(8).map((item) {
        final isIncome = item.type.toLowerCase() == 'income';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isIncome ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIncome
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 16,
                  color: isIncome
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.categoryName.isEmpty ? 'Khác' : item.categoryName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(item.transactionDate),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'}${_money(item.amount)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isIncome
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _roleBadge(String role) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isAdmin ? const Color(0xFFE0E7FF) : const Color(0xFFF1F5F9),
      ),
      child: Text(
        isAdmin ? 'admin' : 'user',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isAdmin ? const Color(0xFF4338CA) : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _typeBadge(String type) {
    final income = type == 'income';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: income ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
      ),
      child: Text(
        income ? 'income' : 'expense',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: income ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }

  void _openUserSheet(BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final email = (user['email'] ?? 'Chưa có email').toString();
        final role = (user['role'] ?? 'user').toString();
        final name = _displayName(user);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Email: $email',
                style: const TextStyle(color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              Text(
                'Role: $role',
                style: const TextStyle(color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              Text(
                'Created: ${_formatDate(user['createdAt'])}',
                style: const TextStyle(color: Color(0xFF334155)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _displayName(Map<String, dynamic> user) {
    final displayName = (user['displayName'] ?? '').toString().trim();
    if (displayName.isNotEmpty) return displayName;
    final email = (user['email'] ?? '').toString();
    if (email.contains('@')) return email.split('@').first;
    return 'Người dùng';
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '--';
    DateTime? date;
    if (raw is Timestamp) date = raw.toDate();
    if (raw is DateTime) date = raw;
    if (raw is String) date = DateTime.tryParse(raw);
    if (raw is int) date = DateTime.fromMillisecondsSinceEpoch(raw);
    if (date == null) return '--';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  String _money(double value) {
    if (value.abs() >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)} tỷ';
    }
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} triệu';
    }
    return NumberFormat('#,###', 'vi').format(value);
  }
}

class _AdminSideMenu extends StatelessWidget {
  const _AdminSideMenu({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSignOut,
  });

  final List<_AdminMenuItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    final adminName = (currentUser?.displayName?.trim().isNotEmpty == true)
        ? currentUser!.displayName!.trim()
        : 'Admin';

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FinSmart',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              itemCount: items.length,
              itemBuilder: (_, index) {
                final item = items[index];
                final active = selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () => onSelect(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFEFF6FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 18,
                            color: active
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: active
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          if (active)
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFDBEAFE),
                        child: Text(
                          adminName.isNotEmpty
                              ? adminName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          adminName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Đăng xuất'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.title,
    required this.desktop,
    required this.notifOpen,
    required this.onNotifToggle,
    required this.onNotifClose,
  });

  final String title;
  final bool desktop;
  final bool notifOpen;
  final VoidCallback onNotifToggle;
  final VoidCallback onNotifClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          desktop ? 16 : 8,
          10,
          desktop ? 16 : 10,
          10,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            if (!desktop)
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
            if (!desktop) const SizedBox(width: 2),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            SizedBox(
              width: desktop ? 280 : 165,
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Tìm kiếm...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, size: 17),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onNotifToggle,
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (notifOpen)
                  Positioned(
                    top: 40,
                    right: 0,
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 250,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _notifItem(
                              '3 tài khoản cần xem xét',
                              '5 phút trước',
                              const Color(0xFFEF4444),
                              onNotifClose,
                            ),
                            _notifItem(
                              'Báo cáo tháng mới đã sẵn sàng',
                              '1 giờ trước',
                              const Color(0xFF3B82F6),
                              onNotifClose,
                            ),
                            _notifItem(
                              'Hệ thống đồng bộ thành công',
                              '2 giờ trước',
                              const Color(0xFF16A34A),
                              onNotifClose,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifItem(String title, String time, Color dot, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final _KpiUi item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.deltaPositive
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.deltaPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: item.deltaPositive
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      item.deltaText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: item.deltaPositive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _AdminSettingsTab extends StatefulWidget {
  const _AdminSettingsTab();

  @override
  State<_AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<_AdminSettingsTab> {
  bool emailAlert = true;
  bool securityLog = true;
  bool maintenanceMode = false;
  bool animateUi = true;

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cài đặt hệ thống',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Giữ dữ liệu mặc định, chỉ thay đổi giao diện theo thiết kế admin.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          _switchTile(
            title: 'Thông báo email cho admin',
            value: emailAlert,
            onChanged: (v) => setState(() => emailAlert = v),
          ),
          _switchTile(
            title: 'Bật audit log bảo mật',
            value: securityLog,
            onChanged: (v) => setState(() => securityLog = v),
          ),
          _switchTile(
            title: 'Maintenance mode',
            value: maintenanceMode,
            onChanged: (v) => setState(() => maintenanceMode = v),
          ),
          _switchTile(
            title: 'Hiệu ứng giao diện',
            value: animateUi,
            onChanged: (v) => setState(() => animateUi = v),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã lưu cài đặt giao diện')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Lưu thay đổi'),
            ),
          ),
          SizedBox(height: 88 + bottomSafe),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: SwitchListTile(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF2563EB),
          activeTrackColor: const Color(0xFFBFDBFE),
        ),
      ),
    );
  }
}

class _AdminData {
  const _AdminData({
    required this.users,
    required this.totalUsers,
    required this.totalTransactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.categories,
    required this.recentTransactions,
    required this.monthly,
    required this.newUsersLast30Days,
    required this.last30DaysTransactions,
    required this.last30DaysIncome,
    required this.last30DaysExpense,
    required this.userGrowthPct,
    required this.transactionGrowthPct,
    required this.incomeGrowthPct,
  });

  final List<Map<String, dynamic>> users;
  final int totalUsers;
  final int totalTransactions;
  final double totalIncome;
  final double totalExpense;
  final Map<String, _CategoryStat> categories;
  final List<TransactionModel> recentTransactions;
  final List<_MonthlyStat> monthly;
  final int newUsersLast30Days;
  final int last30DaysTransactions;
  final double last30DaysIncome;
  final double last30DaysExpense;
  final double userGrowthPct;
  final double transactionGrowthPct;
  final double incomeGrowthPct;

  factory _AdminData.from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    List<TransactionModel> tx,
  ) {
    final users = userDocs.map((e) => e.data()).toList();

    final now = DateTime.now();
    final start30 = now.subtract(const Duration(days: 30));
    final prevStart = now.subtract(const Duration(days: 60));

    final categories = <String, _CategoryStat>{};
    var totalIncome = 0.0;
    var totalExpense = 0.0;

    for (final t in tx) {
      final type = t.type.toLowerCase() == 'income' ? 'income' : 'expense';
      final name = t.categoryName.trim().isEmpty
          ? 'Khác'
          : t.categoryName.trim();
      final old = categories[name];
      categories[name] = _CategoryStat(
        count: (old?.count ?? 0) + 1,
        total: (old?.total ?? 0) + t.amount,
        type: old?.type ?? type,
      );

      if (type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    final monthly = _buildMonthlyStats(users, tx, now);

    final recentTransactions = [...tx]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    final newUsers30 = users.where((u) {
      final createdAt = _toDate(u['createdAt']);
      return createdAt != null && createdAt.isAfter(start30);
    }).length;

    final newUsersPrev30 = users.where((u) {
      final createdAt = _toDate(u['createdAt']);
      return createdAt != null &&
          createdAt.isAfter(prevStart) &&
          createdAt.isBefore(start30);
    }).length;

    final tx30 = tx.where((t) => t.transactionDate.isAfter(start30)).toList();
    final txPrev30 = tx
        .where(
          (t) =>
              t.transactionDate.isAfter(prevStart) &&
              t.transactionDate.isBefore(start30),
        )
        .toList();

    final income30 = tx30
        .where((t) => t.type.toLowerCase() == 'income')
        .fold<double>(0, (p, e) => p + e.amount);
    final incomePrev30 = txPrev30
        .where((t) => t.type.toLowerCase() == 'income')
        .fold<double>(0, (p, e) => p + e.amount);
    final expense30 = tx30
        .where((t) => t.type.toLowerCase() != 'income')
        .fold<double>(0, (p, e) => p + e.amount);

    return _AdminData(
      users: users,
      totalUsers: users.length,
      totalTransactions: tx.length,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      categories: categories,
      recentTransactions: recentTransactions,
      monthly: monthly,
      newUsersLast30Days: newUsers30,
      last30DaysTransactions: tx30.length,
      last30DaysIncome: income30,
      last30DaysExpense: expense30,
      userGrowthPct: _pctDelta(
        newUsers30.toDouble(),
        newUsersPrev30.toDouble(),
      ),
      transactionGrowthPct: _pctDelta(
        tx30.length.toDouble(),
        txPrev30.length.toDouble(),
      ),
      incomeGrowthPct: _pctDelta(income30, incomePrev30),
    );
  }

  static List<_MonthlyStat> _buildMonthlyStats(
    List<Map<String, dynamic>> users,
    List<TransactionModel> tx,
    DateTime now,
  ) {
    final output = <_MonthlyStat>[];
    final monthFmt = DateFormat('MM/yy');

    for (var i = 5; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final next = DateTime(monthStart.year, monthStart.month + 1, 1);

      final usersCount = users.where((u) {
        final created = _toDate(u['createdAt']);
        if (created == null) return false;
        return !created.isBefore(monthStart) && created.isBefore(next);
      }).length;

      final income = tx
          .where(
            (t) =>
                !t.transactionDate.isBefore(monthStart) &&
                t.transactionDate.isBefore(next) &&
                t.type.toLowerCase() == 'income',
          )
          .fold<double>(0, (p, e) => p + e.amount);

      final expense = tx
          .where(
            (t) =>
                !t.transactionDate.isBefore(monthStart) &&
                t.transactionDate.isBefore(next) &&
                t.type.toLowerCase() != 'income',
          )
          .fold<double>(0, (p, e) => p + e.amount);

      output.add(
        _MonthlyStat(
          label: monthFmt.format(monthStart),
          userCount: usersCount,
          income: income,
          expense: expense,
        ),
      );
    }

    return output;
  }

  static DateTime? _toDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static double _pctDelta(double current, double previous) {
    if (previous == 0 && current == 0) return 0;
    if (previous == 0) return 100;
    return ((current - previous) / previous) * 100;
  }
}

class _CategoryStat {
  const _CategoryStat({
    required this.count,
    required this.total,
    required this.type,
  });

  final int count;
  final double total;
  final String type;
}

class _MonthlyStat {
  const _MonthlyStat({
    required this.label,
    required this.userCount,
    required this.income,
    required this.expense,
  });

  final String label;
  final int userCount;
  final double income;
  final double expense;
}

class _AdminMenuItem {
  const _AdminMenuItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _KpiUi {
  const _KpiUi({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.deltaText,
    required this.deltaPositive,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String deltaText;
  final bool deltaPositive;
}
