import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../domain/model/transaction_model.dart';
import '../../domain/services/ocr_service.dart';
import '../../services/login_tutorial_service.dart';
import '../../services/receipt_image_service.dart';
import '../../ui/ai_chat/chatbot.dart';
import '../../ui/home/home_screen.dart';
import '../../ui/home/voice_assistant.dart';
import '../../ui/providers/auth_provider.dart';
import '../../ui/settings/profile_screen.dart';
import '../../ui/stats/stats_screen.dart';
import '../../ui/transaction/create_transaction_page.dart';
import '../../ui/transaction/transaction_list_page.dart';
import '../../ui/split/split_group_list_screen.dart';

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

enum _TutorialTarget {
  homeTab,
  transactionsTab,
  addButton,
  quickActions,
  statsTab,
  profileTab,
}

class _TutorialStepData {
  const _TutorialStepData({
    required this.target,
    required this.title,
    required this.description,
  });

  final _TutorialTarget target;
  final String title;
  final String description;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();

  static MainScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainScreenState>();
  }
}

class MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  static const double _chatbotIconSize = 78;
  static const double _chatbotMinTop = 80;
  static const double _chatbotBottomReserve = 120;
  static const List<_TutorialStepData> _tutorialSteps = [
    _TutorialStepData(
      target: _TutorialTarget.homeTab,
      title: 'Trang tổng quan',
      description:
          'Đây là tab Trang chủ. Bạn có thể xem số dư, tổng thu chi và các mục quan trọng ngay tại đây.',
    ),
    _TutorialStepData(
      target: _TutorialTarget.transactionsTab,
      title: 'Lịch sử giao dịch',
      description:
          'Tab này giúp bạn xem và tìm lại toàn bộ giao dịch đã ghi trong ứng dụng.',
    ),
    _TutorialStepData(
      target: _TutorialTarget.addButton,
      title: 'Nút thêm nhanh',
      description:
          'Nút cộng ở giữa là lối vào nhanh để thêm giao dịch mới bất cứ lúc nào.',
    ),
    _TutorialStepData(
      target: _TutorialTarget.quickActions,
      title: 'Tác vụ nhanh',
      description:
          'Từ đây bạn có thể quét hóa đơn, ghi bằng giọng nói hoặc nhập giao dịch thủ công.',
    ),
    _TutorialStepData(
      target: _TutorialTarget.statsTab,
      title: 'Thống kê',
      description:
          'Mở tab Thống kê để xem biểu đồ, xu hướng chi tiêu và đánh giá tình hình tài chính.',
    ),
    _TutorialStepData(
      target: _TutorialTarget.profileTab,
      title: 'Tài khoản và cài đặt',
      description:
          'Tab cuối cùng dùng để xem thông tin tài khoản, đồng bộ, thông báo và đăng xuất.',
    ),
  ];

  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  bool _hideOverlaysForRoute = false;
  bool _isNestedRouteActive = false;
  bool _isNavBarVisible = true;
  bool _isTutorialActive = false;
  int _tutorialStepIndex = 0;
  bool _hasCheckedTutorial = false;
  String? _tutorialUserId;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  Offset? _chatbotOffset;
  late final List<_TabRouteObserver> _tabRouteObservers;
  final GlobalKey _homeTabKey = GlobalKey();
  final GlobalKey _transactionsTabKey = GlobalKey();
  final GlobalKey _statsTabKey = GlobalKey();
  final GlobalKey _profileTabKey = GlobalKey();
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _quickActionsKey = GlobalKey();

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
      _checkAndStartTutorial();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    _setMenuOpen(!_isMenuOpen);
  }

  void _setMenuOpen(bool value) {
    if (_isMenuOpen == value) return;
    if (value) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    setState(() => _isMenuOpen = value);
  }

  Future<void> _checkAndStartTutorial() async {
    if (_hasCheckedTutorial) return;
    _hasCheckedTutorial = true;

    final userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) {
      return;
    }

    _tutorialUserId = userId;
    final shouldShow = await LoginTutorialService.shouldShowForUser(userId);
    if (!mounted || !shouldShow) return;

    _startTutorial();
  }

  void _startTutorial() {
    if (!mounted) return;
    setState(() {
      _isTutorialActive = true;
      _tutorialStepIndex = 0;
      _selectedIndex = 0;
      _isNavBarVisible = true;
    });
    _syncTutorialStepUi();
  }

  Future<void> _completeTutorial() async {
    final userId =
        _tutorialUserId ?? context.read<AuthProvider>().currentUser?.uid;
    if (userId != null) {
      await LoginTutorialService.markSeenForUser(userId);
    }
    if (!mounted) return;

    if (_isMenuOpen) {
      _animationController.reverse();
    }

    setState(() {
      _isTutorialActive = false;
      _tutorialStepIndex = 0;
      _selectedIndex = 0;
      _isMenuOpen = false;
      _isNavBarVisible = true;
    });
  }

  void _nextTutorialStep() {
    if (_tutorialStepIndex >= _tutorialSteps.length - 1) {
      _completeTutorial();
      return;
    }

    setState(() {
      _tutorialStepIndex += 1;
    });
    _syncTutorialStepUi();
  }

  void _previousTutorialStep() {
    if (_tutorialStepIndex == 0) return;
    setState(() {
      _tutorialStepIndex -= 1;
    });
    _syncTutorialStepUi();
  }

  void _syncTutorialStepUi() {
    if (!_isTutorialActive || !mounted) return;

    final currentStep = _tutorialSteps[_tutorialStepIndex];
    int nextIndex = _selectedIndex;
    bool shouldOpenMenu = false;

    switch (currentStep.target) {
      case _TutorialTarget.homeTab:
        nextIndex = 0;
        break;
      case _TutorialTarget.transactionsTab:
        nextIndex = 1;
        break;
      case _TutorialTarget.addButton:
        break;
      case _TutorialTarget.quickActions:
        shouldOpenMenu = true;
        break;
      case _TutorialTarget.statsTab:
        nextIndex = 3;
        break;
      case _TutorialTarget.profileTab:
        nextIndex = 4;
        break;
    }

    if (!mounted) return;
    setState(() {
      _selectedIndex = nextIndex;
      _isNavBarVisible = true;
    });
    _setMenuOpen(shouldOpenMenu);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNestedRouteState();
    });
  }

  void setSelectedIndex(int index) {
    if (index < 0 || index >= 5 || index == 2) return;
    _onItemTapped(index);
  }

  void _onItemTapped(int index) {
    if (_isTutorialActive) return;
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

      // THAY ĐỔI: Khi quay lại trang gốc của tab, đảm bảo thanh điều hướng hiện lên
      // (Bù đắp cho việc thanh bị ẩn do listener cuộn trước đó)
      if (!shouldHide && !_isNavBarVisible) {
        setState(() => _isNavBarVisible = true);
      }

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

  Future<void> _handleInvoiceScan() async {
    final image = await ReceiptImageService.instance.pickReceiptImage(context);

    if (image != null) {
      if (!mounted) return;
      _toggleMenu();

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
  }

  GlobalKey _keyForTutorialTarget(_TutorialTarget target) {
    switch (target) {
      case _TutorialTarget.homeTab:
        return _homeTabKey;
      case _TutorialTarget.transactionsTab:
        return _transactionsTabKey;
      case _TutorialTarget.addButton:
        return _addButtonKey;
      case _TutorialTarget.quickActions:
        return _quickActionsKey;
      case _TutorialTarget.statsTab:
        return _statsTabKey;
      case _TutorialTarget.profileTab:
        return _profileTabKey;
    }
  }

  Rect? _getRectForKey(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) return null;

    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  Widget _buildTutorialOverlay(BoxConstraints constraints) {
    final step = _tutorialSteps[_tutorialStepIndex];
    final rect = _getRectForKey(_keyForTutorialTarget(step.target));
    final bool placeCardAbove =
        rect != null && rect.center.dy > (constraints.maxHeight * 0.58);
    final double cardTop = rect == null
        ? constraints.maxHeight * 0.18
        : (placeCardAbove ? rect.top - 196 : rect.bottom + 20)
              .clamp(32.0, constraints.maxHeight - 212)
              .toDouble();

    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.72)),
        ),
        if (rect != null)
          Positioned(
            left: (rect.left - 10)
                .clamp(12.0, constraints.maxWidth - 24)
                .toDouble(),
            top: (rect.top - 10)
                .clamp(12.0, constraints.maxHeight - 24)
                .toDouble(),
            child: IgnorePointer(
              child: Container(
                width: (rect.width + 20)
                    .clamp(44.0, constraints.maxWidth - 24)
                    .toDouble(),
                height: (rect.height + 20)
                    .clamp(44.0, constraints.maxHeight - 24)
                    .toDouble(),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          top: cardTop,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bước ${_tutorialStepIndex + 1}/${_tutorialSteps.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    step.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _completeTutorial,
                        child: const Text('Bỏ qua'),
                      ),
                      const Spacer(),
                      if (_tutorialStepIndex > 0)
                        OutlinedButton(
                          onPressed: _previousTutorialStep,
                          child: const Text('Trước'),
                        ),
                      if (_tutorialStepIndex > 0) const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _nextTutorialStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _tutorialStepIndex == _tutorialSteps.length - 1
                              ? 'Hoàn tất'
                              : 'Tiếp',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool hideAssistiveOverlays =
        isKeyboardVisible || _hideOverlaysForRoute;

    // Tính toán vị trí bottom cho các thành phần để có thể animate mượt mà
    // Thay vì dùng IF - kiến trúc này giúp widget không bị remove khỏi tree đột ngột
    final double navBarBottom =
        (hideAssistiveOverlays || _isNestedRouteActive || !_isNavBarVisible)
        ? -100
        : 30;
    final double addButtonBottom =
        (hideAssistiveOverlays || _isNestedRouteActive || !_isNavBarVisible)
        ? -100
        : 50;
    final double menuBottom =
        (hideAssistiveOverlays || _isNestedRouteActive || !_isNavBarVisible)
        ? -100
        : (_isMenuOpen ? 130 : 50);
    final double chatbotOpacity =
        (hideAssistiveOverlays || _isNestedRouteActive || _selectedIndex != 0) ? 0.0 : 1.0;

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
                    } else if (notification.direction ==
                        ScrollDirection.forward) {
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
              // Dim background when menu open
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isMenuOpen ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isMenuOpen,
                  child: GestureDetector(
                    onTap: _toggleMenu,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),

              // Quick action menu buttons
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                bottom: menuBottom,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_isMenuOpen,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isMenuOpen ? 1.0 : 0.0,
                    child: Row(
                      key: _quickActionsKey,
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
                        const SizedBox(width: 24),
                        _buildIconOption(
                          icon: Icons.group,
                          bgColor: Colors.purple.shade50,
                          iconColor: Colors.purple,
                          onTap: () {
                            _toggleMenu();
                            _pushInCurrentTab(const SplitGroupListScreen());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Navigation Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: navBarBottom,
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
                          tutorialKey: _homeTabKey,
                        ),
                        _buildNavItem(
                          1,
                          Icons.receipt_long_outlined,
                          Icons.receipt_long_rounded,
                          tutorialKey: _transactionsTabKey,
                        ),
                        const SizedBox(width: 60),
                        _buildNavItem(
                          3,
                          Icons.bar_chart_outlined,
                          Icons.bar_chart_rounded,
                          tutorialKey: _statsTabKey,
                        ),
                        _buildNavItem(
                          4,
                          Icons.person_outline_rounded,
                          Icons.person_rounded,
                          tutorialKey: _profileTabKey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Chatbot Robot
              Positioned(
                left: _chatbotOffset!.dx,
                top: _chatbotOffset!.dy,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: chatbotOpacity,
                  child: IgnorePointer(
                    ignoring: chatbotOpacity < 0.5,
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
                ),
              ),

              // Main Add Button (+)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: addButtonBottom,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: 1.1,
                    child: GestureDetector(
                      key: _addButtonKey,
                      onTap: _toggleMenu,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
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
              if (_isTutorialActive) _buildTutorialOverlay(constraints),
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

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon, {
    Key? tutorialKey,
  }) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      key: tutorialKey,
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
