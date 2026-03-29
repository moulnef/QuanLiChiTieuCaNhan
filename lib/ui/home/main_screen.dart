import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../transaction/transaction_list_page.dart';
import '../transaction/create_transaction_page.dart';

// --- LỚP HỖ TRỢ ĐIỀU HƯỚNG LỒNG NHAU (GIỮ BOTTOM NAV BAR) ---
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

  // --- TẠO 5 CHÌA KHÓA ĐIỀU HƯỚNG CHO 5 TAB ---
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

  // --- MỞ TRANG THÊM GIAO DỊCH BÊN TRONG TAB HIỆN TẠI ---
  void _openCreateTransaction() {
    _navigatorKeys[_selectedIndex].currentState!.push(
        MaterialPageRoute(builder: (_) => const CreateTransactionPage())
    );
  }

  Widget _buildMenuOption({required IconData icon, required Color iconColor, required Color bgColor, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () { _toggleMenu(); onTap(); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // BỌC CÁC TRANG BẰNG TABNAVIGATOR ĐỂ GIỮ BOTTOM NAV
          IndexedStack(
            index: _selectedIndex,
            children: [
              TabNavigator(navigatorKey: _navigatorKeys[0], rootPage: const HomePage()),
              TabNavigator(navigatorKey: _navigatorKeys[1], rootPage: const TransactionListPage()),
              const SizedBox.shrink(), // Chỗ của nút (+)
              TabNavigator(navigatorKey: _navigatorKeys[3], rootPage: const Center(child: Text("Trang Thống Kê"))),
              TabNavigator(navigatorKey: _navigatorKeys[4], rootPage: const Center(child: Text("Trang Hồ Sơ"))),
            ],
          ),
          if (_isMenuOpen) GestureDetector(onTap: _toggleMenu, child: Container(color: Colors.black54)),
          if (_isMenuOpen)
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuOption(icon: Icons.document_scanner_outlined, iconColor: Colors.orange, bgColor: Colors.orange.shade50, label: "Quét hóa đơn", onTap: () {}),
                  _buildMenuOption(icon: Icons.mic_none, iconColor: Colors.deepPurple, bgColor: Colors.deepPurple.shade50, label: "Nhập giọng nói", onTap: () {}),
                  _buildMenuOption(
                    icon: Icons.edit_outlined, iconColor: Colors.blue, bgColor: Colors.blue.shade50, label: "Thêm thủ công",
                    onTap: _openCreateTransaction, // Gọi hàm mở trang bên trong Tab
                  ),
                ],
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
        padding: EdgeInsets.zero, shape: const CircularNotchedRectangle(), notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Trang chủ'),
              _buildNavItem(1, Icons.swap_horiz_outlined, Icons.swap_horiz, 'Giao dịch'),
              const SizedBox(width: 48),
              _buildNavItem(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Thống kê'),
              _buildNavItem(4, Icons.person_outline, Icons.person, 'Hồ sơ'),
            ],
          ),
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