import 'package:flutter/material.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
// Gọi các file cùng thư mục common thì không cần package:
import 'finance_action_button.dart';
import 'progress_status_bar.dart';

class ProgressCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final int progressPercent;
  final Color progressColor;

  final String? primaryButtonText;
  final String? secondaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  final String? alertMessage;
  final Color? alertColor;

  const ProgressCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    required this.progressPercent,
    required this.progressColor,
    this.primaryButtonText,
    this.secondaryButtonText,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
    this.alertMessage,
    this.alertColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProgressStatusBar(
            progress: progressPercent,
            color: progressColor,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoBlock(
                  label: leftLabel,
                  value: leftValue,
                  valueColor: progressColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoBlock(
                  label: rightLabel,
                  value: rightValue,
                  valueColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (primaryButtonText != null || secondaryButtonText != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (primaryButtonText != null)
                  Expanded(
                    child: FinanceActionButton(
                      text: primaryButtonText!,
                      onPressed: onPrimaryPressed,
                    ),
                  ),
                if (primaryButtonText != null && secondaryButtonText != null)
                  const SizedBox(width: 12),
                if (secondaryButtonText != null)
                  Expanded(
                    child: FinanceActionButton(
                      text: secondaryButtonText!,
                      onPressed: onSecondaryPressed,
                      backgroundColor: const Color(0xFFF3F4F6),
                      textColor: const Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ],
          if (alertMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (alertColor ?? AppColors.warning).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                alertMessage!,
                style: TextStyle(
                  color: alertColor ?? AppColors.warning,
                  fontSize: 14,
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

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _InfoBlock({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}