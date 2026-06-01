import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/saving.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/wallet_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/transaction_model.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/utils/money_formatter.dart';

String formatCurrency(num amount) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);

String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

class SavingTabPage extends StatefulWidget {
  const SavingTabPage({super.key});

  @override
  State<SavingTabPage> createState() => _SavingTabPageState();
}

class _SavingTabPageState extends State<SavingTabPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FinanceRepository _repository = FinanceRepository();

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'user_001';

  Future<Map<String, dynamic>?> _showDepositDialog(SavingGoal item, List<WalletModel> wallets) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    WalletModel selectedWallet = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Nạp tiền tiết kiệm', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    labelText: 'Nguồn tiền',
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
                    suffixText: '₫',
                    hintText: 'Nhập số tiền...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    final clean = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                    final val = int.tryParse(clean);
                    if (val == null || val <= 0) return 'Số tiền không hợp lệ';
                    if (val > selectedWallet.balance) return 'Không đủ số dư trong ví';
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
              child: const Text('Nạp ngay'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showWithdrawDialog(SavingGoal item, List<WalletModel> wallets) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    WalletModel selectedWallet = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Rút tiền tiết kiệm', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    labelText: 'Ví nhận tiền',
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
                    suffixText: '₫',
                    hintText: 'Nhập số tiền...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    final clean = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                    final val = int.tryParse(clean);
                    if (val == null || val <= 0) return 'Số tiền không hợp lệ';
                    if (val > item.currentAmount) return 'Vượt quá số tiền tiết kiệm hiện có';
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
              child: const Text('Rút tiền'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeposit(SavingGoal item) async {
    final walletsData = await _repository.getWalletsByUserId(_currentUserId);
    final wallets = walletsData.map((w) => WalletModel.fromMap(w)).toList();

    if (wallets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tạo ví trước khi nạp tiền')),
      );
      return;
    }

    final result = await _showDepositDialog(item, wallets);
    if (result == null || !mounted) return;

    final amount = result['amount'] as int;
    final wallet = result['wallet'] as WalletModel;

    try {
      // 1. Trừ tiền ví nguồn
      final newBalance = wallet.balance - amount;
      await _repository.upsertWallet(wallet.copyWith(balance: newBalance));

      // 2. Tạo giao dịch chuyển tiền vào quỹ
      final tx = TransactionModel(
        id: 'tx_saving_dep_${DateTime.now().millisecondsSinceEpoch}',
        userId: _currentUserId,
        walletId: wallet.id,
        categoryId: 'saving_dep',
        categoryName: 'Gửi tiết kiệm',
        type: 'expense',
        amount: amount.toDouble(),
        note: 'Nạp tiền tiết kiệm: ${item.title}',
        transactionDate: DateTime.now(),
      );
      await _repository.upsertTransaction(tx);

      // 3. Cộng tiền vào mục tiêu tiết kiệm
      final newCurrent = item.currentAmount + amount;
      final completed = newCurrent >= item.targetAmount;
      final updated = item.copyWith(
        currentAmount: newCurrent,
        status: completed ? 'completed' : 'active',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await context.read<FinanceProvider>().updateSavingGoal(updated);
      await context.read<FinanceProvider>().refreshFinancialSummary(_currentUserId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nạp ${formatCurrency(amount)} từ ví "${wallet.name}" vào "${item.title}" ${completed ? '🎉 Hoàn thành!' : ''}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _handleWithdraw(SavingGoal item) async {
    final walletsData = await _repository.getWalletsByUserId(_currentUserId);
    final wallets = walletsData.map((w) => WalletModel.fromMap(w)).toList();

    if (wallets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng tạo ví trước khi rút tiền')),
      );
      return;
    }

    final result = await _showWithdrawDialog(item, wallets);
    if (result == null || !mounted) return;

    final amount = result['amount'] as int;
    final wallet = result['wallet'] as WalletModel;

    try {
      // 1. Cộng tiền vào ví chính được chọn
      final newBalance = wallet.balance + amount;
      await _repository.upsertWallet(wallet.copyWith(balance: newBalance));

      // 2. Tạo giao dịch nhận tiền từ quỹ
      final tx = TransactionModel(
        id: 'tx_saving_wd_${DateTime.now().millisecondsSinceEpoch}',
        userId: _currentUserId,
        walletId: wallet.id,
        categoryId: 'saving_wd',
        categoryName: 'Rút tiết kiệm',
        type: 'income',
        amount: amount.toDouble(),
        note: 'Rút tiền tiết kiệm: ${item.title}',
        transactionDate: DateTime.now(),
      );
      await _repository.upsertTransaction(tx);

      // 3. Trừ tiền khỏi mục tiêu tiết kiệm
      final newCurrent = item.currentAmount - amount;
      final updated = item.copyWith(
        currentAmount: newCurrent,
        status: 'active',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await context.read<FinanceProvider>().updateSavingGoal(updated);
      await context.read<FinanceProvider>().refreshFinancialSummary(_currentUserId);

      if (!mounted) return;

      // 4. Nếu rút hết khi đạt 100%, hỏi xem có muốn đóng mục tiêu không
      if (newCurrent == 0 && item.currentAmount >= item.targetAmount) {
        final shouldClose = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Đóng mục tiêu?', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('Mục tiêu "${item.title}" đã rút hết tiền. Bạn có muốn đóng mục tiêu tiết kiệm này không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Đồng ý', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldClose == true && mounted) {
          await context.read<FinanceProvider>().deleteSavingGoal(item.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã đóng và xóa mục tiêu tiết kiệm "${item.title}"')),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã rút ${formatCurrency(amount)} về ví "${wallet.name}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _showAddSavingSheet([SavingGoal? savingGoal]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSavingGoalSheet(
        userId: _currentUserId,
        savingGoal: savingGoal,
      ),
    );
  }

  Future<bool?> _confirmDelete(SavingGoal item) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa mục tiêu tiết kiệm "${item.title}"?'),
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
    return StreamBuilder<List<SavingGoal>>(
      stream: _firestoreService.streamSavings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return _EmptyState(onCreate: () => _showAddSavingSheet());
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _AddButton(onPressed: () => _showAddSavingSheet()),
              );
            }

            final item = items[index];
            return Dismissible(
              key: Key(item.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(item),
              onDismissed: (_) async {
                try {
                  await context.read<FinanceProvider>().deleteSavingGoal(item.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã xóa mục tiêu tiết kiệm "${item.title}"')),
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
                onTap: () => _showAddSavingSheet(item),
                child: _SavingGoalCard(
                  item: item,
                  onDeposit: () => _handleDeposit(item),
                  onWithdraw: () => _handleWithdraw(item),
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
  final SavingGoal item;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  const _SavingGoalCard({
    required this.item,
    required this.onDeposit,
    required this.onWithdraw,
  });

  Color _getColor() {
    if (item.colorValue != null) {
      return Color(item.colorValue!);
    }
    return AppColors.financeGreen;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (item.currentAmount / item.targetAmount).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();
    final isCompleted = item.currentAmount >= item.targetAmount || item.status == 'completed';
    final cardColor = _getColor();

    final deadlineDate = DateTime.fromMillisecondsSinceEpoch(item.targetDate);
    final isOverdue = deadlineDate.isBefore(DateTime.now()) && !isCompleted;
    final daysLeft = deadlineDate.difference(DateTime.now()).inDays;

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
                              'Hoàn thành 🎉',
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
                          ? 'Đã hoàn thành mục tiêu!'
                          : (isOverdue
                              ? 'Đã quá hạn ${daysLeft.abs()} ngày'
                              : 'Còn $daysLeft ngày (Hạn: ${formatDate(deadlineDate)})'),
                      style: TextStyle(
                        color: isOverdue ? Colors.redAccent : const Color(0xFF94A3B8),
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
                style: TextStyle(
                  color: cardColor,
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
              valueColor: AlwaysStoppedAnimation(cardColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountColumn(label: 'Hiện tại', amount: item.currentAmount, color: cardColor),
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
  final String userId;
  final SavingGoal? savingGoal;

  const _AddSavingGoalSheet({
    required this.userId,
    this.savingGoal,
  });

  @override
  State<_AddSavingGoalSheet> createState() => _AddSavingGoalSheetState();
}

class _AddSavingGoalSheetState extends State<_AddSavingGoalSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  String _selectedEmoji = '🎯';
  Color _selectedColor = AppColors.financeGreen;

  final List<String> _emojiList = ['🎯', '🏍️', '📱', '💻', '💰', '🏠', '🚗', '✈️', '🗾', '🎒', '💍', '🎁'];

  final List<Color> _colorList = [
    AppColors.financeGreen,
    AppColors.blue,
    AppColors.purple,
    AppColors.warning,
    AppColors.danger,
    AppColors.teal,
  ];

  int get _calculatedMonthlySaving {
    final amountText = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final target = int.tryParse(amountText) ?? 0;
    final current = widget.savingGoal?.currentAmount ?? 0;
    if (target <= current) return 0;

    final now = DateTime.now();
    int monthsRemaining = ((_selectedDate.year - now.year) * 12) + _selectedDate.month - now.month;
    if (monthsRemaining <= 0) {
      monthsRemaining = 1;
    }
    return ((target - current) / monthsRemaining).round();
  }

  @override
  void initState() {
    super.initState();
    if (widget.savingGoal != null) {
      _titleController.text = widget.savingGoal!.title;
      _amountController.text = NumberFormat('#,###', 'vi_VN').format(widget.savingGoal!.targetAmount);
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(widget.savingGoal!.targetDate);
      _selectedEmoji = widget.savingGoal!.icon;
      if (widget.savingGoal!.colorValue != null) {
        _selectedColor = Color(widget.savingGoal!.colorValue!);
      }
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
                widget.savingGoal != null ? 'Chỉnh sửa mục tiêu' : 'Mục tiêu tiết kiệm mới',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Số tiền cần tiết kiệm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final clean = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                  final amount = int.tryParse(clean);
                  if (amount == null || amount <= 0) {
                    return 'Số tiền không hợp lệ';
                  }
                  return null;
                },
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
                          color: isSelected ? _selectedColor.withOpacity(0.15) : const Color(0xFFF1F5F9),
                          border: Border.all(
                            color: isSelected ? _selectedColor : Colors.transparent,
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
              const SizedBox(height: 18),
              const Text(
                'Chọn màu sắc',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorList.length,
                  itemBuilder: (context, index) {
                    final color = _colorList[index];
                    final isSelected = color.value == _selectedColor.value;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black87 : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                tileColor: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                title: const Text(
                  'Ngày dự kiến hoàn thành',
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
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              if (_calculatedMonthlySaving > 0) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _selectedColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cần tiết kiệm mỗi tháng:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      Text(
                        formatCurrency(_calculatedMonthlySaving),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _selectedColor,
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
                    backgroundColor: _selectedColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final title = _titleController.text.trim();
                    final cleanAmt = _amountController.text.replaceAll(RegExp(r'\D'), '');
                    final targetAmt = int.parse(cleanAmt);
                    final currentAmt = widget.savingGoal?.currentAmount ?? 0;
                    final isDone = currentAmt >= targetAmt;

                    final goal = SavingGoal(
                      id: widget.savingGoal?.id ?? 'saving_${DateTime.now().millisecondsSinceEpoch}',
                      userId: widget.userId,
                      title: title,
                      icon: _selectedEmoji,
                      currentAmount: currentAmt,
                      targetAmount: targetAmt,
                      targetDate: _selectedDate.millisecondsSinceEpoch,
                      createdAt: widget.savingGoal?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                      status: isDone ? 'completed' : 'active',
                      colorValue: _selectedColor.value,
                    );

                    try {
                      if (widget.savingGoal != null) {
                        await context.read<FinanceProvider>().updateSavingGoal(goal);
                      } else {
                        await context.read<FinanceProvider>().addSavingGoal(
                          title: title,
                          targetAmount: targetAmt,
                          deadline: _selectedDate,
                          icon: _selectedEmoji,
                          color: _selectedColor,
                        );
                      }

                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(widget.savingGoal != null
                              ? 'Đã cập nhật mục tiêu tiết kiệm "$title"'
                              : 'Đã thêm mục tiêu tiết kiệm "$title"'),
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
                    widget.savingGoal != null ? 'Cập nhật mục tiêu' : 'Tạo mục tiêu',
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

class AddSavingSheetPublic extends StatelessWidget {
  const AddSavingSheetPublic({super.key});
  @override
  Widget build(BuildContext context) {
    return _AddSavingGoalSheet(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'user_001',
    );
  }
}