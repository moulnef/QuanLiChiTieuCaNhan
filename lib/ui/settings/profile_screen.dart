import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../domain/model/settings_model.dart';
import 'user_info_screen.dart';
import 'change_password_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? user = FirebaseAuth.instance.currentUser;
  final settings = AppSettings();

  void _onUserInfoTap() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const UserInfoPage()));
    if (result == true) setState(() { user = FirebaseAuth.instance.currentUser; });
  }

  void _onChangePasswordTap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
  }

  void _onLanguageTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildLanguageSheet(),
    );
  }

  Widget _buildLanguageSheet() {
    final languages = [
      {'code': 'vi', 'label': 'Tiếng Việt', 'flag': '🇻🇳'},
      {'code': 'en', 'label': 'English', 'flag': '🇬🇧'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Chọn ngôn ngữ",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 4),
          const Text(
            "Select language",
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 20),
          ...languages.map((lang) {
            final isSelected = settings.language == lang['label'];
            return GestureDetector(
              onTap: () {
                setState(() => settings.language = lang['label']!);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1A1A2E) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1A1A2E) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        lang['label']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
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
                _buildCard(children: [
                  _buildItem(
                    icon: Icons.person_outline_rounded,
                    label: "Thông tin cá nhân",
                    subtitle: "Họ tên, ngày sinh",
                    color: const Color(0xFF4F7FFF),
                    onTap: _onUserInfoTap,
                  ),
                  _buildDivider(),
                  _buildItem(
                    icon: Icons.lock_outline_rounded,
                    label: "Đổi mật khẩu",
                    subtitle: "Cập nhật mật khẩu",
                    color: const Color(0xFF8B5CF6),
                    onTap: _onChangePasswordTap,
                  ),
                  _buildDivider(),
                  _buildLanguageItem(),
                ]),
                const SizedBox(height: 20),
                _buildSectionTitle("Thông báo"),
                const SizedBox(height: 10),
                _buildCard(children: [
                  _buildToggleItem(
                    icon: Icons.notifications_outlined,
                    label: "Nhắc nhở thanh toán",
                    subtitle: "Thông báo trước 3 ngày",
                    color: const Color(0xFFF59E0B),
                    value: settings.isNotifyEnabled,
                    onChanged: (val) => setState(() => settings.isNotifyEnabled = val),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionTitle("Dữ liệu"),
                const SizedBox(height: 10),
                _buildCard(children: [
                  _buildToggleItem(
                    icon: Icons.cloud_outlined,
                    label: "Đồng bộ đám mây",
                    subtitle: "Lần cuối: vừa xong",
                    color: const Color(0xFF06B6D4),
                    value: settings.isSyncEnabled,
                    onChanged: (val) => setState(() => settings.isSyncEnabled = val),
                  ),
                  _buildDivider(),
                  _buildItem(
                    icon: Icons.backup_outlined,
                    label: "Sao lưu dữ liệu",
                    subtitle: "Sao lưu / Khôi phục",
                    color: const Color(0xFF6366F1),
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 28),
                _buildLogoutButton(),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem() {
    final isEnglish = settings.language == 'English';

    return InkWell(
      onTap: () {
        // Logic chuyển đổi ngôn ngữ
        if (isEnglish) {
          context.setLocale(const Locale('vi'));
        } else {
          context.setLocale(const Locale('en'));
        }

        // Đóng màn hình hiện tại (Settings hoặc BottomSheet)
        Navigator.pop(context);
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
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.language_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Ngôn ngữ",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E)
                    ),
                  ),
                  Text(
                    settings.language,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEnglish ? '🇬🇧' : '🇻🇳',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final displayName = user?.displayName ?? "Người dùng";
    final email = user?.email ?? "Chưa cập nhật";
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "U";

    return Container(
      padding: const EdgeInsets.only(top: 64, bottom: 32, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 13, color: Color(0xFF10B981)),
                      SizedBox(width: 5),
                      Text("Đã xác minh",
                          style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w500)),
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
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
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
        _statCard("0", "Giao dịch", Icons.swap_horiz_rounded),
        const SizedBox(width: 12),
        _statCard("0đ", "Tiết kiệm", Icons.savings_outlined),
        const SizedBox(width: 12),
        _statCard(joinedDate, "Tham gia", Icons.calendar_today_outlined),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF4F7FFF)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 1),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
                  color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 20),
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
                color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4F7FFF),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 70),
      child: Divider(height: 1, color: Color(0xFFF3F4F6)),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => FirebaseAuth.instance.signOut(),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE4E6)),
          boxShadow: [
            BoxShadow(color: Colors.red.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text("Đăng xuất",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
          ],
        ),
      ),
    );
  }
}