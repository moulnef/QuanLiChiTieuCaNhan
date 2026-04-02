import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeHeaderWidget extends StatefulWidget {
  // 💡 Khai báo 2 biến để nhận dữ liệu Real-time từ Trang chủ truyền vào
  final double totalIncome;
  final double totalExpense;

  const HomeHeaderWidget({
    super.key,
    required this.totalIncome,
    required this.totalExpense
  });

  @override
  State<HomeHeaderWidget> createState() => _HomeHeaderWidgetState();
}

class _HomeHeaderWidgetState extends State<HomeHeaderWidget> {
  bool _isBalanceVisible = true;

  String _formatMoney(double amount) {
    if (!_isBalanceVisible) return "******";
    return NumberFormat('#,###', 'en_US').format(amount).replaceAll(',', '.');
  }

  @override
  Widget build(BuildContext context) {
    // Tính toán số dư khả dụng ngay tại đây
    double availableBalance = widget.totalIncome - widget.totalExpense;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Xin chào,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Text("Nguyễn Văn An", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Text("👋", style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: const [Icon(Icons.wifi, color: Colors.greenAccent, size: 14), SizedBox(width: 4), Text("Online", style: TextStyle(color: Colors.white, fontSize: 12))]),
                  ),
                  const SizedBox(width: 16),
                  Stack(
                    children: [
                      const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                      Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Text("3", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))
                    ],
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 30),
          const Text("Số dư khả dụng", style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("${_formatMoney(availableBalance)} đ", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible), child: Icon(_isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white70, size: 24)),
            ],
          ),
          const SizedBox(height: 4),
          Text("Tháng ${DateTime.now().month}/${DateTime.now().year}", style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(child: _buildGlassCard("Thu nhập", "+${_formatMoney(widget.totalIncome)} đ", Icons.trending_up, Colors.greenAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildGlassCard("Chi tiêu", "-${_formatMoney(widget.totalExpense)} đ", Icons.trending_down, Colors.redAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(String title, String amount, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1), width: 1)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4), Text(amount, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)])),
        ],
      ),
    );
  }
}