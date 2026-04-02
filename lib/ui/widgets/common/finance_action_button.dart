import 'package:flutter/material.dart';
// File này chỉ cần gọi AppColors là xanh ngay
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';

class FinanceActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color textColor;
  final double height;

  const FinanceActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = AppColors.softGreen,
    this.textColor = AppColors.financeGreen,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}