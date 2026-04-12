import 'package:flutter/material.dart';

class FinanceStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color backgroundColor;
  final Color titleColor;
  final Color valueColor;

  const FinanceStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.backgroundColor,
    this.titleColor = const Color(0xFFD5FFF4),
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}