import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/widgets/common/finance_action_button.dart';

// Helper formatters
String formatCurrency(num amount) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);
String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

class InstallmentTabPage extends StatefulWidget {
  const InstallmentTabPage({super.key});

  @override
  State<InstallmentTabPage> createState() => _InstallmentTabPageState();
}

class _InstallmentTabPageState extends State<InstallmentTabPage> {
  Future<int?> _showAmountDialog({
    required String title,
    required String actionLabel,
    int? maxAmount,
  }) async {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        final controller = TextEditingController();
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Số tiền',
                suffixText: '₫',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                final val = int.tryParse(value ?? '');
                if (val == null || val <= 0) return 'Số tiền không hợp lệ';
                if (maxAmount != null && val > maxAmount) return 'Vượt quá phần còn lại';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, int.parse(controller.text));
                }
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    return result;
  }

  Future<void> _handlePay(FinanceInstallmentItem item) async {
    final amount = await _showAmountDialog(
      title: 'Thanh toán trả góp',
      actionLabel: 'Thanh toán',
      maxAmount: item.remainingAmount,
    );

    if (!mounted || amount == null) return;

    try {
      await context.read<FinanceProvider>().payInstallment(item.id, amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thanh toán ${formatCurrency(amount)} cho "${item.title}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddInstallmentSheet(),
    );

    if (!mounted) return;
    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo kế hoạch trả góp mới')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.installments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = provider.installments;
        if (items.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) return _buildAddButton();
            final item = items[index];
            return _InstallmentCard(
              item: item,
              onPay: () => _handlePay(item),
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
          Icon(Icons.credit_card_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Chưa có khoản trả góp', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return OutlinedButton.icon(
      onPressed: _openCreateSheet,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Thêm kế hoạch trả góp'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        foregroundColor: const Color(0xFF2563EB),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({required this.item, required this.onPay});
  final FinanceInstallmentItem item;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    double progress = (item.paidAmount / item.totalAmount).clamp(0.0, 1.0);
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
                      'Đã trả ${item.currentPeriod}/${item.totalPeriods} kỳ',
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
              valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)), // Tím cho trả góp
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountColumn(label: 'Đã thanh toán', amount: item.paidAmount, color: const Color(0xFF8B5CF6)),
              _AmountColumn(label: 'Tổng nợ', amount: item.totalAmount, color: const Color(0xFF1E293B), isRight: true),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  text: 'Thanh toán kỳ này',
                  onPressed: onPay,
                  color: const Color(0xFF8B5CF6).withOpacity(0.08),
                  textColor: const Color(0xFF7C3AED),
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

class _AddInstallmentSheet extends StatefulWidget {
  const _AddInstallmentSheet();
  @override
  State<_AddInstallmentSheet> createState() => _AddInstallmentSheetState();
}

class _AddInstallmentSheetState extends State<_AddInstallmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final _periodController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _selectedDueDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 30),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Kế hoạch trả góp mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _buildInput(controller: _titleController, label: 'Tên khoản trả góp'),
            const SizedBox(height: 16),
            _buildInput(controller: _totalController, label: 'Tổng số tiền', isNumber: true),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInput(controller: _periodController, label: 'Số kỳ', isNumber: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildInput(controller: _monthlyController, label: 'Mỗi kỳ', isNumber: true)),
              ],
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
                  if (_formKey.currentState!.validate()) {
                    await context.read<FinanceProvider>().addInstallmentPlan(
                      title: _titleController.text,
                      totalAmount: int.parse(_totalController.text),
                      totalPeriods: int.parse(_periodController.text),
                      monthlyPayment: int.parse(_monthlyController.text),
                    );
                    if (mounted) Navigator.pop(context, true);
                  }
                },
                child: const Text('Lưu kế hoạch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({required TextEditingController controller, required String label, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
      validator: (v) => v!.isEmpty ? 'Vui lòng nhập' : null,
    );
  }
}