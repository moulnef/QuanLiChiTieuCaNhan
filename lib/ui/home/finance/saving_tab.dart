import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/finance_action_button.dart';

// Helper formatters
String formatCurrency(num amount) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);
String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

class SavingsTab extends StatefulWidget {
  const SavingsTab({super.key});

  @override
  State<SavingsTab> createState() => _SavingsTabState();
}

class _SavingsTabState extends State<SavingsTab> {
  // Logic nạp tiền
  Future<void> _handleDeposit(FinanceSavingItem item) async {
    final amount = await _showAmountDialog(
      title: 'Nạp tiền tiết kiệm',
      actionLabel: 'Nạp ngay',
    );
    if (!mounted || amount == null) return;
    try {
      await context.read<FinanceProvider>().depositToSavingGoal(item.id, amount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã nạp ${formatCurrency(amount)} vào "${item.title}"')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // Logic rút tiền
  Future<void> _handleWithdraw(FinanceSavingItem item) async {
    final amount = await _showAmountDialog(
      title: 'Rút tiền tiết kiệm',
      actionLabel: 'Rút tiền',
      maxAmount: item.currentAmount,
    );
    if (!mounted || amount == null) return;
    try {
      await context.read<FinanceProvider>().withdrawFromSavingGoal(item.id, amount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã rút ${formatCurrency(amount)} từ "${item.title}"')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // Dialog nhập số tiền chung
  Future<int?> _showAmountDialog({required String title, required String actionLabel, int? maxAmount}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              suffixText: '₫',
              hintText: 'Nhập số tiền...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              final val = int.tryParse(value ?? '');
              if (val == null || val <= 0) return 'Số tiền không hợp lệ';
              if (maxAmount != null && val > maxAmount) return 'Không đủ số dư';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, int.parse(controller.text));
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());

        final items = provider.savings;
        if (items.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) return _buildAddButton();
            final item = items[index];
            return _SavingGoalCard(
              item: item,
              onDeposit: () => _handleDeposit(item),
              onWithdraw: () => _handleWithdraw(item),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Chưa có mục tiêu tiết kiệm', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return OutlinedButton.icon(
      onPressed: () => _showAddSavingSheet(context),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Thêm mục tiêu tiết kiệm'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        foregroundColor: const Color(0xFF2563EB),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showAddSavingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddSavingGoalSheet(),
    );
  }
}

class _SavingGoalCard extends StatelessWidget {
  final FinanceSavingItem item;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  const _SavingGoalCard({required this.item, required this.onDeposit, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    double progress = (item.currentAmount / item.targetAmount).clamp(0.0, 1.0);
    int percent = (progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(item.icon, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Còn ${item.daysLeft} ngày',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountColumn(label: 'Hiện tại', amount: item.currentAmount, color: const Color(0xFF2563EB)),
              _AmountColumn(label: 'Mục tiêu', amount: item.targetAmount, color: const Color(0xFF1E293B), isRight: true),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  text: '+ Nạp tiền',
                  onPressed: onDeposit,
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  textColor: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CardButton(
                  text: 'Rút tiền',
                  onPressed: onWithdraw,
                  color: const Color(0xFFF1F5F9),
                  textColor: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final bool isRight;

  const _AmountColumn({required this.label, required this.amount, required this.color, this.isRight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          formatCurrency(amount),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color),
        ),
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;

  const _CardButton({required this.text, required this.onPressed, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _AddSavingGoalSheet extends StatefulWidget {
  const _AddSavingGoalSheet();
  @override
  State<_AddSavingGoalSheet> createState() => _AddSavingGoalSheetState();
}

class _AddSavingGoalSheetState extends State<_AddSavingGoalSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Mục tiêu tiết kiệm mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Tên mục tiêu',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Số tiền cần tiết kiệm',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            tileColor: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Ngày dự kiến hoàn thành', style: TextStyle(fontSize: 14)),
            trailing: Text(formatDate(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () async {
                if (_titleController.text.isNotEmpty && _amountController.text.isNotEmpty) {
                  final title = _titleController.text;
                  await context.read<FinanceProvider>().addSavingGoal(
                    title: title,
                    targetAmount: int.parse(_amountController.text),
                    deadline: _selectedDate,
                    icon: '🎯',
                    color: const Color(0xFF3B82F6),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã thêm mục tiêu tiết kiệm "$title"')),
                    );
                  }
                }
              },
              child: const Text('Tạo mục tiêu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}