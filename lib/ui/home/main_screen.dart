import 'package:flutter/material.dart';
import '../../ui/home/home_screen.dart';
import '../../ui/home/account_page.dart';
import '../../ui/stats/stats_screen.dart';
import '../../ui/settings/profile_screen.dart';
import '../../ui/transaction/add_transaction_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const AccountPage(),
    const SizedBox.shrink(), // Placeholder cho nút Thêm ở giữa
    const StatsPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) return; // Không làm gì khi bấm vào nút "Thêm" ở BottomNavigationBar
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Trang chủ'),
              _buildNavItem(1, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Tài khoản'),
              const SizedBox(width: 40), // Khoảng trống cho FAB
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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
