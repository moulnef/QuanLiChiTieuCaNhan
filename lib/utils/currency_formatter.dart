import 'package:intl/intl.dart';

String formatVND(double amount) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  return '${formatter.format(amount)} ₫';
}

String formatVNDCompact(double amount) {
  final absAmount = amount.abs();
  if (absAmount >= 1000000000) {
    final formatted = NumberFormat('0.0', 'vi_VN').format(amount / 1000000000);
    return '$formatted tỷ';
  } else if (absAmount >= 100000000) {
    final formatted = NumberFormat('0.0', 'vi_VN').format(amount / 1000000);
    return '$formatted tr';
  } else if (absAmount >= 1000000) {
    final formatted = NumberFormat('0.00', 'vi_VN').format(amount / 1000000);
    return '$formatted tr';
  } else if (absAmount >= 1000) {
    final formatted = NumberFormat('0', 'vi_VN').format(amount / 1000);
    return '${formatted}k';
  }
  return formatVND(amount);
}
