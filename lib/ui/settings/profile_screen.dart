import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'user_info_screen.dart';
import 'change_password_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _demoUserId = 'user_001';
  static const double _profileBottomReserve = 144;
  User? user = FirebaseAuth.instance.currentUser;
  final FinanceRepository _repository = FinanceRepository();

  bool _isNotifyEnabled = true;
  bool _isSyncEnabled = true;
  String _language = 'Tiếng Việt';

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
      final totalWallet = await _repository.getTotalWalletBalance(_currentUserId);
      final transactionCount = await _repository.getTransactionCountByUserId(_currentUserId);

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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _displayName = user?.displayName ?? 'Người dùng';
        _email = user?.email ?? 'Chưa cập nhật';
      });
    }
  }

  void _onUserInfoTap() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const UserInfoPage()));
    if (result == true) {
      setState(() => user = FirebaseAuth.instance.currentUser);
      _loadProfileData();
    }
  }

  void _onChangePasswordTap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
  }

  @override
  Widget build(BuildContext context) {
    final double dynamicBottomSpace = MediaQuery.of(context).padding.bottom + _profileBottomReserve;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        color: const Color(0xFF6D28D9),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _buildStatRow(),
                  const SizedBox(height: 28),
                  _buildSectionTitle("Tài khoản"),
                  const SizedBox(height: 10),
                  _buildCard(
                    children: [
                      _buildItem(icon: Icons.person_outline_rounded, label: "Thông tin cá nhân", subtitle: "Họ tên, ngày sinh", color: const Color(0xFF1D4ED8), onTap: _onUserInfoTap),
                      _buildDivider(),
                      _buildItem(icon: Icons.lock_outline_rounded, label: "Đổi mật khẩu", subtitle: "Cập nhật mật khẩu", color: const Color(0xFF6D28D9), onTap: _onChangePasswordTap),
                      _buildDivider(),
                      _buildLanguageItem(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Thông báo"),
                  const SizedBox(height: 10),
                  _buildCard(
                    children: [
                      _buildToggleItem(
                        icon: Icons.notifications_outlined, label: "Nhắc nhở thanh toán", subtitle: "Thông báo trước 3 ngày", color: const Color(0xFFF59E0B),
                        value: _isNotifyEnabled,
                        onChanged: (val) => setState(() => _isNotifyEnabled = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Dữ liệu"),
                  const SizedBox(height: 10),
                  _buildCard(
                    children: [
                      _buildToggleItem(
                        icon: Icons.cloud_outlined, label: "Đồng bộ đám mây", subtitle: "Lần cuối: vừa xong", color: const Color(0xFF06B6D4),
                        value: _isSyncEnabled,
                        onChanged: (val) => setState(() => _isSyncEnabled = val),
                      ),
                      _buildDivider(),
                      _buildItem(icon: Icons.backup_outlined, label: "Sao lưu dữ liệu", subtitle: "Sao lưu / Khôi phục", color: const Color(0xFF6D28D9), onTap: () {}),
                    ],
                  ),
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
    final isEnglish = _language == 'English';

    return InkWell(
      onTap: () {
        if (isEnglish) {
          setState(() => _language = 'Tiếng Việt');
          context.setLocale(const Locale('vi'));
        } else {
          setState(() => _language = 'English');
          context.setLocale(const Locale('en'));
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.language_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ngôn ngữ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                  Text(_language, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isEnglish ? '🇬🇧' : '🇻🇳', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : "U";

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Thêm các vòng tròn trang trí giống trang chủ
          Positioned(
            right: -30, top: -20,
            child: Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
          ),
          Positioned(
            right: 40, top: 30,
            child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06))),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 64, bottom: 32, left: 24, right: 24),
            child: Row(
              children: [
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)),
                  child: Center(child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(_email, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 5),
                            Text("Đã xác minh", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _onUserInfoTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
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
        _statCard("$_transactionCount", "Giao dịch", Icons.swap_horiz_rounded),
        const SizedBox(width: 12),
        _statCard(_formatMoney(_walletBalance), "Tổng ví", Icons.account_balance_wallet_outlined),
        const SizedBox(width: 12),
        _statCard(joinedDate, "Tham gia", Icons.calendar_today_outlined),
      ],
    );
  }

  String _formatMoney(double amount) {
    try {
      final formatter = NumberFormat('#,###', 'vi_VN');
      final formatted = formatter.format(amount.round());
      return '${formatted}đ';
    } catch (_) {
      return '${amount.toStringAsFixed(0)}đ';
    }
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF6D28D9)),
            const SizedBox(height: 8),
            Text(value.isEmpty ? "--" : value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8), letterSpacing: 1));
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildItem({required IconData icon, required String label, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))), Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))] )),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({required IconData icon, required String label, required String subtitle, required Color color, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))), Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))])),
          Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF6D28D9), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(padding: EdgeInsets.only(left: 70), child: Divider(height: 1, color: Color(0xFFF1F5F9)));
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => FirebaseAuth.instance.signOut(),
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFE4E6)),
          boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text("Đăng xuất", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
          ],
        ),
      ),
    );
  }
}