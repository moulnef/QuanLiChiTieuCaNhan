import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/bank_interest.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/services/ocr_service.dart';

// Helper formatters
String formatCurrency(num amount) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);
String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

class DebtTabPage extends StatefulWidget {
  const DebtTabPage({super.key});

  @override
  State<DebtTabPage> createState() => _DebtTabPageState();
}

class _DebtTabPageState extends State<DebtTabPage> {
  final OCRService _ocrService = OCRService();

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _scanAmount(TextEditingController controller) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR hiện chỉ hỗ trợ mobile/desktop.')),
      );
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final result = await _ocrService.scanReceiptPath(image.path);
    final amount = result?['amount'];
    if (!mounted) return;

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không nhận diện được số tiền.')),
      );
      return;
    }

    controller.text = amount.toStringAsFixed(0);
  }

  // Logic thanh toán nợ
  Future<void> _handlePay(FinanceDebtItem item) async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    final amount = await _showAmountDialog(
      title: 'Thanh toán khoản vay',
      actionLabel: 'Thanh toán',
      maxAmount: item.remainingAmount,
    );

    if (amount == null) return;

    Future.microtask(() async {
      try {
        await financeProvider.payDebt(item.id, amount);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã thanh toán ${formatCurrency(amount)} cho "${item.title}"',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
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
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Số tiền thanh toán',
                  suffixText: '₫',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  suffixIcon: IconButton(
                    onPressed: () => _scanAmount(controller),
                    icon: const Icon(Icons.document_scanner_outlined),
                  ),
                ),
                validator: (value) {
                  final val = int.tryParse(value ?? '');
                  if (val == null || val <= 0) return 'Số tiền không hợp lệ';
                  if (maxAmount != null && val > maxAmount)
                    return 'Vượt quá số nợ còn lại';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Hủy',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEEF2FF),
              foregroundColor: const Color(0xFF4F46E5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(int.parse(controller.text));
              }
            },
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddLoanSheet(),
    );

    if (!mounted) return;
    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo khoản vay mới'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.debts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = provider.debts;
        if (items.isEmpty) return _buildEmptyState();

        return RefreshIndicator(
          onRefresh: provider.loadFinanceData,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: 100,
            ),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) return _buildAddButton();
              final item = items[index];
              return _DebtCard(item: item, onPay: () => _handlePay(item));
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text('Chưa có khoản vay', style: TextStyle(color: Colors.grey)),
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
      label: const Text('Thêm khoản vay mới'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        foregroundColor: const Color(0xFF2563EB),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.item, required this.onPay});
  final FinanceDebtItem item;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    double progress = (item.paidAmount / item.totalAmount).clamp(0.0, 1.0);
    Color alertColor = (item.daysLeft < 0)
        ? Colors.redAccent
        : (item.daysLeft <= 7 ? Colors.orange : const Color(0xFF2563EB));

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
                      item.lender,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  item.interestText,
                  style: TextStyle(
                    color: alertColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
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
              valueColor: AlwaysStoppedAnimation(alertColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountColumn(
                label: 'Đã trả',
                amount: item.paidAmount,
                color: const Color(0xFF10B981),
              ),
              _AmountColumn(
                label: 'Còn lại',
                amount: item.remainingAmount,
                color: Colors.redAccent,
                isRight: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TextInfoColumn(
                label: 'Trả mỗi tháng',
                value: formatCurrency(item.monthlyPayment),
              ),
              _TextInfoColumn(
                label: 'Hạn tiếp theo',
                value: formatDate(item.dueDate),
                isRight: true,
                valueColor: alertColor,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  text: 'Thanh toán nợ',
                  onPressed: onPay,
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  textColor: const Color(0xFFD97706),
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
  const _AmountColumn({
    required this.label,
    required this.amount,
    required this.color,
    this.isRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatCurrency(amount),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TextInfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool isRight;
  final Color? valueColor;
  const _TextInfoColumn({
    required this.label,
    required this.value,
    this.isRight = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: valueColor ?? const Color(0xFF475569),
          ),
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
  const _CardButton({
    required this.text,
    required this.onPressed,
    required this.color,
    required this.textColor,
  });

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
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddLoanSheet extends StatefulWidget {
  const _AddLoanSheet();
  @override
  State<_AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<_AddLoanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  BankInterest? selectedBank;
  int? selectedTerm;
  double monthlyAmount = 0;
  DateTime? nextDueDate;

  void _calculateLoan() {
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (selectedBank != null && selectedTerm != null && amountText.isNotEmpty) {
      double principal = double.tryParse(amountText) ?? 0;
      double rate = selectedBank!.rates[selectedTerm!]!;

      setState(() {
        monthlyAmount = context.read<FinanceProvider>().calculateMonthlyPayment(
          principal,
          rate,
          selectedTerm!,
        );
      });
    }
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
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const Text(
                'Khoản vay mới',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),

              _buildTextField(
                _titleController,
                'Tên khoản vay (ví dụ: Vay mua xe)',
              ),
              const SizedBox(height: 16),

              _buildBankDropdown(),
              const SizedBox(height: 16),

              _buildTextField(
                _amountController,
                'Tổng số tiền vay',
                isNumber: true,
                onChanged: (_) => _calculateLoan(),
              ),
              const SizedBox(height: 16),

              if (selectedBank != null) ...[
                _buildTermDropdown(),
                const SizedBox(height: 16),
              ],

              if (monthlyAmount > 0) _buildLoanSummary(),

              const SizedBox(height: 16),
              _buildDatePicker(context),

              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoanSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        children: [
          _rowInfo(
            'Lãi suất áp dụng',
            '${selectedBank!.rates[selectedTerm!]}% / năm',
          ),
          const Divider(),
          _rowInfo(
            'Trả mỗi tháng (Gốc + Lãi)',
            formatCurrency(monthlyAmount),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBankDropdown() {
    return DropdownButtonFormField<BankInterest>(
      decoration: _inputDecoration('Ngân hàng cho vay'),
      items: loanBankData
          .map((bank) => DropdownMenuItem(value: bank, child: Text(bank.name)))
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedBank = value;
          selectedTerm = null;
          monthlyAmount = 0;
        });
      },
    );
  }

  Widget _buildTermDropdown() {
    return DropdownButtonFormField<int>(
      decoration: _inputDecoration('Kỳ hạn vay'),
      items: selectedBank!.rates.keys
          .map(
            (term) => DropdownMenuItem(value: term, child: Text('$term tháng')),
      )
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedTerm = value;
          _calculateLoan();
        });
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _rowInfo(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => nextDueDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              nextDueDate == null
                  ? 'Ngày đến hạn tiếp theo'
                  : 'Ngày đến hạn: ${formatDate(nextDueDate!)}',
            ),
            const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label, {
        bool isNumber = false,
        ValueChanged<String>? onChanged,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: _inputDecoration(label),
      onChanged: onChanged,
      validator: (v) => v!.isEmpty ? 'Vui lòng nhập' : null,
    );
  }


  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        onPressed: () async {
          if (_formKey.currentState!.validate() &&
              selectedBank != null &&
              selectedTerm != null &&
              nextDueDate != null) {
            await context.read<FinanceProvider>().addDebtRecord(
              title: _titleController.text,
              lender: selectedBank!.name,
              totalAmount: (monthlyAmount * selectedTerm!).round(),
              monthlyPayment: monthlyAmount.round(),
              dueDate: nextDueDate!,
              interestText: '${selectedBank!.rates[selectedTerm!]}%/năm',
            );
            if (mounted) Navigator.pop(context, true);
          }
        },
        child: const Text(
          'Lưu khoản vay',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Public alias để finance_screen có thể dùng trực tiếp
class AddLoanSheetPublic extends _AddLoanSheet {
  const AddLoanSheetPublic();
}