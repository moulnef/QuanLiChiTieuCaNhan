import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/core/constants/app_colors.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/saving.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
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
  final FirestoreService _firestoreService = FirestoreService();

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'user_001';

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

  Future<void> _handleDeposit(SavingGoal item) async {
    final amount = await _showAmountDialog(
      title: 'Nạp tiền tiết kiệm',
      actionLabel: 'Nạp ngay',
    );
    if (!mounted || amount == null) return;

    try {
      final newCurrent = item.currentAmount + amount;
      final completed = newCurrent >= item.targetAmount;
      final updated = item.copyWith(
        currentAmount: newCurrent,
        status: completed ? 'completed' : 'active',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await context.read<FinanceProvider>().updateSavingGoal(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã nạp ${formatCurrency(amount)} vào "${item.title}" ${completed ? '🎉 Hoàn thành!' : ''}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _handleWithdraw(SavingGoal item) async {
    final amount = await _showAmountDialog(
      title: 'Rút tiền tiết kiệm',
      actionLabel: 'Rút tiền',
      maxAmount: item.currentAmount,
    );
    if (!mounted || amount == null) return;

    try {
      final newCurrent = item.currentAmount - amount;
      final completed = newCurrent >= item.targetAmount;
      final updated = item.copyWith(
        currentAmount: newCurrent,
        status: completed ? 'completed' : 'active',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await context.read<FinanceProvider>().updateSavingGoal(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã rút ${formatCurrency(amount)} từ "${item.title}"')),
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

  @override
  void initState() {
    super.initState();
    if (widget.savingGoal != null) {
      _titleController.text = widget.savingGoal!.title;
      _amountController.text = widget.savingGoal!.targetAmount.toString();
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
                decoration: InputDecoration(
                  labelText: 'Số tiền cần tiết kiệm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
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
                    final targetAmt = int.parse(_amountController.text.trim());
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