import 'package:flutter/material.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/budget.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/category_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/local/category_data.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/utils/app_localizer.dart';

class AddBudgetFormSheet extends StatefulWidget {
  final String userId;
  final Budget? budget;
  final void Function(Budget newBudget) onSubmit;

  const AddBudgetFormSheet({
    super.key,
    required this.userId,
    this.budget,
    required this.onSubmit,
  });

  @override
  State<AddBudgetFormSheet> createState() => _AddBudgetFormSheetState();
}

class _AddBudgetFormSheetState extends State<AddBudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _limitController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedIcon;

  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _selectedCategoryId = widget.budget!.categoryId;
      _selectedCategoryName = widget.budget!.categoryName;
      _selectedIcon = widget.budget!.icon;
      _limitController.text = widget.budget!.limitAmount.toInt().toString();
      _selectedMonth = widget.budget!.month;
      _selectedYear = widget.budget!.year;
    } else {
      final now = DateTime.now();
      _selectedMonth = now.month;
      _selectedYear = now.year;
    }
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedCategoryName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vui lòng chọn danh mục'.xtr(context))));
      return;
    }

    final limitAmount = double.tryParse(_limitController.text.trim()) ?? 0;
    if (limitAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hạn mức phải lớn hơn 0'.xtr(context))));
      return;
    }

    final now = DateTime.now();

    final newBudget = Budget(
      id:
          widget.budget?.id ??
          'budget_${DateTime.now().millisecondsSinceEpoch}',
      userId: widget.userId,
      categoryId: _selectedCategoryId!,
      categoryName: _selectedCategoryName!,
      icon: _selectedIcon ?? '📁',
      month: _selectedMonth,
      year: _selectedYear,
      limitAmount: limitAmount,
      spentAmount: widget.budget?.spentAmount ?? 0,
      createdAt: widget.budget?.createdAt ?? now,
      updatedAt: now,
      status: widget.budget?.status ?? 'safe',
    );

    widget.onSubmit(newBudget);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.budget != null
                    ? 'Chỉnh sửa ngân sách'.xtr(context)
                    : 'Thêm ngân sách mới'.xtr(context),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Danh mục'.xtr(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<CategoryModel>>(
                stream: _firestoreService.streamCategories(),
                builder: (context, snapshot) {
                  // Lấy dữ liệu từ Firestore, nếu lỗi hoặc trống thì dùng CategoryData cục bộ
                  final remoteItems =
                      snapshot.data
                          ?.where((item) => item.type == 'expense')
                          .toList() ??
                      [];
                  final expenseCategories = remoteItems.isNotEmpty
                      ? remoteItems
                      : CategoryData.getExpenseCategories();

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      remoteItems.isEmpty &&
                      snapshot.error == null) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  // Luôn hiển thị nếu có CategoryData làm dự phòng
                  if (expenseCategories.isEmpty) {
                    return Text(
                      'Không tìm thấy danh mục chi tiêu nào trong tài khoản. Hãy tạo danh mục trước.'.xtr(context),
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    items: expenseCategories.map((item) {
                      return DropdownMenuItem<String>(
                        value: item.id,
                        child: Row(
                          children: [
                            Text(
                              (item.icon != null && item.icon!.isNotEmpty)
                                  ? item.icon!
                                  : '📁',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(item.name.xtrCategory(context)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      final selected = expenseCategories.firstWhere(
                        (item) => item.id == value,
                      );
                      setState(() {
                        _selectedCategoryId = selected.id;
                        _selectedCategoryName = selected.name;
                        _selectedIcon = selected.icon;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Chọn danh mục'.xtr(context),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng chọn danh mục'.xtr(context);
                      }
                      return null;
                    },
                  );
                },
              ),

              const SizedBox(height: 16),

              Text(
                'Hạn mức (VNĐ)'.xtr(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: 3000000'.xtr(context),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập hạn mức'.xtr(context);
                  }
                  final number = int.tryParse(value.trim());
                  if (number == null || number <= 0) {
                    return 'Hạn mức phải là số nguyên dương'.xtr(context);
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tháng'.xtr(context),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedMonth,
                          items: List.generate(12, (index) => index + 1)
                              .map(
                                (month) => DropdownMenuItem(
                                  value: month,
                                  child: Text('Tháng '.xtr(context) + '$month'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedMonth = value!;
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Năm'.xtr(context),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedYear,
                          items: [2025, 2026, 2027, 2028]
                              .map(
                                (year) => DropdownMenuItem(
                                  value: year,
                                  child: Text('$year'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value!;
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Lưu ngân sách'.xtr(context),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
