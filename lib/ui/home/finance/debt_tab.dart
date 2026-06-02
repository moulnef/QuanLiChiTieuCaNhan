import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/debt_record.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/wallet_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/services/ocr_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/money_formatter.dart';

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
  final FirestoreService _firestoreService = FirestoreService();
  final FinanceRepository _repository = FinanceRepository();
  final OCRService _ocrService = OCRService();
  String _filter = 'active'; // 'all', 'active' (chưa xong), 'settled' (đã xong)

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'user_001';

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

  Future<Map<String, dynamic>?> _showDebtPaymentDialog(DebtRecord item, List<WalletModel> wallets) async {
    final isChoVay = item.lenderName.startsWith('cho_vay|');
    final cleanName = item.lenderName.replaceAll('cho_vay|', '').replaceAll('di_vay|', '');
    
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    WalletModel selectedWallet = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);

    final requiredMin = item.monthlyPayment > 0 ? item.monthlyPayment : 0;
    final maxAmount = item.remainingAmount;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(isChoVay ? 'Thu nợ từ $cleanName' : 'Thanh toán nợ cho $cleanName', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<WalletModel>(
                  initialValue: selectedWallet,
                  items: wallets.map((w) => DropdownMenuItem(
                    value: w,
                    child: Text('${w.name} (${formatCurrency(w.balance)})'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedWallet = val);
                  },
                  decoration: InputDecoration(
                    labelText: isChoVay ? 'Ví nhận tiền' : 'Ví thanh toán',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Số tiền thanh toán',
                    suffixText: '₫',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    final clean = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                    final val = int.tryParse(clean);
                    if (val == null || val <= 0) return 'Số tiền không hợp lệ';
                    if (val > maxAmount) return 'Vượt quá số nợ còn lại (${formatCurrency(maxAmount)})';
                    
                    // Validate minimum payment limit
                    if (requiredMin > 0 && maxAmount >= requiredMin && val < requiredMin) {
                      return 'Số tiền phải tối thiểu bằng 1 kỳ: ${formatCurrency(requiredMin)}';
                    }
                    
                    // Validate wallet balance if paying debt
                    if (!isChoVay && val > selectedWallet.balance) {
                      return 'Không đủ số dư trong ví';
                    }
                    return null;
                  },
                ),
              ],
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
                  final clean = controller.text.replaceAll(RegExp(r'\D'), '');
                  Navigator.pop(dialogContext, {
                    'amount': int.parse(clean),
                    'wallet': selectedWallet,
                  });
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePay(DebtRecord item) async {
    final cleanName = item.lenderName.replaceAll('cho_vay|', '').replaceAll('di_vay|', '');
    final isChoVay = item.lenderName.startsWith('cho_vay|');

    final walletsData = await _repository.getWalletsByUserId(_currentUserId);
    final wallets = walletsData.map((w) => WalletModel.fromMap(w)).toList();

    if (wallets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tạo ví trước khi thanh toán nợ')),
      );
      return;
    }

    final result = await _showDebtPaymentDialog(item, wallets);
    if (result == null || !mounted) return;

    final amount = result['amount'] as int;
    final wallet = result['wallet'] as WalletModel;

    try {
      // 1. Cập nhật số dư ví
      final newBalance = isChoVay ? wallet.balance + amount : wallet.balance - amount;
      await _repository.upsertWallet(wallet.copyWith(balance: newBalance));

      // 2. Tạo giao dịch tương ứng
      final tx = TransactionModel(
        id: 'tx_debt_pay_${DateTime.now().millisecondsSinceEpoch}',
        userId: _currentUserId,
        walletId: wallet.id,
        categoryId: isChoVay ? 'debt_collect' : 'debt_repay',
        categoryName: isChoVay ? 'Thu nợ' : 'Trả nợ',
        type: isChoVay ? 'income' : 'expense',
        amount: amount.toDouble(),
        note: isChoVay ? 'Thu nợ từ $cleanName' : 'Thanh toán nợ cho $cleanName',
        transactionDate: DateTime.now(),
      );
      await _repository.upsertTransaction(tx);

      // 3. Cập nhật khoản vay nợ
      final newPaid = item.paidAmount + amount;
      final isSettled = newPaid >= item.totalAmount;
      final updated = item.copyWith(
        paidAmount: newPaid,
        status: isSettled ? 'settled' : 'active',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await context.read<FinanceProvider>().updateDebtRecord(updated);
      await context.read<FinanceProvider>().refreshFinancialSummary(_currentUserId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isChoVay
                ? 'Đã thu ${formatCurrency(amount)} từ "$cleanName" ${isSettled ? '🎉 Đã tất toán!' : ''}'
                : 'Đã trả ${formatCurrency(amount)} cho "$cleanName" ${isSettled ? '🎉 Đã tất toán!' : ''}',
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

  void _showAddDebtSheet([DebtRecord? record]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDebtSheet(
        userId: _currentUserId,
        debtRecord: record,
      ),
    );
  }

  Future<bool?> _confirmDelete(DebtRecord item) {
    final cleanName = item.lenderName.replaceAll('cho_vay|', '').replaceAll('di_vay|', '');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa khoản vay nợ với "$cleanName"?'),
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
    return Column(
      children: [
        const SizedBox(height: 12),
        // Filter tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterChip('all', 'Tất cả'),
              const SizedBox(width: 8),
              _buildFilterChip('active', 'Chưa xong'),
              const SizedBox(width: 8),
              _buildFilterChip('settled', 'Đã xong'),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<DebtRecord>>(
            stream: _repository.streamDebts(_currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var items = snapshot.data ?? [];
              
              // Apply UI filter
              if (_filter == 'active') {
                items = items.where((e) => e.status != 'settled').toList();
              } else if (_filter == 'settled') {
                items = items.where((e) => e.status == 'settled').toList();
              }

              if (items.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  if (index == items.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _AddButton(onPressed: () => _showAddDebtSheet()),
                    );
                  }

                  final item = items[index];
                  return Dismissible(
                    key: Key(item.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete(item),
                    onDismissed: (_) async {
                      try {
                        await context.read<FinanceProvider>().deleteDebt(item.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã xóa khoản vay nợ')),
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
                      onTap: () => _showAddDebtSheet(item),
                      child: _DebtCard(
                        item: item,
                        onPay: () => _handlePay(item),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filter = value);
      },
      selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text('Chưa có khoản vay nợ', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            _AddButton(onPressed: () => _showAddDebtSheet()),
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
      label: const Text('Thêm khoản vay nợ mới'),
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
  final DebtRecord item;
  final VoidCallback onPay;

  const _DebtCard({required this.item, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final isChoVay = item.lenderName.startsWith('cho_vay|');
    final cleanName = item.lenderName.replaceAll('cho_vay|', '').replaceAll('di_vay|', '');
    final themeColor = isChoVay ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    
    double progress = item.totalAmount > 0 ? (item.paidAmount / item.totalAmount).clamp(0.0, 1.0) : 0.0;
    int percent = (progress * 100).toInt();
    final isSettled = item.paidAmount >= item.totalAmount || item.status == 'settled';

    final dueDateTime = DateTime.fromMillisecondsSinceEpoch(item.nextDueDate);
    final daysLeft = dueDateTime.difference(DateTime.now()).inDays;
    final isOverdue = dueDateTime.isBefore(DateTime.now()) && !isSettled;

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
                  color: themeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isChoVay ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: themeColor,
                  size: 28,
                ),
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
                            cleanName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isChoVay ? 'Cho vay' : 'Đi vay',
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isSettled)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Đã xong ✓',
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
                      item.title.isNotEmpty ? item.title : 'Không có ghi chú',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  color: themeColor,
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
              valueColor: AlwaysStoppedAnimation(themeColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountColumn(
                label: 'Đã thanh toán',
                amount: item.paidAmount,
                color: themeColor,
              ),
              _AmountColumn(
                label: 'Chưa thanh toán',
                amount: item.remainingAmount,
                color: const Color(0xFF1E293B),
                isRight: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng gốc:',
                style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                formatCurrency(item.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSettled ? 'Đã tất toán lúc:' : (isOverdue ? 'Quá hạn:' : 'Thời hạn còn lại:'),
                style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                isSettled
                    ? formatDate(DateTime.fromMillisecondsSinceEpoch(item.updatedAt))
                    : (isOverdue
                        ? 'Quá hạn ${daysLeft.abs()} ngày (Hạn: ${formatDate(dueDateTime)})'
                        : 'Còn $daysLeft ngày (Hạn: ${formatDate(dueDateTime)})'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSettled
                      ? Colors.green
                      : (isOverdue ? Colors.redAccent : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
          if (!isSettled) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _CardButton(
                    text: isChoVay ? 'Ghi nhận thu nợ' : 'Ghi nhận trả nợ',
                    onPressed: onPay,
                    color: themeColor.withOpacity(0.08),
                    textColor: themeColor,
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
            fontSize: 16,
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

class _AddDebtSheet extends StatefulWidget {
  final String userId;
  final DebtRecord? debtRecord;

  const _AddDebtSheet({
    required this.userId,
    this.debtRecord,
  });

  @override
  State<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<_AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _monthsController = TextEditingController();
  final FinanceRepository _repository = FinanceRepository();

  String _selectedType = 'cho_vay'; // 'cho_vay' or 'di_vay'
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));

  String _selectedBank = 'MB Bank';
  final List<String> _banks = ['MB Bank', 'Vietcombank', 'Techcombank', 'BIDV', 'VietinBank'];
  final Map<String, double> _bankRates = {
    'MB Bank': 11.0,
    'Vietcombank': 10.0,
    'Techcombank': 10.5,
    'BIDV': 10.2,
    'VietinBank': 10.8,
  };

  bool _receiveToWallet = false;
  List<WalletModel> _wallets = [];
  WalletModel? _selectedWallet;

  int get _calculatedMonthlyPayment {
    final cleanAmt = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final total = double.tryParse(cleanAmt) ?? 0.0;
    final months = int.tryParse(_monthsController.text) ?? 12;
    final rateYear = _bankRates[_selectedBank] ?? 0.0;
    if (total <= 0 || months <= 0) return 0;
    final monthlyRate = rateYear / 100 / 12;
    return ((total / months) + (total * monthlyRate)).round();
  }

  Future<void> _loadWallets() async {
    final data = await _repository.getWalletsByUserId(widget.userId);
    final list = data.map((w) => WalletModel.fromMap(w)).toList();
    if (mounted) {
      setState(() {
        _wallets = list;
        if (list.isNotEmpty) {
          _selectedWallet = list.firstWhere((w) => w.isDefault, orElse: () => list.first);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _monthsController.text = '12';
    if (widget.debtRecord != null) {
      final isChoVay = widget.debtRecord!.lenderName.startsWith('cho_vay|');
      _selectedType = isChoVay ? 'cho_vay' : 'di_vay';
      
      final rawName = widget.debtRecord!.lenderName
          .replaceAll('cho_vay|', '')
          .replaceAll('di_vay|', '');
      final nameParts = rawName.split(' - ');
      if (nameParts.length > 1) {
        _nameController.text = nameParts[0];
        final bankCandidate = nameParts[1];
        if (_banks.contains(bankCandidate)) {
          _selectedBank = bankCandidate;
        }
      } else {
        _nameController.text = rawName;
      }
      
      _amountController.text = NumberFormat('#,###', 'vi_VN').format(widget.debtRecord!.totalAmount);
      _noteController.text = widget.debtRecord!.title;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(widget.debtRecord!.nextDueDate);
      
      if (widget.debtRecord!.monthlyPayment > 0) {
        final estMonths = (widget.debtRecord!.totalAmount / widget.debtRecord!.monthlyPayment).round();
        _monthsController.text = estMonths > 0 ? estMonths.toString() : '12';
      }
    }
    _loadWallets();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.debtRecord != null;
    final themeColor = _selectedType == 'cho_vay' ? const Color(0xFF10B981) : const Color(0xFFEF4444);

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
                isEdit ? 'Chỉnh sửa khoản vay nợ' : 'Khoản vay nợ mới',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'cho_vay',
                      label: Text('Tôi cho vay'),
                      icon: Icon(Icons.arrow_upward_rounded),
                    ),
                    ButtonSegment(
                      value: 'di_vay',
                      label: Text('Tôi đi vay'),
                      icon: Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (set) => setState(() {
                    _selectedType = set.first;
                    _receiveToWallet = false;
                  }),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: themeColor.withOpacity(0.15),
                    selectedForegroundColor: themeColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _selectedType == 'cho_vay' ? 'Tên người vay' : 'Tên chủ nợ/đối tác',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Vui lòng nhập tên đối tác' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Số tiền gốc',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  suffixText: '₫',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final clean = v!.replaceAll(RegExp(r'\D'), '');
                  final val = int.tryParse(clean);
                  if (val == null || val <= 0) return 'Số tiền không hợp lệ';
                  return null;
                },
              ),
              if (_selectedType == 'di_vay') ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBank,
                  items: _banks.map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(b),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBank = val);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Ngân hàng cho vay',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _monthsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Kỳ hạn vay (tháng)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final val = int.tryParse(v ?? '');
                    if (val == null || val <= 0) return 'Kỳ hạn không hợp lệ';
                    return null;
                  },
                ),
                if (!isEdit && _wallets.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _receiveToWallet,
                        onChanged: (val) => setState(() => _receiveToWallet = val ?? false),
                      ),
                      const Text('Nhận tiền vào tài khoản', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  if (_receiveToWallet) ...[
                    DropdownButtonFormField<WalletModel>(
                      initialValue: _selectedWallet,
                      items: _wallets.map((w) => DropdownMenuItem(
                        value: w,
                        child: Text('${w.name} (${formatCurrency(w.balance)})'),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedWallet = val),
                      decoration: InputDecoration(
                        labelText: 'Nhận vào ví',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Ghi chú (Tùy chọn)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                tileColor: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text(
                  'Hạn thanh toán',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                  if (picked != null && mounted) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              if (_selectedType == 'di_vay' && _calculatedMonthlyPayment > 0) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: themeColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Lãi suất áp dụng:', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                          Text('${_bankRates[_selectedBank]}% / năm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Trả mỗi tháng (gốc + lãi):', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                          Text(formatCurrency(_calculatedMonthlyPayment), style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
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
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final name = _nameController.text.trim();
                    final note = _noteController.text.trim();
                    
                    final clean = _amountController.text.replaceAll(RegExp(r'\D'), '');
                    final totalAmt = int.parse(clean);
                    
                    final bankSuffix = _selectedType == 'di_vay' ? ' - $_selectedBank' : '';
                    final compositeLenderName = '$_selectedType|$name$bankSuffix';

                    final monthlyVal = _selectedType == 'di_vay' ? _calculatedMonthlyPayment : 0;
                    final rate = _selectedType == 'di_vay' ? (_bankRates[_selectedBank] ?? 0.0) : 0.0;

                    final debt = DebtRecord(
                      id: widget.debtRecord?.id ?? 'debt_${DateTime.now().millisecondsSinceEpoch}',
                      userId: widget.userId,
                      title: note,
                      lenderName: compositeLenderName,
                      totalAmount: totalAmt,
                      paidAmount: widget.debtRecord?.paidAmount ?? 0,
                      monthlyPayment: monthlyVal,
                      interestRate: rate,
                      nextDueDate: _selectedDate.millisecondsSinceEpoch,
                      createdAt: widget.debtRecord?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                      status: (widget.debtRecord?.paidAmount ?? 0) >= totalAmt ? 'settled' : 'active',
                    );

                    try {
                      // Xử lý nạp tiền vào ví nếu chọn "Nhận tiền vào tài khoản"
                      if (_selectedType == 'di_vay' && _receiveToWallet && _selectedWallet != null && !isEdit) {
                        final newBalance = _selectedWallet!.balance + totalAmt;
                        await _repository.upsertWallet(_selectedWallet!.copyWith(balance: newBalance));

                        final tx = TransactionModel(
                          id: 'tx_debt_inc_${DateTime.now().millisecondsSinceEpoch}',
                          userId: widget.userId,
                          walletId: _selectedWallet!.id,
                          categoryId: 'debt_loan',
                          categoryName: 'Đi vay',
                          type: 'income',
                          amount: totalAmt.toDouble(),
                          note: 'Nhận tiền khoản vay: $name',
                          transactionDate: DateTime.now(),
                        );
                        await _repository.upsertTransaction(tx);
                      }

                      if (isEdit) {
                        await context.read<FinanceProvider>().updateDebtRecord(debt);
                      } else {
                        await context.read<FinanceProvider>().addDebtRecordDirect(debt);
                      }

                      await context.read<FinanceProvider>().refreshFinancialSummary(widget.userId);

                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Đã cập nhật khoản vay nợ'
                                : 'Đã lưu khoản vay nợ',
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
                    isEdit ? 'Cập nhật khoản vay nợ' : 'Lưu khoản vay nợ',
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

class AddLoanSheetPublic extends StatelessWidget {
  const AddLoanSheetPublic({super.key});
  @override
  Widget build(BuildContext context) {
    return _AddDebtSheet(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'user_001',
    );
  }
}
