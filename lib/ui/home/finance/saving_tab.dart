import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/bank_interest.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/services/ocr_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';

String formatCurrency(num amount) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);

String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

class SavingTabPage extends StatefulWidget {
  const SavingTabPage({super.key});

  @override
  State<SavingTabPage> createState() => _SavingTabPageState();
}

class _SavingTabPageState extends State<SavingTabPage> {
  final OCRService _ocrService = OCRService();

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<int?> _showAmountDialog({
    required String title,
    required String actionLabel,
    int? maxAmount,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              suffixText: '₫',
              hintText: 'Nhập số tiền...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, int.parse(controller.text));
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

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

  void _showAddSavingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSavingGoalSheet(ocrService: _ocrService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.savings.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = provider.savings;
        if (items.isEmpty) {
          return _EmptyState(onCreate: _showAddSavingSheet);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _AddButton(onPressed: _showAddSavingSheet),
              );
            }

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
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Chưa có mục tiêu tiết kiệm',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            _AddButton(onPressed: onCreate),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
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
}

class _SavingGoalCard extends StatelessWidget {
  final FinanceSavingItem item;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  const _SavingGoalCard({required this.item, required this.onDeposit, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    final progress = (item.currentAmount / item.targetAmount).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

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
          ),
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
  final OCRService ocrService;

  const _AddSavingGoalSheet({required this.ocrService});

  @override
  State<_AddSavingGoalSheet> createState() => _AddSavingGoalSheetState();
}

class _AddSavingGoalSheetState extends State<_AddSavingGoalSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  BankInterest? _selectedBank;

  Color _bankColor(BankInterest? bank) {
    if (bank == null) return AppColors.financeGreen;
    final index = bankData.indexOf(bank);
    switch (index % 3) {
      case 0:
        return AppColors.financeGreen;
      case 1:
        return AppColors.blue;
      default:
        return AppColors.purple;
    }
  }

  Future<void> _scanAmount() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR hiện chỉ hỗ trợ mobile/desktop.')),
      );
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final result = await widget.ocrService.scanReceiptPath(image.path);
    final amount = result?['amount'];

    if (!mounted) return;
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không nhận diện được số tiền.')),
      );
      return;
    }

    _amountController.text = amount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mục tiêu tiết kiệm mới',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tên mục tiêu',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên mục tiêu';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số tiền cần tiết kiệm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  suffixIcon: IconButton(
                    onPressed: _scanAmount,
                    icon: const Icon(Icons.document_scanner_outlined),
                  ),
                ),
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Số tiền không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<BankInterest>(
                value: _selectedBank,
                decoration: InputDecoration(
                  labelText: 'Ngân hàng tham khảo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                items: bankData
                    .map(
                      (bank) =>
                      DropdownMenuItem(value: bank, child: Text(bank.name)),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedBank = value);
                },
              ),
              if (_selectedBank != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Lãi tham khảo: ${_selectedBank!.rates.values.first.toStringAsFixed(1)}%/năm',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                tileColor: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                title: const Text(
                  'Ngày dự kiến hoàn thành',
                  style: TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  formatDate(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bankColor(_selectedBank),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final title = _titleController.text.trim();
                    await context.read<FinanceProvider>().addSavingGoal(
                      title: title,
                      targetAmount: int.parse(_amountController.text),
                      deadline: _selectedDate,
                      icon: '🎯',
                      color: _bankColor(_selectedBank),
                    );

                    if (!mounted) return;
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã thêm mục tiêu tiết kiệm "$title"'),
                      ),
                    );
                  },
                  child: const Text(
                    'Tạo mục tiêu',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

/// Public alias để finance_screen có thể dùng trực tiếp
class AddSavingSheetPublic extends _AddSavingGoalSheet {
  AddSavingSheetPublic() : super(ocrService: OCRService());
}