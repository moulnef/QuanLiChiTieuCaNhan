import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_group.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_member.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_expense.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/money_formatter.dart';
import '../providers/split_provider.dart';

class AddExpenseSheet extends StatefulWidget {
  final SplitGroup group;

  const AddExpenseSheet({super.key, required this.group});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  late String _selectedPayerId;
  SplitType _splitType = SplitType.equal;
  
  // Controllers for custom splits for each member
  final Map<String, TextEditingController> _customShareControllers = {};
  
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Default payer is the first member (usually the creator/current user)
    _selectedPayerId = widget.group.members.isNotEmpty ? widget.group.members.first.id : '';
    
    // Initialize custom share controllers
    for (final member in widget.group.members) {
      _customShareControllers[member.id] = TextEditingController();
    }

    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    for (final controller in _customShareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged() {
    if (_splitType == SplitType.equal) {
      // Trigger state rebuild to update the equal split preview
      setState(() {});
    }
  }

  double get _totalAmount {
    final cleanText = _amountController.text.replaceAll(RegExp(r'\D'), '');
    return double.tryParse(cleanText) ?? 0.0;
  }

  void _onSplitTypeChanged(SplitType type) {
    setState(() {
      _splitType = type;
      if (type == SplitType.custom && _totalAmount > 0) {
        // Pre-populate custom controllers with equal share as a starting point
        final equalShare = (_totalAmount / widget.group.members.length).roundToDouble();
        final formatter = NumberFormat('#,###', 'vi_VN');
        
        for (final member in widget.group.members) {
          _customShareControllers[member.id]?.text = formatter.format(equalShare);
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();
    final totalAmount = _totalAmount;

    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số tiền chi tiêu phải lớn hơn 0đ'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final Map<String, double> shares = {};

    if (_splitType == SplitType.equal) {
      final share = totalAmount / widget.group.members.length;
      for (final member in widget.group.members) {
        shares[member.id] = share;
      }
    } else {
      double customSum = 0;
      for (final member in widget.group.members) {
        final shareCleanText = _customShareControllers[member.id]?.text.replaceAll(RegExp(r'\D'), '') ?? '';
        final shareVal = double.tryParse(shareCleanText) ?? 0.0;
        shares[member.id] = shareVal;
        customSum += shareVal;
      }

      // Check sum matches total
      if ((customSum - totalAmount).abs() > 1.0) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Số tiền chia không khớp'),
            content: Text(
              'Tổng số tiền chia cho các thành viên (${_currencyFormat.format(customSum)}) phải bằng tổng số tiền chi tiêu (${_currencyFormat.format(totalAmount)}).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đồng ý', style: TextStyle(color: Color(0xFF6D28D9))),
              ),
            ],
          ),
        );
        return;
      }
    }

    final expenseId = const Uuid().v4();
    final newExpense = SplitExpense(
      id: expenseId,
      description: description,
      amount: totalAmount,
      paidBy: _selectedPayerId,
      splitType: _splitType,
      shares: shares,
      createdAt: DateTime.now(),
    );

    try {
      await context.read<SplitProvider>().addExpense(widget.group.id, newExpense);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thêm khoản chi thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể thêm khoản chi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalAmount = _totalAmount;
    final equalSharePreview = widget.group.members.isNotEmpty ? totalAmount / widget.group.members.length : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Thêm khoản chi tiêu mới',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              // Description Input
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Mô tả (ví dụ: Ăn lẩu, Thuê xe máy)',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  floatingLabelStyle: const TextStyle(color: Color(0xFF6D28D9)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                  ),
                  prefixIcon: const Icon(LucideIcons.text, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập mô tả khoản chi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF6D28D9)),
                decoration: InputDecoration(
                  labelText: 'Số tiền chi tiêu',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  floatingLabelStyle: const TextStyle(color: Color(0xFF6D28D9)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                  ),
                  prefixIcon: const Icon(LucideIcons.dollarSign, color: Color(0xFF6D28D9)),
                  suffixText: 'VND',
                  suffixStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6D28D9)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập số tiền';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Payer Dropdown
              DropdownButtonFormField<String>(
                value: _selectedPayerId,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  labelText: 'Người trả tiền',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  prefixIcon: const Icon(LucideIcons.userCheck, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                ),
                items: widget.group.members.map((member) {
                  return DropdownMenuItem<String>(
                    value: member.id,
                    child: Text(member.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPayerId = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              // Split Type Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hình thức chia tiền',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _splitTypeButton('Chia đều', SplitType.equal),
                        _splitTypeButton('Tùy chỉnh', SplitType.custom),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Equal Split preview or Custom shares inputs
              if (_splitType == SplitType.equal)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Chia đều cho ${widget.group.members.length} người. Mỗi người chịu ${_currencyFormat.format(equalSharePreview)}.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhập phần tiền từng người chịu:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    ...widget.group.members.map((member) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                member.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _customShareControllers[member.id],
                                keyboardType: TextInputType.number,
                                inputFormatters: [ThousandsSeparatorInputFormatter()],
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF6D28D9)),
                                decoration: const InputDecoration(
                                  suffixText: 'đ',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Text(
                  'Thêm khoản chi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _splitTypeButton(String label, SplitType type) {
    final isSelected = _splitType == type;
    return GestureDetector(
      onTap: () => _onSplitTypeChanged(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
