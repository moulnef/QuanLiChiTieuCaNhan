import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:provider/provider.dart';
import '../../ui/home/home_screen.dart';
import '../../ui/transaction/transaction_list_page.dart';
import '../../ui/stats/stats_screen.dart';
import '../../ui/settings/profile_screen.dart';
import '../../ui/transaction/create_transaction_page.dart';
import '../../ui/providers/finance_provider.dart';

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
              TabNavigator(navigatorKey: _navigatorKeys[3], rootPage: const StatsPage()),
              TabNavigator(navigatorKey: _navigatorKeys[4], rootPage: const ProfilePage()),
            ],
          ),
          if (_isMenuOpen) GestureDetector(onTap: _toggleMenu, child: Container(color: Colors.black54)),
          if (_isMenuOpen)
            Positioned(
              bottom: 112, left: 0, right: 0,
              child: Column(
                children: [
                  _buildMenuOption(icon: Icons.document_scanner_outlined, color: Colors.orange, label: "Quét hóa đơn", onTap: () {}),
                  _buildMenuOption(icon: Icons.mic_none, color: Colors.purple, label: "Nhập giọng nói", onTap: () {}),
                  _buildMenuOption(icon: Icons.edit_outlined, color: Colors.blue, label: "Thêm thủ công", onTap: _openCreateTransaction),
                ],
              ),
            ),
        ],
      ),

      floatingActionButton: Transform.translate(
        offset: const Offset(0, 16),
        child: GestureDetector(
          onTap: _toggleMenu,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: RotationTransition(
              turns: _rotationAnimation,
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        child: SizedBox(
          height: 64,
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

  Widget _buildMenuOption({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FloatingActionButton.extended(
        heroTag: label,
        onPressed: () { _toggleMenu(); onTap(); },
        backgroundColor: Colors.white,
        icon: Icon(icon, color: color),
        label: Text(label, style: const TextStyle(color: Colors.black87)),
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
