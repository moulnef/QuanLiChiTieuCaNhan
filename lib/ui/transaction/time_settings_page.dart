import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'transaction_list_controller.dart';

class TimeSettingsPage extends ConsumerStatefulWidget {
  const TimeSettingsPage({super.key});

  @override
  ConsumerState<TimeSettingsPage> createState() => _TimeSettingsPageState();
}

class _TimeSettingsPageState extends ConsumerState<TimeSettingsPage> {
  // Logic chọn ngày/tháng/khoảng thời gian của bạn...
  // Sau khi tạo xong file này, Loan hãy bỏ comment ở file TransactionListPage nhé!
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chọn thời gian")),
      body: const Center(child: Text("Giao diện chọn thời gian")),
    );
  }
}