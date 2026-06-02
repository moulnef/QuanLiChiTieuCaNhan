import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/finance_stat_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/saving.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/installment_plan.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/debt_record.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/finance/saving_tab.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/finance/installment_tab.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/home/finance/debt_tab.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _FinanceHeader(),
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: AppColors.financeGreen,
                unselectedLabelColor: Color(0xFF9CA3AF),
                indicatorColor: AppColors.financeGreen,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(text: 'Tiết kiệm'),
                  Tab(text: 'Trả góp'),
                  Tab(text: 'Vay nợ'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  SavingTabPage(),
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

class _FinanceHeader extends StatelessWidget {
  const _FinanceHeader();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'user_001';
    final repository = context.read<FinanceRepository>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.financeGreen,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tài Chính',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quản lý tiết kiệm, góp và vay',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xCCFFFFFF),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<SavingGoal>>(
                  stream: repository.streamSavings(userId),
                  builder: (context, snapshot) {
                    final list = snapshot.data ?? [];
                    final count = list.where((item) => item.status != 'completed' && item.currentAmount < item.targetAmount).length;
                    return FinanceStatCard(
                      title: 'Đang tiết kiệm',
                      value: '$count mục',
                      backgroundColor: const Color(0xFF229A7D),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<List<InstallmentPlan>>(
                  stream: repository.streamInstallments(userId),
                  builder: (context, snapshot) {
                    final list = snapshot.data ?? [];
                    final count = list.where((item) => item.status != 'completed' && item.paidAmount < item.totalAmount).length;
                    return FinanceStatCard(
                      title: 'Còn trả góp',
                      value: '$count mục',
                      backgroundColor: const Color(0xFF229A7D),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<List<DebtRecord>>(
                  stream: repository.streamDebts(userId),
                  builder: (context, snapshot) {
                    final list = snapshot.data ?? [];
                    final count = list.where((item) => item.status != 'settled' && item.paidAmount < item.totalAmount).length;
                    return FinanceStatCard(
                      title: 'Còn vay',
                      value: '$count mục',
                      backgroundColor: const Color(0xFF229A7D),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}