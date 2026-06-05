import 'package:flutter/material.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
// Chú ý: model không có chữ 's'
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/utils/app_localizer.dart';

class BudgetVsActualChart extends StatelessWidget {
  final List<Budget> budgets;

  const BudgetVsActualChart({
    super.key,
    required this.budgets,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = budgets.isEmpty
        ? 1
        : budgets
        .map((e) => e.limitAmount > e.spentAmount ? e.limitAmount : e.spentAmount)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ngân sách vs Thực tế'.xtr(context),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 210,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: budgets.map((budget) {
                final budgetFactor = budget.limitAmount / maxValue;
                final spentFactor = budget.spentAmount / maxValue;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 12,
                                  height: 130 * budgetFactor,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCE9FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 12,
                                  height: 130 * spentFactor,
                                  decoration: BoxDecoration(
                                    color: _getBarColor(budget.status),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            children: [
                              () {
                                final clean = budget.icon.trim();
                                int? codePoint = int.tryParse(clean);
                                if (codePoint == null) {
                                  var hexStr = clean;
                                  if (hexStr.toLowerCase().startsWith('0x')) {
                                    hexStr = hexStr.substring(2);
                                  }
                                  codePoint = int.tryParse(hexStr, radix: 16);
                                }
                                if (codePoint != null) {
                                  return TextSpan(
                                    text: String.fromCharCode(codePoint),
                                    style: const TextStyle(
                                      fontFamily: 'MaterialIcons',
                                      fontSize: 12,
                                    ),
                                  );
                                } else {
                                  return TextSpan(text: budget.icon);
                                }
                              }(),
                              TextSpan(text: ' ${budget.categoryName.xtrCategory(context)}'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _LegendDot(color: Color(0xFFDCE9FF)),
              const SizedBox(width: 6),
              Text(
                'Ngân sách'.xtr(context),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 24),
              const _LegendDot(color: AppColors.blue),
              const SizedBox(width: 6),
              Text(
                'Thực tế'.xtr(context),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBarColor(String status) {
    switch (status) {
      case 'danger':
        return AppColors.danger;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.blue;
    }
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;

  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}