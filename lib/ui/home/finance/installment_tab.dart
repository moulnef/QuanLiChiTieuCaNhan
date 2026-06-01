import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/installment_plan.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/wallet_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/money_formatter.dart';

// Helper formatters
String formatCurrency(num amount) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);
String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

class InstallmentTabPage extends StatefulWidget {
  const InstallmentTabPage({super.key});

  @override
  State<InstallmentTabPage> createState() => _InstallmentTabPageState();
}

class _InstallmentTabPageState extends State<InstallmentTabPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FinanceRepository _repository = FinanceRepository();

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'user_001';

  void _showAddInstallmentSheet([InstallmentPlan? plan]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddInstallmentSheet(
        userId: _currentUserId,
        installmentPlan: plan,
      ),
    );
  }

  Future<WalletModel?> _showPaymentWalletDialog(int amount) async {
    final walletsData = await _repository.getWalletsByUserId(_currentUserId);
    final wallets = walletsData.map((w) => WalletModel.fromMap(w)).toList();
    if (wallets.isEmpty) return null;
    
    WalletModel selectedWallet = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);

    return showDialog<WalletModel>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Thanh toán trả góp kỳ này', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Số tiền cần trả: ${formatCurrency(amount)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              DropdownButtonFormField<WalletModel>(
                value: selectedWallet,
                items: wallets.map((w) => DropdownMenuItem(
                  value: w,
                  child: Text('${w.name} (${formatCurrency(w.balance)})'),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedWallet = val);
                },
                decoration: InputDecoration(
                  labelText: 'Ví thanh toán',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedWallet.balance < amount) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Không đủ số dư trong ví đã chọn!'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(dialogContext, selectedWallet);
              },
              child: const Text('Thanh toán'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMarkPaid(InstallmentPlan item) async {
    if (item.paidPeriods >= item.totalPeriods || item.status == 'completed') {
      return;
    }

    final amount = item.monthlyPayment;
    final wallet = await _showPaymentWalletDialog(amount);
    if (wallet == null || !mounted) return;

    try {
      // 1. Trừ tiền ví nguồn
      final newBalance = wallet.balance - amount;
      await _repository.upsertWallet(wallet.copyWith(balance: newBalance));

      // 2. Tạo giao dịch trả góp
      final tx = TransactionModel(
        id: 'tx_inst_pay_${DateTime.now().millisecondsSinceEpoch}',
        userId: _currentUserId,
        walletId: wallet.id,
        categoryId: 'installment_pay',
        categoryName: 'Trả góp',
        type: 'expense',
        amount: amount.toDouble(),
        note: 'Thanh toán trả góp: ${item.title} (Kỳ ${item.paidPeriods + 1}/${item.totalPeriods})',
        transactionDate: DateTime.now(),
      );
      await _repository.upsertTransaction(tx);

      // 3. Cập nhật trả góp
      final newPeriods = item.paidPeriods + 1;
      final isCompleted = newPeriods >= item.totalPeriods;
      final newPaidAmount = (item.paidAmount + amount).clamp(0, item.totalAmount);
      
      final currentDueDate = DateTime.fromMillisecondsSinceEpoch(item.nextDueDate);
      final newDueDate = currentDueDate.add(const Duration(days: 30));

      final updated = item.copyWith(
        paidPeriods: newPeriods,
        paidAmount: newPaidAmount,
        nextDueDate: newDueDate.millisecondsSinceEpoch,
        status: isCompleted ? 'completed' : 'active',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await context.read<FinanceProvider>().updateInstallmentPlan(updated);
      await context.read<FinanceProvider>().refreshFinancialSummary(_currentUserId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thanh toán thành công! Đã trả kỳ $newPeriods/$item.totalPeriods. Còn lại ${item.totalPeriods - newPeriods} kỳ.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool?> _confirmDelete(InstallmentPlan item) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa kế hoạch trả góp "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InstallmentPlan>>(
      stream: _firestoreService.streamInstallments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _EmptyState(onCreate: () => _showAddInstallmentSheet());
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _AddButton(onPressed: () => _showAddInstallmentSheet()),
              );
            }

            final item = items[index];
            return Dismissible(
              key: Key(item.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(item),
              onDismissed: (_) async {
                try {
                  await context.read<FinanceProvider>().deleteInstallment(item.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã xóa kế hoạch trả góp "${item.title}"')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không thể xóa: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
              ),
              child: GestureDetector(
                onTap: () => _showAddInstallmentSheet(item),
                child: _InstallmentCard(
                  item: item,
                  onPay: () => _handleMarkPaid(item),
                ),
              ),
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
            Icon(Icons.credit_card_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Chưa có khoản trả góp',
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
  final InstallmentPlan item;
  final VoidCallback onPay;

  const _InstallmentCard({required this.item, required this.onPay});

  @override
  Widget build(BuildContext context) {
    double progress = item.totalPeriods > 0 ? (item.paidPeriods / item.totalPeriods).clamp(0.0, 1.0) : 0.0;
    int percent = (progress * 100).toInt();
    final isCompleted = item.paidPeriods >= item.totalPeriods || item.status == 'completed';
    final nextDueDateTime = DateTime.fromMillisecondsSinceEpoch(item.nextDueDate);

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCompleted)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Đã hoàn tất 🎉',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCompleted
                          ? 'Đã trả hết tất cả các kỳ!'
                          : 'Kỳ hạn tiếp theo: ${formatDate(nextDueDateTime)}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Color(0xFF8B5CF6), // Tím cho trả góp
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
              valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountColumn(
                label: 'Đã trả (${item.paidPeriods}/${item.totalPeriods} tháng)',
                amount: item.paidAmount,
                color: const Color(0xFF8B5CF6),
              ),
              _AmountColumn(
                label: 'Tổng tiền trả góp',
                amount: item.totalAmount,
                color: const Color(0xFF1E293B),
                isRight: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Số tiền mỗi tháng:',
                style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                formatCurrency(item.monthlyPayment),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _CardButton(
                    text: 'Đánh dấu đã trả tháng này',
                    onPressed: onPay,
                    color: const Color(0xFF8B5CF6).withOpacity(0.08),
                    textColor: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
          ],
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
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
            fontSize: 17,
            color: color,
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

class _AddInstallmentSheet extends StatefulWidget {
  final String userId;
  final InstallmentPlan? installmentPlan;

  const _AddInstallmentSheet({
    required this.userId,
    this.installmentPlan,
  });

  @override
  State<_AddInstallmentSheet> createState() => _AddInstallmentSheetState();
}

class _AddInstallmentSheetState extends State<_AddInstallmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();

  String _selectedBank = 'MB Bank';
  final List<String> _banks = ['MB Bank', 'Vietcombank', 'Techcombank', 'BIDV', 'VietinBank'];

  int _selectedPeriod = 12;
  final List<int> _periods = [3, 6, 12, 24];
  final Map<int, double> _interestRates = {
    3: 6.0,
    6: 7.2,
    12: 8.2,
    24: 9.0,
  };

  DateTime _selectedDate = DateTime.now();
  String _selectedEmoji = '🧾';
  int _calculatedMonthly = 0;

  final List<String> _emojiList = ['🧾', '📱', '💻', '🚗', '🏍️', '🏠', '🎁', '✈️', '🎓', '💍', '🛋️'];

  @override
  void initState() {
    super.initState();
    if (widget.installmentPlan != null) {
      final titleParts = widget.installmentPlan!.title.split(' - ');
      if (titleParts.length > 1) {
        _titleController.text = titleParts[0];
        final bankCandidate = titleParts[1];
        if (_banks.contains(bankCandidate)) {
          _selectedBank = bankCandidate;
        }
      } else {
        _titleController.text = widget.installmentPlan!.title;
      }
      _totalController.text = NumberFormat('#,###', 'vi_VN').format(widget.installmentPlan!.totalAmount);
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(widget.installmentPlan!.nextDueDate);
      _selectedEmoji = widget.installmentPlan!.icon;
      if (_periods.contains(widget.installmentPlan!.totalPeriods)) {
        _selectedPeriod = widget.installmentPlan!.totalPeriods;
      }
    }
    _recalculate();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final amountText = _totalController.text.replaceAll(RegExp(r'\D'), '');
    if (amountText.isNotEmpty) {
      final totalAmount = double.tryParse(amountText) ?? 0.0;
      final months = _selectedPeriod;
      final interest = _interestRates[months] ?? 0.0;

      if (totalAmount > 0 && months > 0) {
        final monthlyRate = interest / 100 / 12;
        setState(() {
          _calculatedMonthly = ((totalAmount / months) + (totalAmount * monthlyRate)).round();
        });
        return;
      }
    }
    setState(() {
      _calculatedMonthly = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.installmentPlan != null;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEdit ? 'Chỉnh sửa trả góp' : 'Kế hoạch trả góp mới',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tên vật phẩm/Khoản trả góp',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Vui lòng nhập tên khoản trả góp' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _totalController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Tổng số tiền gốc',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  suffixText: '₫',
                ),
                onChanged: (_) => _recalculate(),
                validator: (v) {
                  final clean = v!.replaceAll(RegExp(r'\D'), '');
                  final val = int.tryParse(clean);
                  if (val == null || val <= 0) return 'Số tiền không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedBank,
                items: _banks.map((b) => DropdownMenuItem(
                  value: b,
                  child: Text(b),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedBank = val);
                    _recalculate();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Ngân hàng/Đơn vị',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _selectedPeriod,
                items: _periods.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text('$p tháng - Lãi ${_interestRates[p]}%/năm'),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPeriod = val);
                    _recalculate();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Kỳ hạn & Lãi suất',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn biểu tượng (Emoji)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojiList.length,
                  itemBuilder: (context, index) {
                    final emoji = _emojiList[index];
                    final isSelected = emoji == _selectedEmoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(right: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.15) : const Color(0xFFF1F5F9),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                tileColor: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: Text(
                  isEdit ? 'Ngày thanh toán tiếp theo' : 'Ngày bắt đầu thanh toán',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  formatDate(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              if (_calculatedMonthly > 0) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Số tiền mỗi kỳ (gốc + lãi):',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        formatCurrency(_calculatedMonthly),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final title = '${_titleController.text.trim()} - $_selectedBank';
                    final cleanAmt = _totalController.text.replaceAll(RegExp(r'\D'), '');
                    final totalAmt = int.parse(cleanAmt);
                    final periods = _selectedPeriod;
                    
                    final plan = InstallmentPlan(
                      id: widget.installmentPlan?.id ?? 'installment_${DateTime.now().millisecondsSinceEpoch}',
                      userId: widget.userId,
                      title: title,
                      icon: _selectedEmoji,
                      totalAmount: totalAmt,
                      paidAmount: widget.installmentPlan?.paidAmount ?? 0,
                      monthlyPayment: _calculatedMonthly,
                      paidPeriods: widget.installmentPlan?.paidPeriods ?? 0,
                      totalPeriods: periods,
                      nextDueDate: _selectedDate.millisecondsSinceEpoch,
                      createdAt: widget.installmentPlan?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                      status: (widget.installmentPlan?.paidPeriods ?? 0) >= periods ? 'completed' : 'active',
                    );

                    try {
                      if (isEdit) {
                        await context.read<FinanceProvider>().updateInstallmentPlan(plan);
                      } else {
                        await context.read<FinanceProvider>().addInstallmentPlanDirect(plan);
                      }

                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Đã cập nhật trả góp "$title"'
                                : 'Đã thêm kế hoạch trả góp "$title"',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: Text(
                    isEdit ? 'Cập nhật trả góp' : 'Lưu kế hoạch',
                    style: const TextStyle(
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

class AddInstallmentSheetPublic extends StatelessWidget {
  const AddInstallmentSheetPublic({super.key});
  @override
  Widget build(BuildContext context) {
    return _AddInstallmentSheet(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'user_001',
    );
  }
}