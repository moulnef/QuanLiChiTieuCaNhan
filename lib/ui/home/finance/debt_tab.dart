import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/debt_record.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/remote/firestore_service.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/providers/finance_provider.dart';
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
  final FirestoreService _firestoreService = FirestoreService();
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

  Future<void> _handlePay(DebtRecord item) async {
    final cleanName = item.lenderName.replaceAll('cho_vay|', '').replaceAll('di_vay|', '');
    final isChoVay = item.lenderName.startsWith('cho_vay|');

    final amount = await _showAmountDialog(
      title: isChoVay ? 'Thu nợ từ $cleanName' : 'Thanh toán nợ cho $cleanName',
      actionLabel: 'Xác nhận',
      maxAmount: item.remainingAmount,
    );

    if (!mounted || amount == null) return;

    try {
      final newPaid = item.paidAmount + amount;
      final isSettled = newPaid >= item.totalAmount;
      final updated = item.copyWith(
        paidAmount: newPaid,
        status: isSettled ? 'settled' : 'active',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await context.read<FinanceProvider>().updateDebtRecord(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isChoVay
                ? 'Đã thu ${formatCurrency(amount)} từ "$cleanName" ${isSettled ? '🎉 Đã tất toán!' : ''}'
                : 'Đã trả ${formatCurrency(amount)} cho "$cleanName" ${isSettled ? '🎉 Đã tất toán!' : ''}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
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
                  labelText: 'Số tiền',
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
                  if (maxAmount != null && val > maxAmount) {
                    return 'Vượt quá số dư còn lại';
                  }
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
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF2563EB),
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
            stream: _firestoreService.streamDebts(),
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

  String _selectedType = 'cho_vay'; // 'cho_vay' or 'di_vay'
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    if (widget.debtRecord != null) {
      final isChoVay = widget.debtRecord!.lenderName.startsWith('cho_vay|');
      _selectedType = isChoVay ? 'cho_vay' : 'di_vay';
      _nameController.text = widget.debtRecord!.lenderName
          .replaceAll('cho_vay|', '')
          .replaceAll('di_vay|', '');
      _amountController.text = widget.debtRecord!.totalAmount.toString();
      _noteController.text = widget.debtRecord!.title;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(widget.debtRecord!.nextDueDate);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
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
                  onSelectionChanged: (set) => setState(() => _selectedType = set.first),
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
                  labelText: _selectedType == 'cho_vay' ? 'Tên người vay' : 'Tên chủ nợ',
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
                decoration: InputDecoration(
                  labelText: 'Số tiền gốc',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  suffixText: '₫',
                ),
                validator: (v) {
                  final val = int.tryParse(v!.trim());
                  if (val == null || val <= 0) return 'Số tiền không hợp lệ';
                  return null;
                },
              ),
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
                    final totalAmt = int.parse(_amountController.text.trim());
                    
                    final compositeLenderName = '${_selectedType}|${name}';

                    final debt = DebtRecord(
                      id: widget.debtRecord?.id ?? 'debt_${DateTime.now().millisecondsSinceEpoch}',
                      userId: widget.userId,
                      title: note,
                      lenderName: compositeLenderName,
                      totalAmount: totalAmt,
                      paidAmount: widget.debtRecord?.paidAmount ?? 0,
                      monthlyPayment: widget.debtRecord?.monthlyPayment ?? 0,
                      interestRate: widget.debtRecord?.interestRate ?? 0.0,
                      nextDueDate: _selectedDate.millisecondsSinceEpoch,
                      createdAt: widget.debtRecord?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                      status: (widget.debtRecord?.paidAmount ?? 0) >= totalAmt ? 'settled' : 'active',
                    );

                    try {
                      if (isEdit) {
                        await context.read<FinanceProvider>().updateDebtRecord(debt);
                      } else {
                        await context.read<FinanceProvider>().addDebtRecordDirect(debt);
                      }

                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Đã cập nhật khoản vay nợ'
                                : 'Đã thêm khoản vay nợ mới',
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
