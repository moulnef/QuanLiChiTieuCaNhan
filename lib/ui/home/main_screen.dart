import 'package:flutter/material.dart';
import '../../ui/home/home_screen.dart';
import '../../ui/transaction/transaction_list_page.dart';
// 💡 ĐÃ VÁ: Tạm thời comment các trang bị thiếu để hết lỗi đỏ
// import '../../ui/stats/stats_screen.dart';
// import '../../ui/settings/profile_screen.dart';
import '../../ui/transaction/create_transaction_page.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/ui/ai_chat/chatbot.dart';
import '../../ui/home/voice_assistant.dart';

class TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootPage;

  const TabNavigator({super.key, required this.navigatorKey, required this.rootPage});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) => rootPage);
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) _animationController.reverse();
    else _animationController.forward();
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  void _onItemTapped(int index) {
    if (index == 2) return;
    if (_isMenuOpen) _toggleMenu();
    setState(() => _selectedIndex = index);
  }

  void _openCreateTransaction() {
    _navigatorKeys[_selectedIndex].currentState!.push(
        MaterialPageRoute(builder: (_) => const CreateTransactionPage())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              TabNavigator(navigatorKey: _navigatorKeys[0], rootPage: const HomePage()),
              TabNavigator(navigatorKey: _navigatorKeys[1], rootPage: const TransactionListPage()),
              const SizedBox.shrink(),
              TabNavigator(navigatorKey: _navigatorKeys[3], rootPage: const Scaffold(body: Center(child: Text("Màn hình Thống kê")))),
              TabNavigator(navigatorKey: _navigatorKeys[4], rootPage: const Scaffold(body: Center(child: Text("Màn hình Hồ sơ")))),
            ],
          ),
          if (_isMenuOpen) GestureDetector(onTap: _toggleMenu, child: Container(color: Colors.black54)),
          if (_isMenuOpen)
            Positioned(
              bottom: 32,
              left: 0, right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuOption(icon: Icons.document_scanner_outlined, iconColor: Colors.orange, bgColor: Colors.orange.shade50, label: "Quét hóa đơn", onTap: () {}),
                  _buildMenuOption(
                      icon: Icons.mic_none,
                      iconColor: Colors.deepPurple,
                      bgColor: Colors.deepPurple.shade50,
                      label: "Nhập giọng nói",
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                          builder: (context) => const VoiceAssistant(),
                        );
                      }
                  ),
                  _buildMenuOption(
                    icon: Icons.edit_outlined,
                    iconColor: Colors.blue,
                    bgColor: Colors.blue.shade50,
                    label: "Thêm thủ công",
                    onTap: _openCreateTransaction,
                    bottomMargin: 0,
                  ),
                ],

              ),
            ),
          Positioned(
            bottom: 20, // Giảm xuống một chút vì con robot to hơn, để nó không bị quá cao so với thanh dưới
            right: 16,  // Giữ nguyên bên phải
            child: GestureDetector(
              onTap: () {
                // Vẫn giữ nguyên lệnh mở Chatbot
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatbotScreen()),
                );
              },
              child: SizedBox( // Chuyển từ Container sang SizedBox để chỉ định kích thước mà không có nền/đổ bóng
                width: 90,  // Tăng kích thước chiều rộng lên 90 (cũ là 65)
                height: 90, // Tăng kích thước chiều cao lên 90 (cũ là 65)
                child: Image.asset(
                  'lib/ui/ai_chat/robot.gif', // Đường dẫn file gif của Thúy
                  fit: BoxFit.contain, // Sử dụng BoxFit.contain để con robot hiện đầy đủ, không bị cắt mất
                  errorBuilder: (context, error, stackTrace) {
                    // Tăng kích thước icon lỗi lên cho tương xứng
                    return const Icon(Icons.smart_toy, color: Colors.purple, size: 50);
                  },
                ),
              ),
            ),
          ),
        ],

      ),

      floatingActionButton: GestureDetector(
        onTap: _toggleMenu,
        child: Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 4))]),
          child: RotationTransition(turns: _rotationAnimation, child: const Icon(Icons.add, color: Colors.white, size: 32)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Trang chủ'),
              _buildNavItem(1, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Tài khoản'),
              const SizedBox(width: 48),
              _buildNavItem(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Thống kê'),
              _buildNavItem(4, Icons.person_outline, Icons.person, 'Hồ sơ'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption({required IconData icon, required Color iconColor, required Color bgColor, required String label, required VoidCallback onTap, double bottomMargin = 16}) {
    return GestureDetector(
      onTap: () { _toggleMenu(); onTap(); },
      child: Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 22)),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.blue : Colors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}