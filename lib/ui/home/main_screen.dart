import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../domain/model/transaction_model.dart';
// Đã sửa lại đường dẫn ocr_service cho đúng chuẩn dự án của Thúy
import '../../domain/services/ocr_service.dart';
import '../../ui/ai_chat/chatbot.dart';
import '../../ui/home/home_screen.dart';
import '../../ui/home/voice_assistant.dart';
import '../../ui/settings/profile_screen.dart';
import '../../ui/stats/stats_screen.dart';
import '../../ui/transaction/create_transaction_page.dart';
import '../../ui/transaction/transaction_list_page.dart';

class TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootPage;

  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.rootPage,
  });

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

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  static const double _chatbotIconSize = 78;
  static const double _chatbotMinTop = 80;
  static const double _chatbotBottomReserve = 120;

  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  Offset? _chatbotOffset;

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
      duration: const Duration(milliseconds: 250),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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

  Future<void> _pushInCurrentTab(Widget page) async {
    if (_isMenuOpen) {
      _toggleMenu();
    }

    final currentNav = _navigatorKeys[_selectedIndex].currentState;
    if (currentNav != null) {
      await currentNav.push(MaterialPageRoute(builder: (_) => page));
      return;
    }

    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openChatbot() {
    _pushInCurrentTab(const ChatbotScreen());
  }

  Future<void> _handleInvoiceScan() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (!mounted) return;
      _toggleMenu();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9))),
      );

      final result = await _ocrService.scanReceiptPath(image.path);

      if (!mounted) return;
      Navigator.pop(context);

      if (result != null && result['amount'] != null) {
        _pushInCurrentTab(
          CreateTransactionPage(
            editData: TransactionModel(
              amount: (result['amount'] as num).toDouble(),
              categoryId: '',
              type: 'expense',
              transactionDate: DateTime.now(),
              note: 'Quét từ hóa đơn',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy số tiền hợp lệ trong ảnh!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool hideAssistiveOverlays = isKeyboardVisible;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _chatbotOffset ??= Offset(
            constraints.maxWidth - _chatbotIconSize - 10,
            constraints.maxHeight - _chatbotIconSize - _chatbotBottomReserve,
          );
          _chatbotOffset = _clampChatbotOffset(_chatbotOffset!, constraints);

          return Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: [
                  TabNavigator(
                    navigatorKey: _navigatorKeys[0],
                    rootPage: const HomePage(),
                  ),
                  TabNavigator(
                    navigatorKey: _navigatorKeys[1],
                    rootPage: const TransactionListPage(),
                  ),
                  const SizedBox.shrink(),
                  TabNavigator(
                    navigatorKey: _navigatorKeys[3],
                    rootPage: const StatsPage(),
                  ),
                  TabNavigator(
                    navigatorKey: _navigatorKeys[4],
                    rootPage: const ProfilePage(),
                  ),
                ],
              ),
              if (!hideAssistiveOverlays && _isMenuOpen)
                GestureDetector(
                  onTap: _toggleMenu,
                  child: Container(color: Colors.black.withValues(alpha: 0.4)),
                ),
              if (!hideAssistiveOverlays)
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
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(30),
                                  ),
                                ),
                                builder: (context) => const VoiceAssistant(),
                              );
                            },
                          ),
                          const SizedBox(width: 24),
                          _buildIconOption(
                            icon: Icons.edit_rounded,
                            bgColor: Colors.green.shade50,
                            iconColor: Colors.green,
                            onTap: () {
                              _toggleMenu();
                              _pushInCurrentTab(const CreateTransactionPage());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: SafeArea(
                  child: Container(
                    height: 65,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          spreadRadius: 1,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(0, Icons.home_outlined, Icons.home_rounded),
                        _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded),
                        const SizedBox(width: 60),
                        _buildNavItem(
                          3,
                          Icons.bar_chart_outlined,
                          Icons.bar_chart_rounded,
                        ),
                        _buildNavItem(
                          4,
                          Icons.person_outline_rounded,
                          Icons.person_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!hideAssistiveOverlays)
                Positioned(
                  left: _chatbotOffset!.dx,
                  top: _chatbotOffset!.dy,
                  child: GestureDetector(
                    onTap: _openChatbot,
                    onPanUpdate: (details) {
                      setState(() {
                        _chatbotOffset = _clampChatbotOffset(
                          _chatbotOffset! + details.delta,
                          constraints,
                        );
                      });
                    },
                    child: SizedBox(
                      width: _chatbotIconSize,
                      height: _chatbotIconSize,
                      child: Image.asset(
                        'lib/ui/ai_chat/robot.gif',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(
                              Icons.smart_toy_rounded,
                              color: Color(0xFF6D28D9),
                              size: 50,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (!hideAssistiveOverlays)
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: 1.1,
                      child: GestureDetector(
                        onTap: _toggleMenu,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            // THAY ĐỔI: Màu Gradient Galaxy cho nút dấu (+)
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6D28D9).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                          ),
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
                ),
            ],
          );
        },
      ),
    );
  }

  Offset _clampChatbotOffset(Offset value, BoxConstraints constraints) {
    final double minX = 0;
    final double maxX = (constraints.maxWidth - _chatbotIconSize).clamp(
      0,
      double.infinity,
    );
    final double minY = _chatbotMinTop;
    final double maxY =
    (constraints.maxHeight - _chatbotIconSize - _chatbotBottomReserve)
        .clamp(_chatbotMinTop, double.infinity);

    return Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));
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
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon) {
    final bool isSelected = _selectedIndex == index;
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
            // THAY ĐỔI: Màu Tím Galaxy khi tab được chọn
            color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF94A3B8),
            size: 28,
          ),
        ),
      ),
    );
  }
}