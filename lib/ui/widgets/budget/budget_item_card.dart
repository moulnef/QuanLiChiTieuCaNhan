import 'package:flutter/material.dart';

// Core constants & Utils
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/finance_calculator.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/money_formatter.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/category_data.dart';

// Model (Chú ý: model của bạn không có chữ 's' và nằm trong domain)
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';

// Common Widgets (Lùi 1 cấp ra widgets, sau đó vào common)
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/progress_status_bar.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/utils/app_localizer.dart';

class BudgetItemCard extends StatelessWidget {
  final Budget budget;

  const BudgetItemCard({super.key, required this.budget});

  Color _getStatusColor() {
    switch (budget.status) {
      case 'danger':
        return AppColors.danger;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.safe;
    }
  }

  IconData _getStatusIcon() {
    switch (budget.status) {
      case 'danger':
        return Icons.cancel_outlined;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final alert = FinanceCalculator.getBudgetAlertMessage(
      progressPercent: budget.progressPercent,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(budget.icon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CategoryData.resolveDisplayName(
                        budget.categoryId,
                        budget.categoryName,
                      ).xtrCategory(context),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${budget.progressPercent}% ' + 'đã dùng'.xtr(context),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(_getStatusIcon(), color: statusColor, size: 28),
            ],
          ),
          const SizedBox(height: 14),
          ProgressStatusBar(
            progress: budget.progressPercent,
            color: statusColor,
            height: 10,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đã chi: '.xtr(context) +
                      MoneyFormatter.formatVnd(budget.spentAmount),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                'Còn lại: '.xtr(context) +
                    MoneyFormatter.formatVnd(budget.remainingAmount),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.safe,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (alert != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                alert.xtr(context),
                style: TextStyle(
                  fontSize: 15,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
