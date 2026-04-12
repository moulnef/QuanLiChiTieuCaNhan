import 'package:flutter/material.dart';

// Import màu sắc từ thư mục core
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';

// Import Model Budget (Lưu ý: model không có chữ 's')
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';

// Import file ngang hàng (cùng trong thư mục budget nên viết thế này là đúng)
import 'budget_item_card.dart';

class BudgetHomeSection extends StatelessWidget {
  final List<Budget> budgets;
  final VoidCallback? onViewAll;

  const BudgetHomeSection({
    super.key,
    required this.budgets,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = budgets.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
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
              const Expanded(
                child: Text(
                  'Ngân sách tháng này',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...visibleItems.map((item) => BudgetItemCard(budget: item)),
        ],
      ),
    );
  }
}