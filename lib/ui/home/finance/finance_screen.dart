import 'package:flutter/material.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/finance_stat_card.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/progress_card.dart';

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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.financeGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
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
            children: const [
              Expanded(
                child: FinanceStatCard(
                  title: 'Đang tiết kiệm',
                  value: '58.5tr',
                  backgroundColor: Color(0xFF229A7D),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: FinanceStatCard(
                  title: 'Còn trả góp',
                  value: '23.5tr',
                  backgroundColor: Color(0xFF229A7D),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: FinanceStatCard(
                  title: 'Còn vay',
                  value: '7.5tr',
                  backgroundColor: Color(0xFF229A7D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class SavingTabPage extends StatelessWidget {
  const SavingTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
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
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            side: const BorderSide(color: Color(0xFF8CF0D1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            '+  Tạo mục tiêu mới',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.financeGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class InstallmentTabPage extends StatelessWidget {
  const InstallmentTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
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
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            side: const BorderSide(color: Color(0xFFB9D7FF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            '+  Thêm kế hoạch trả góp',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
class DebtTabPage extends StatelessWidget {
  const DebtTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
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
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            side: const BorderSide(color: Color(0xFFF7C58C)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            '+  Thêm khoản vay',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFFEA580C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}