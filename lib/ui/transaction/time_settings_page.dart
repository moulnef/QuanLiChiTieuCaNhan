import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import 'transaction_list_controller.dart';

class TimeSettingsPage extends ConsumerStatefulWidget {
  const TimeSettingsPage({super.key});

  @override
  ConsumerState<TimeSettingsPage> createState() => _TimeSettingsPageState();
}

class _TimeSettingsPageState extends ConsumerState<TimeSettingsPage> {
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();
  String? _selectedOptionLabel;

  // --- HÀM XỬ LÝ CHUNG: ÁP DỤNG BỘ LỌC ---
  void _applyDateRange(DateTime start, DateTime end, String label) {
    setState(() => _selectedOptionLabel = label);
    final range = DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day, 23, 59, 59),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        ref.read(transactionListControllerProvider.notifier).updateDateRange(range);
        Navigator.pop(context);
      }
    });
  }

  // =========================================================
  // HÀM TẠO GIAO DIỆN LỊCH SỔ CÒNG ĐA NĂNG (ĐÃ SỬA TÊN KHÔNG DẤU)
  // mode: 0 (Chọn 1 ngày), 1 (Chọn 1 tháng), 2 (Chọn range 2 ngày)
  // =========================================================
  Future<DateTimeRange?> _showSoCongDatePicker(BuildContext context, {required int mode, DateTime? initStart, DateTime? initEnd}) async {
    DateTime tempStart = initStart ?? DateTime.now();
    DateTime tempEnd = initEnd ?? DateTime.now();
    bool isSelectingStart = true;

    return await showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- DIV 1: KHỐI HEADER LƠ LỬNG ---
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() => isSelectingStart = true),
                                child: Center(
                                  child: Text(
                                    mode == 1 ? DateFormat('MM/yyyy').format(tempStart) : DateFormat('dd/MM/yyyy').format(tempStart),
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelectingStart ? Colors.blue : Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ),
                            if (mode == 2) ...[
                              Container(width: 1, height: 24, color: Colors.grey.shade300),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => isSelectingStart = false),
                                  child: Center(
                                    child: Text(
                                      DateFormat('dd/MM/yyyy').format(tempEnd),
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: !isSelectingStart ? Colors.blue : Colors.grey.shade400),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // --- DIV 2: KHỐI NỘI DUNG CHỌN ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 280,
                              child: mode == 1
                                  ? CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.monthYear,
                                initialDateTime: tempStart,
                                onDateTimeChanged: (date) => setDialogState(() => tempStart = date),
                              )
                                  : CalendarDatePicker(
                                initialDate: isSelectingStart ? tempStart : tempEnd,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                onDateChanged: (date) {
                                  setDialogState(() {
                                    if (isSelectingStart) {
                                      tempStart = date;
                                      if (mode == 2) isSelectingStart = false;
                                    } else {
                                      tempEnd = date;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () { setDialogState(() { tempStart = DateTime.now(); tempEnd = DateTime.now(); }); },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: const BorderSide(color: Colors.blue),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text("Hôm nay", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context, DateTimeRange(start: tempStart, end: tempEnd)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text("Xong", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(top: 45, left: 60, child: Container(width: 5, height: 20, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(5)))),
                  Positioned(top: 45, right: 60, child: Container(width: 5, height: 20, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(5)))),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          title: const Text("Chọn thời gian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () => _applyDateRange(DateTime(2000), DateTime(2100), "Tất cả"),
              child: const Text("Tất cả", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            )
          ],
          bottom: const TabBar(
            isScrollable: true, labelColor: Colors.blue, unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue, indicatorWeight: 3,
            tabs: [Tab(text: "Ngày"), Tab(text: "Tuần"), Tab(text: "Tháng"), Tab(text: "Quý"), Tab(text: "Tùy chọn")],
          ),
        ),
        body: TabBarView(children: [_buildDayTab(), _buildWeekTab(), _buildMonthTab(), _buildQuarterTab(), _buildCustomTab()]),
      ),
    );
  }

  Widget _buildDayTab() {
    final now = DateTime.now();
    return _buildListOptions([
      _OptionItem("Hôm nay", () => _applyDateRange(now, now, "Hôm nay")),
      _OptionItem("Hôm qua", () => _applyDateRange(now.subtract(const Duration(days: 1)), now.subtract(const Duration(days: 1)), "Hôm qua")),
      _OptionItem("Ngày khác...", () async {
        final res = await _showSoCongDatePicker(context, mode: 0);
        if (res != null) _applyDateRange(res.start, res.start, "Ngày khác...");
      }, icon: Icons.calendar_month),
    ]);
  }

  Widget _buildWeekTab() {
    final now = DateTime.now();
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    return _buildListOptions([
      _OptionItem("Tuần này", () => _applyDateRange(startOfThisWeek, startOfThisWeek.add(const Duration(days: 6)), "Tuần này")),
      _OptionItem("Tuần trước", () => _applyDateRange(startOfThisWeek.subtract(const Duration(days: 7)), startOfThisWeek.subtract(const Duration(days: 1)), "Tuần trước")),
    ]);
  }

  Widget _buildMonthTab() {
    final now = DateTime.now();
    return _buildListOptions([
      _OptionItem("Tháng này", () => _applyDateRange(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0), "Tháng này")),
      _OptionItem("Tháng trước", () => _applyDateRange(DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0), "Tháng trước")),
      _OptionItem("Tháng khác...", () async {
        final res = await _showSoCongDatePicker(context, mode: 1);
        if (res != null) _applyDateRange(DateTime(res.start.year, res.start.month, 1), DateTime(res.start.year, res.start.month + 1, 0), "Tháng khác...");
      }, icon: Icons.date_range),
    ]);
  }

  Widget _buildQuarterTab() {
    final y = DateTime.now().year;
    return _buildListOptions([
      _OptionItem("Quý I ($y)", () => _applyDateRange(DateTime(y, 1, 1), DateTime(y, 3, 31), "Q1")),
      _OptionItem("Quý II ($y)", () => _applyDateRange(DateTime(y, 4, 1), DateTime(y, 6, 30), "Q2")),
      _OptionItem("Quý III ($y)", () => _applyDateRange(DateTime(y, 7, 1), DateTime(y, 9, 30), "Q3")),
      _OptionItem("Quý IV ($y)", () => _applyDateRange(DateTime(y, 10, 1), DateTime(y, 12, 31), "Q4")),
    ]);
  }

  Widget _buildCustomTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListOptions([_OptionItem("Toàn bộ thời gian", () => _applyDateRange(DateTime(2000), DateTime(2100), "Tất cả"), icon: Icons.all_inclusive)]),
          const SizedBox(height: 24),
          const Text("TÙY CHỌN KHOẢNG THỜI GIAN", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: () async {
                final res = await _showSoCongDatePicker(context, mode: 2, initStart: _customStartDate, initEnd: _customEndDate);
                if (res != null) {
                  setState(() { _customStartDate = res.start; _customEndDate = res.end; });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Từ ngày", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(DateFormat('dd/MM/yyyy').format(_customStartDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.blue, size: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Đến ngày", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(DateFormat('dd/MM/yyyy').format(_customEndDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_customStartDate.isAfter(_customEndDate)) {
                  _showErrorNotification("Ngày bắt đầu không thể lớn hơn ngày kết thúc!");
                  return;
                }
                _applyDateRange(_customStartDate, _customEndDate, "Tùy chọn");
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Áp dụng", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  void _showErrorNotification(String message) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(30)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 1),
    );
  }

  Widget _buildListOptions(List<_OptionItem> options) {
    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = _selectedOptionLabel == option.label;
        return Theme(
          data: Theme.of(context).copyWith(hoverColor: Colors.transparent, highlightColor: Colors.blue.shade50),
          child: Card(
            elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              selected: isSelected, selectedTileColor: Colors.blue.shade50,
              title: Text(option.label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.blue : Colors.black87)),
              trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : Icon(option.icon ?? Icons.chevron_right, color: Colors.grey),
              onTap: option.onTap,
            ),
          ),
        );
      },
    );
  }
}

class _OptionItem {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  _OptionItem(this.label, this.onTap, {this.icon});
}