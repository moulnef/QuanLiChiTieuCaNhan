import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'saving_tab.dart';
import 'installment_tab.dart';
import 'debt_tab.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FinanceBody();
  }
}

class _FinanceBody extends StatelessWidget {
  const _FinanceBody();

  String _formatTr(num amount) {
    return '${(amount / 1000000).toStringAsFixed(1)}tr';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Container(
        color: const Color(0xFFF8FAFC), // Nền xám cực nhạt
        child: Column(
          children: [
            // TabBar phong cách mới
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Color(0xFF2563EB),
                unselectedLabelColor: Color(0xFF94A3B8),
                indicatorColor: Color(0xFF2563EB),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'Tiết kiệm'),
                  Tab(text: 'Trả góp'),
                  Tab(text: 'Vay nợ'),
                ],
              ),
            ),
            
            // Summary Cards Row
            Consumer<FinanceProvider>(
              builder: (context, provider, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _SummaryMiniCard(
                      title: 'Đang tiết kiệm',
                      value: _formatTr(provider.totalSavingAmount),
                      color: const Color(0xFF10B981),
                      bgColor: const Color(0xFFECFDF5),
                    ),
                    const SizedBox(width: 12),
                    _SummaryMiniCard(
                      title: 'Còn trả góp',
                      value: _formatTr(provider.totalInstallmentRemaining),
                      color: const Color(0xFF3B82F6),
                      bgColor: const Color(0xFFEFF6FF),
                    ),
                    const SizedBox(width: 12),
                    _SummaryMiniCard(
                      title: 'Còn vay',
                      value: _formatTr(provider.totalDebtRemaining),
                      color: const Color(0xFFF59E0B),
                      bgColor: const Color(0xFFFFFBEB),
                    ),
                  ],
                ),
              ),
            ),

            const Expanded(
              child: TabBarView(
                children: [
                  SavingsTab(),
                  InstallmentTabPage(),
                  DebtTabPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final Color bgColor;

  const _SummaryMiniCard({
    required this.title,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
