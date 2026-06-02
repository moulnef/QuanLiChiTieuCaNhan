import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/model/transaction_model.dart';
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
  final NavigatorObserver? navigatorObserver;

  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.rootPage,
    this.navigatorObserver,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      observers: navigatorObserver == null
          ? const <NavigatorObserver>[]
          : <NavigatorObserver>[navigatorObserver!],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) => rootPage);
      },
    );
  }
}

class _TabRouteObserver extends NavigatorObserver {
  _TabRouteObserver({required this.onChanged});

  final VoidCallback onChanged;

  void _notifyChanged() => onChanged();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _notifyChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _notifyChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _notifyChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _notifyChanged();
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
  bool _hideOverlaysForRoute = false;
  bool _isNestedRouteActive = false;
  bool _isNavBarVisible = true;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  Offset? _chatbotOffset;
  late final List<_TabRouteObserver> _tabRouteObservers;

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
    _tabRouteObservers = List<_TabRouteObserver>.generate(
      _navigatorKeys.length,
      (_) => _TabRouteObserver(onChanged: _updateNestedRouteState),
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNestedRouteState();
    });
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

    if (_selectedIndex == index) {
      final currentNav = _navigatorKeys[index].currentState;
      currentNav?.popUntil((route) => route.isFirst);
      if (index == 0) {
        HomePageState.scrollToTopActive();
      }
      setState(() {
        _isNavBarVisible = true;
      });
      return;
    }

    if (_isMenuOpen) _toggleMenu();
    setState(() {
      _selectedIndex = index;
      _isNavBarVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNestedRouteState();
    });
  }

  void _updateNestedRouteState() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentNav = _navigatorKeys[_selectedIndex].currentState;
      final bool shouldHide = currentNav?.canPop() ?? false;
      if (_isNestedRouteActive == shouldHide) return;
      setState(() => _isNestedRouteActive = shouldHide);
    });
  }

  Future<void> _pushInCurrentTab(
    Widget page, {
    bool hideOverlaysWhilePushed = false,
  }) async {
    if (_isMenuOpen) {
      _toggleMenu();
    }

    if (hideOverlaysWhilePushed && mounted) {
      setState(() => _hideOverlaysForRoute = true);
    }

    try {
      final currentNav = _navigatorKeys[_selectedIndex].currentState;
      if (currentNav != null) {
        await currentNav.push(MaterialPageRoute(builder: (_) => page));
        return;
      }

      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } finally {
      if (hideOverlaysWhilePushed && mounted) {
        setState(() => _hideOverlaysForRoute = false);
      }
    }
  }

  Future<void> _openCreateTransactionPage({TransactionModel? editData}) {
    return _pushInCurrentTab(
      CreateTransactionPage(editData: editData),
      hideOverlaysWhilePushed: true,
    );
  }

  void _openChatbot() {
    _pushInCurrentTab(const ChatbotScreen());
  }

  Future<ImageSource?> _showSourceSelectionSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Chọn nguồn quét hóa đơn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                  title: const Text(
                    'Chụp ảnh mới bằng Camera',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  subtitle: const Text('Dùng camera chụp trực tiếp hóa đơn'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  title: const Text(
                    'Chọn từ Thư viện ảnh',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  subtitle: const Text('Chọn ảnh hóa đơn có sẵn từ máy'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPermissionDeniedSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showPermanentlyDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Quyền $permissionName bị từ chối'),
        content: Text(
          'Bạn đã từ chối quyền truy cập $permissionName vĩnh viễn. Vui lòng mở Cài đặt thiết bị để cấp quyền này cho ứng dụng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D28D9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInvoiceScan() async {
    if (_isMenuOpen) _toggleMenu();

    final ImageSource? source = await _showSourceSelectionSheet();
    if (source == null) return;

    if (source == ImageSource.camera) {
      final cameraStatus = await Permission.camera.status;
      if (cameraStatus.isDenied) {
        final requestResult = await Permission.camera.request();
        if (requestResult.isDenied) {
          _showPermissionDeniedSnackBar('Cần cấp quyền truy cập Camera để chụp ảnh hóa đơn.');
          return;
        } else if (requestResult.isPermanentlyDenied) {
          _showPermanentlyDeniedDialog('Camera');
          return;
        }
      } else if (cameraStatus.isPermanentlyDenied) {
        _showPermanentlyDeniedDialog('Camera');
        return;
      }
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
          ),
        );

        final result = await _ocrService.scanReceiptPath(image.path);

        if (!mounted) return;
        Navigator.pop(context);

        if (result != null && result['amount'] != null) {
          _openCreateTransactionPage(
            editData: TransactionModel(
              amount: (result['amount'] as num).toDouble(),
              categoryId: '',
              type: 'expense',
              transactionDate: DateTime.now(),
              note: 'Quét từ hóa đơn',
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Có lỗi xảy ra khi quét: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool hideAssistiveOverlays =
        isKeyboardVisible || _hideOverlaysForRoute || _isNestedRouteActive;

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
              NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0) {
                    if (notification.direction == ScrollDirection.reverse) {
                      if (_isNavBarVisible) {
                        setState(() {
                          _isNavBarVisible = false;
                          if (_isMenuOpen) {
                            _toggleMenu();
                          }
                        });
                      }
                    } else if (notification.direction == ScrollDirection.forward) {
                      if (!_isNavBarVisible) {
                        setState(() {
                          _isNavBarVisible = true;
                        });
                      }
                    }
                  }
                  return false;
                },
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    TabNavigator(
                      navigatorKey: _navigatorKeys[0],
                      rootPage: const HomePage(),
                      navigatorObserver: _tabRouteObservers[0],
                    ),
                    TabNavigator(
                      navigatorKey: _navigatorKeys[1],
                      rootPage: const TransactionListPage(),
                      navigatorObserver: _tabRouteObservers[1],
                    ),
                    const SizedBox.shrink(),
                    TabNavigator(
                      navigatorKey: _navigatorKeys[3],
                      rootPage: const StatsPage(),
                      navigatorObserver: _tabRouteObservers[3],
                    ),
                    TabNavigator(
                      navigatorKey: _navigatorKeys[4],
                      rootPage: const ProfilePage(),
                      navigatorObserver: _tabRouteObservers[4],
                    ),
                  ],
                ),
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
                  bottom: _isNavBarVisible ? (_isMenuOpen ? 130 : 50) : -100,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_isMenuOpen,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isMenuOpen && _isNavBarVisible ? 1.0 : 0.0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          _buildIconOption(
                            icon: Icons.camera_alt_rounded,
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
                              _toggleMenu();
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
                              _openCreateTransactionPage();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!hideAssistiveOverlays)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  bottom: _isNavBarVisible ? 30 : -100,
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
                          _buildNavItem(
                            0,
                            Icons.home_outlined,
                            Icons.home_rounded,
                          ),
                          _buildNavItem(
                            1,
                            Icons.receipt_long_outlined,
                            Icons.receipt_long_rounded,
                          ),
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
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
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
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  bottom: _isNavBarVisible ? 50 : -100,
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
                                color: const Color(
                                  0xFF6D28D9,
                                ).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
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
            color: isSelected
                ? const Color(0xFF6D28D9)
                : const Color(0xFF94A3B8),
            size: 28,
          ),
        ),
      ),
    );
  }
}
