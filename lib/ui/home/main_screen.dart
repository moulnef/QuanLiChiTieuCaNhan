import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

// --- Các file import của dự án ---
import '../../services/ocr_service.dart';
import '../../ui/home/home_screen.dart';
import '../../ui/transaction/transaction_list_page.dart';
import '../../ui/transaction/create_transaction_page.dart';

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
  late Animation<double> _rotationAnimation; // 💡 THÊM BIẾN XOAY

  final List<Widget> _pages = [
    const HomePage(),
    const TransactionListPage(),
    const SizedBox(),
    const Scaffold(body: Center(child: Text("Trang Thống Kê"))),
    const Scaffold(body: Center(child: Text("Trang Cá Nhân"))),
  ];

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final OCRService _ocrService = OCRService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250)
    );
    // 💡 TẠO HIỆU ỨNG XOAY 45 ĐỘ (0.125 của 1 vòng tròn)
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut)
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  void _onItemTapped(int index) {
    if (index == 2) return;
    if (_isMenuOpen) _toggleMenu();
    setState(() => _selectedIndex = index);
  }

  Future<void> _handleInvoiceScan() async {
    await Permission.photos.request();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (!mounted) return;
      _toggleMenu();

      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator())
      );

      final result = await _ocrService.scanReceipt(File(image.path));

      if (!mounted) return;
      Navigator.pop(context);

      if (result != null && result['amount'] != null) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CreateTransactionPage(
                  initialAmount: result['amount'],
                  initialNote: "Quét từ hóa đơn",
                )
            )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy số tiền hợp lệ trong ảnh!'))
        );
      }
    }
  }

  // --- Giao diện (UI) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: Stack(
        children: [

          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),

          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),

          // LỚP 3: Menu 3 nút nảy lên từ dưới
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            bottom: _isMenuOpen ? 130 : 50,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_isMenuOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isMenuOpen ? 1.0 : 0.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _buildIconOption(
                      icon: Icons.document_scanner_rounded,
                      bgColor: Colors.orange.shade50,
                      iconColor: Colors.orange,
                      onTap: _handleInvoiceScan,
                    ),
                    const SizedBox(width: 24),
                    _buildIconOption(
                      icon: Icons.mic_rounded,
                      bgColor: Colors.blue.shade50,
                      iconColor: Colors.blue,
                      onTap: () {
                        // TODO: Gắn hàm xử lý giọng nói vào đây
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildIconOption(
                      icon: Icons.edit_rounded,
                      bgColor: Colors.green.shade50,
                      iconColor: Colors.green,
                      onTap: () {
                        _toggleMenu();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTransactionPage()));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // LỚP 4: Navbar nổi dưới cùng (Phong cách iPhone)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Container(
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(0, Icons.home_rounded, Icons.home),
                    _buildNavItem(1, Icons.list_alt_rounded, Icons.list),
                    const SizedBox(width: 60),
                    _buildNavItem(3, Icons.pie_chart_outline_rounded, Icons.pie_chart),
                    _buildNavItem(4, Icons.person_outline_rounded, Icons.person),
                  ],
                ),
              ),
            ),
          ),

          // 💡 LỚP 5: Nút Dấu cộng (+) xoay
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: Transform.scale(
                scale: 1.1,
                child: FloatingActionButton(
                  onPressed: _toggleMenu,
                  backgroundColor: Colors.blueAccent,
                  elevation: 4,
                  shape: const CircleBorder(),
                  // 💡 ĐÃ SỬA: Đổi thành Icon dấu cộng và bọc trong RotationTransition
                  child: RotationTransition(
                    turns: _rotationAnimation,
                    child: const Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconOption({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            isSelected ? filledIcon : outlineIcon,
            key: ValueKey<bool>(isSelected),
            color: isSelected ? Colors.blueAccent : Colors.grey.shade400,
            size: 28,
          ),
        ),
      ),
    );
  }
}