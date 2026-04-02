import 'package:flutter/material.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';

class ProgressStatusBar extends StatelessWidget {
  final int progress;
  final Color color;
  final double height;
  final double radius;

  const ProgressStatusBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 10,
    this.radius = 999,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0, 100);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.progressBackground,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * (safeProgress / 100);
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          );
        },
      ),
    );
  }
}