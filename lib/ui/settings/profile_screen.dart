import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'user_info_screen.dart';
import 'change_password_screen.dart';
import 'app_feedback_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/app_localizer.dart';
import '../../utils/currency_formatter.dart';
import '../providers/sync_provider.dart';
import '../../services/sync_service.dart';
import '../../services/notification_service.dart';
import '../providers/notification_provider.dart';
import 'backup_restore_screen.dart';

import '../../modules/admin/admin_dashboard.dart';
import '../providers/auth_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _demoUserId = 'user_001';
  static const double _profileBottomReserve = 144;
  fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
  final FinanceRepository _repository = FinanceRepository();

  bool _isNotifyEnabled = true;

  String _displayName = 'Người dùng';
  String _email = 'Chưa cập nhật';
  double _walletBalance = 0;
  int _transactionCount = 0;

  String get _currentUserId => user?.uid ?? _demoUserId;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      await _repository.ensureDefaultWalletsForUser(_currentUserId);
      await Future.delayed(const Duration(milliseconds: 100));

      final session = await _repository.getAuthSessionByUserId(_currentUserId);
      final totalWallet = await _repository.getTotalWalletBalance(
        _currentUserId,
      );
      final transactionCount = await _repository.getTransactionCountByUserId(
        _currentUserId,
      );

      final notifyEnabledPref = await NotificationService.instance
          .isNotificationEnabledForUser(_currentUserId);
      final hasOSPermission = await NotificationService.instance
          .checkPermission();

      if (!mounted) return;
      setState(() {
        _displayName = session?['displayName']?.toString().isNotEmpty == true
            ? session!['displayName'].toString()
            : (user?.displayName ?? 'Người dùng');
        _email = session?['email']?.toString().isNotEmpty == true
            ? session!['email'].toString()
            : (user?.email ?? 'Chưa cập nhật');
        _walletBalance = totalWallet;
        _transactionCount = transactionCount;
        _isNotifyEnabled = notifyEnabledPref && hasOSPermission;
      });
    } catch (_) {
      bool localNotify = false;
      try {
        final notifyEnabledPref = await NotificationService.instance
            .isNotificationEnabledForUser(_currentUserId);
        final hasOSPermission = await NotificationService.instance
            .checkPermission();
        localNotify = notifyEnabledPref && hasOSPermission;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _displayName = user?.displayName ?? 'Người dùng';
        _email = user?.email ?? 'Chưa cập nhật';
        _isNotifyEnabled = localNotify;
      });
    }
  }

  void _onUserInfoTap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserInfoPage()),
    );
    if (result == true) {
      setState(() => user = fb_auth.FirebaseAuth.instance.currentUser);
      _loadProfileData();
    }
  }

  void _onChangePasswordTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  void _onFeedbackTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AppFeedbackPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    // web layout bottom space
    final double dynamicBottomSpace = kIsWeb ? 24.0 : 140.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        color: const Color(0xFF6D28D9),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _buildStatRow(),
                  const SizedBox(height: 28),
                  _buildSectionTitle("Tài khoản".xtr(context)),
                  const SizedBox(height: 10),
                  _buildCard(
                    children: [
                      _buildItem(
                        icon: Icons.person_outline_rounded,
                        label: "Thông tin cá nhân".xtr(context),
                        subtitle: "Họ tên, ngày sinh".xtr(context),
                        color: const Color(0xFF1D4ED8),
                        onTap: _onUserInfoTap,
                      ),
                      _buildDivider(),
                      _buildItem(
                        icon: Icons.lock_outline_rounded,
                        label: "Đổi mật khẩu".xtr(context),
                        subtitle: "Cập nhật mật khẩu".xtr(context),
                        color: const Color(0xFF6D28D9),
                        onTap: _onChangePasswordTap,
                      ),
                      _buildDivider(),
                      _buildItem(
                        icon: Icons.rate_review_outlined,
                        label: 'Góp ý và đánh giá ứng dụng'.xtr(context),
                        subtitle: 'Gửi nhận xét và chấm điểm từ 1 đến 5 sao'
                            .xtr(context),
                        color: const Color(0xFFF59E0B),
                        onTap: _onFeedbackTap,
                      ),
                      _buildDivider(),
                      _buildLanguageItem(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Thông báo".xtr(context)),
                  const SizedBox(height: 10),
                  _buildCard(
                    children: [
                      _buildToggleItem(
                        icon: Icons.notifications_outlined,
                        label: "Nhắc nhở thanh toán".xtr(context),
                        subtitle: "Thông báo trước 3 ngày".xtr(context),
                        color: const Color(0xFFF59E0B),
                        value: _isNotifyEnabled,
                        onChanged: (val) async {
                          if (val) {
                            final hasPermission = await NotificationService
                                .instance
                                .checkPermission();
                            bool granted = hasPermission;
                            if (!hasPermission) {
                              granted = await NotificationService.instance
                                  .requestPermission();
                            }
                            if (granted) {
                              await NotificationService.instance
                                  .setNotificationEnabledForUser(
                                    _currentUserId,
                                    true,
                                  );
                              setState(() {
                                _isNotifyEnabled = true;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Đã bật thông báo thành công!'.xtr(
                                        context,
                                      ),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                context
                                    .read<NotificationProvider>()
                                    .checkNewNotifications(_currentUserId);
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Vui lòng bật quyền thông báo trong cài đặt thiết bị.'
                                          .xtr(context),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else {
                            await NotificationService.instance
                                .setNotificationEnabledForUser(
                                  _currentUserId,
                                  false,
                                );
                            setState(() {
                              _isNotifyEnabled = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã tắt thông báo.'.xtr(context),
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Dữ liệu".xtr(context)),
                  const SizedBox(height: 10),
                  _buildCard(
                    children: [
                      _buildSyncSection(),
                      _buildItem(
                        icon: Icons.backup_outlined,
                        label: "Sao lưu dữ liệu".xtr(context),
                        subtitle: "Sao lưu / Khôi phục".xtr(context),
                        color: const Color(0xFF6D28D9),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BackupRestoreScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (authProvider.isAdmin) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle("Quản trị".xtr(context)),
                    const SizedBox(height: 10),
                    _buildAdminEntry(),
                  ],
                  const SizedBox(height: 28),
                  _buildLogoutButton(),
                  SizedBox(height: dynamicBottomSpace),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem() {
    final isEnglish = context.locale.languageCode == 'en';
    final languageLabel = isEnglish ? 'English' : 'Tiếng Việt';

    return InkWell(
      onTap: () {
        if (isEnglish) {
          context.setLocale(const Locale('vi'));
        } else {
          context.setLocale(const Locale('en'));
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.language_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ngôn ngữ".xtr(context),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    languageLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEnglish ? '🇬🇧' : '🇻🇳',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final initial = _displayName.isNotEmpty
        ? _displayName[0].toUpperCase()
        : "U";

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 40,
            top: 30,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 64,
              bottom: 32,
              left: 24,
              right: 24,
            ),
            child: Row(
              children: [
                Consumer<SyncProvider>(
                  builder: (context, syncProvider, _) {
                    Color dotColor;
                    switch (syncProvider.status) {
                      case SyncStatus.syncing:
                        dotColor = const Color(0xFFF59E0B);
                        break;
                      case SyncStatus.success:
                        dotColor = const Color(0xFF10B981);
                        break;
                      case SyncStatus.error:
                      case SyncStatus.offline:
                        dotColor = const Color(0xFFEF4444);
                        break;
                      case SyncStatus.idle:
                      default:
                        dotColor = syncProvider.pendingCount > 0
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981);
                        break;
                    }

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF1D4ED8),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.55,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "Đã xác minh".xtr(context),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _onUserInfoTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    String joinedDate = "Chưa rõ";
    if (user?.metadata.creationTime != null) {
      joinedDate = DateFormat('MM/yyyy').format(user!.metadata.creationTime!);
    }
    return Row(
      children: [
        _statCard(
          "$_transactionCount",
          "Giao dịch".xtr(context),
          Icons.swap_horiz_rounded,
        ),
        const SizedBox(width: 12),
        _statCard(
          _formatMoney(_walletBalance),
          "Tổng ví".xtr(context),
          Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(width: 12),
        _statCard(
          joinedDate,
          "Tham gia".xtr(context),
          Icons.calendar_today_outlined,
        ),
      ],
    );
  }

  String _formatMoney(double amount) {
    return formatVND(amount);
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF6D28D9)),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value.isEmpty ? "--" : value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1D4ED8),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF6D28D9),
            activeTrackColor: const Color(0xFFD8B4FE),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 70),
      child: Divider(height: 1, color: Color(0xFFF1F5F9)),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => context.read<AuthProvider>().signOut(),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE4E6)),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              color: Color(0xFFEF4444),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              "Đăng xuất".xtr(context),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminEntry() {
    return Animate(
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 300)),
        SlideEffect(
          begin: Offset(0, 0.12),
          end: Offset.zero,
          curve: Curves.easeOut,
        ),
      ],
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF283593)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảng điều khiển quản trị'.xtr(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mở trang dashboard dành cho admin'.xtr(context),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncSection() {
    if (kIsWeb) return const SizedBox.shrink();

    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        Color iconColor;
        Widget trailingWidget;
        String statusText;

        switch (syncProvider.status) {
          case SyncStatus.syncing:
            iconColor = const Color(0xFFF59E0B); // Orange
            trailingWidget = const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
              ),
            );
            statusText = "Đang đồng bộ...".xtr(context);
            break;
          case SyncStatus.success:
            iconColor = const Color(0xFF10B981); // Green
            trailingWidget = const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF10B981),
              size: 20,
            );
            statusText = "Đã đồng bộ".xtr(context);
            break;
          case SyncStatus.error:
            iconColor = const Color(0xFFEF4444); // Red
            trailingWidget = const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 20,
            );
            statusText =
                "Đồng bộ thất bại: ".xtr(context) +
                (syncProvider.errorMessage ??
                    "Lỗi không xác định".xtr(context));
            break;
          case SyncStatus.offline:
            iconColor = const Color(0xFF94A3B8); // Grey
            trailingWidget = const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            );
            statusText = "Không có kết nối mạng".xtr(context);
            break;
          case SyncStatus.idle:
          default:
            if (syncProvider.pendingCount > 0) {
              iconColor = const Color(0xFFF59E0B); // Orange
              trailingWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${syncProvider.pendingCount}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706),
                  ),
                ),
              );
              statusText =
                  "${syncProvider.pendingCount} ${"bản ghi chờ đồng bộ".xtr(context)}";
            } else {
              iconColor = const Color(0xFF10B981); // Green
              trailingWidget = const Icon(
                Icons.cloud_done_outlined,
                color: Color(0xFF10B981),
                size: 20,
              );
              statusText = "Đã đồng bộ".xtr(context);
            }
            break;
        }

        final lastSyncTimeStr = syncProvider.lastSyncTime != null
            ? DateFormat('HH:mm dd/MM/yyyy').format(syncProvider.lastSyncTime!)
            : "Chưa đồng bộ lần nào".xtr(context);
        final subtitle =
            "${"Lần cuối: ".xtr(context)}$lastSyncTimeStr • ${"Tự động đồng bộ khi có kết nối".xtr(context)}";

        final showRetryButton = syncProvider.status == SyncStatus.error;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.cloud_outlined,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Đồng bộ đám mây".xtr(context),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            trailingWidget,
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showRetryButton)
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final result = await syncProvider.syncNow(
                            _currentUserId,
                          );
                          if (context.mounted && result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "${"Đã đồng bộ ".xtr(context)}${result.successCount} ${"bản ghi thành công!".xtr(context)}",
                                ),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            String cleanMsg = e.toString();
                            if (cleanMsg.contains(': ')) {
                              cleanMsg = cleanMsg.substring(
                                cleanMsg.indexOf(': ') + 2,
                              );
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Đồng bộ thất bại: ".xtr(context) + cleanMsg,
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text("Thử lại".xtr(context)),
                    ),
                ],
              ),
            ),
            _buildDivider(),
          ],
        );
      },
    );
  }
}
