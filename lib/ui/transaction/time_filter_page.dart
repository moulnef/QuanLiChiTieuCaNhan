import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeFilterPage extends StatefulWidget {
  const TimeFilterPage({super.key});

  @override
  State<TimeFilterPage> createState() => _TimeFilterPageState();
}

class _TimeFilterPageState extends State<TimeFilterPage> {
  // Biến lưu trạng thái riêng của trang này
  String _selectedDayOption = 'Hôm nay';
  DateTime _customDate = DateTime.now();

  String _selectedCustomRangeOption = 'Toàn bộ';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
          title: const Text("Chọn thời gian", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Theo ngày"),
              Tab(text: "Theo tuần"),
              Tab(text: "Theo tháng"),
              Tab(text: "Theo quý"),
              Tab(text: "Tùy chọn"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabDay(),
            _buildSimpleList(['Tuần này', 'Tuần trước']),
            _buildSimpleList(['Tháng này', 'Tháng trước', 'Tháng khác']), // Bạn có thể phát triển thêm DatePicker tháng sau
            _buildSimpleList(['Quý I', 'Quý II', 'Quý III', 'Quý IV']),
            _buildTabCustomRange(),
          ],
        ),
      ),
    );
  }

  // ================= TAB 1: THEO NGÀY =================
  Widget _buildTabDay() {
    return Column(
      children: [
        RadioListTile(
          title: const Text("Hôm nay"), value: 'Hôm nay', groupValue: _selectedDayOption,
          onChanged: (v) => setState(() => _selectedDayOption = v!),
        ),
        RadioListTile(
          title: const Text("Hôm qua"), value: 'Hôm qua', groupValue: _selectedDayOption,
          onChanged: (v) => setState(() => _selectedDayOption = v!),
        ),
        RadioListTile(
          title: const Text("Ngày khác"), value: 'Ngày khác', groupValue: _selectedDayOption,
          onChanged: (v) => setState(() => _selectedDayOption = v!),
        ),

        // CHỈ HIỆN LỊCH VÀ NÚT KHI CHỌN "NGÀY KHÁC"
        if (_selectedDayOption == 'Ngày khác') ...[
          const Divider(),
          // Ô "Treo" ngày người dùng chọn
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.blue.shade50,
            width: double.infinity,
            alignment: Alignment.center,
            child: Text(
              "Đang chọn: ${DateFormat('dd/MM/yyyy').format(_customDate)}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
            ),
          ),
          // Bảng lịch
          Expanded(
            child: CalendarDatePicker(
              initialDate: _customDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onDateChanged: (date) => setState(() => _customDate = date),
            ),
          ),
          // 2 Nút (Hôm nay & Xong)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _customDate = DateTime.now()),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text("Hôm nay"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, DateFormat('dd/MM/yyyy').format(_customDate)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text("Xong", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          )
        ] else ...[
          // Nếu chỉ chọn Hôm nay/Hôm qua thì hiện nút Xác nhận chung
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selectedDayOption),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text("Áp dụng", style: TextStyle(color: Colors.white)),
            )),
          )
        ]
      ],
    );
  }

  // ================= TAB 5: TÙY CHỌN (TỪ NGÀY - ĐẾN NGÀY) =================
  Widget _buildTabCustomRange() {
    return Column(
      children: [
        RadioListTile(
          title: const Text("Toàn bộ thời gian"), value: 'Toàn bộ', groupValue: _selectedCustomRangeOption,
          onChanged: (v) => setState(() => _selectedCustomRangeOption = v!),
        ),
        RadioListTile(
          title: const Text("Tùy chọn khoảng thời gian"), value: 'Tùy chọn', groupValue: _selectedCustomRangeOption,
          onChanged: (v) => setState(() => _selectedCustomRangeOption = v!),
        ),

        if (_selectedCustomRangeOption == 'Tùy chọn') ...[
          const Divider(),
          // Ô "Treo" từ ngày đến ngày
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.blue.shade50,
            width: double.infinity,
            alignment: Alignment.center,
            child: Text(
              "${DateFormat('dd/MM/yyyy').format(_startDate)}  -  ${DateFormat('dd/MM/yyyy').format(_endDate)}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
            ),
          ),
          const SizedBox(height: 20),
          // Nút chọn ngày
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _startDate = picked);
                },
                icon: const Icon(Icons.calendar_today, size: 16), label: const Text("Chọn Từ ngày"),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _endDate = picked);
                },
                icon: const Icon(Icons.calendar_today, size: 16), label: const Text("Chọn Đến ngày"),
              ),
            ],
          ),
          const Spacer(),
          // Nút Xác nhận
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, "${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM').format(_endDate)}"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text("Xong", style: TextStyle(color: Colors.white)),
              ),
            ),
          )
        ] else ...[
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(context, 'Toàn bộ thời gian'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text("Áp dụng", style: TextStyle(color: Colors.white)),
            )),
          )
        ]
      ],
    );
  }

  // --- Hàm hỗ trợ tạo các List đơn giản (Cho Tuần, Tháng, Quý) ---
  Widget _buildSimpleList(List<String> options) {
    return ListView.builder(
      itemCount: options.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(options[index]),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => Navigator.pop(context, options[index]), // Bấm là chọn luôn
        );
      },
    );
  }
}