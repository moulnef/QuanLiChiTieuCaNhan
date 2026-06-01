import 'package:flutter/material.dart';
// Dùng package path để không bao giờ bị sai cấp độ lùi
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/money_formatter.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/progress_status_bar.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/utils/app_localizer.dart';
class BudgetSummaryCard extends StatelessWidget {
  final int totalSpent;
  final int totalLimit;
  final int progressPercent;

  const BudgetSummaryCard({
    super.key,
    required this.totalSpent,
    required this.totalLimit,
    required this.progressPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9333),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng ngân sách tháng 3'.xtr(context),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const ProgressStatusBar(
            progress: 0,
            color: Colors.transparent,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(
                    color: const Color(0xFFFFC48D),
                  ),
                  FractionallySizedBox(
                    widthFactor: (progressPercent.clamp(0, 100)) / 100,
                    child: Container(
                      color: const Color(0xFF5DD58E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đã dùng: '.xtr(context) + MoneyFormatter.formatVnd(totalSpent),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'Giới hạn: '.xtr(context) + MoneyFormatter.formatVnd(totalLimit),
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}