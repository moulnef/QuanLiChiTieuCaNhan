import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../domain/model/settings_model.dart';
import 'user_info_screen.dart';
import 'change_password_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? user = FirebaseAuth.instance.currentUser;
  final settings = AppSettings();

  void _onUserInfoTap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserInfoPage()),
    );
    if (result == true) {
      setState(() {
        user = FirebaseAuth.instance.currentUser;
      });
    }
  }

  void _onChangePasswordTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildStatCards(),
            const SizedBox(height: 24),
            _buildActionSection(
              title: "Tài khoản",
              items: [
                _buildActionItem(Icons.person_outline, "Thông tin cá nhân", "Cập nhật họ tên, email", Colors.blue, _onUserInfoTap),
                _buildActionItem(Icons.lock_outline, "Đổi mật khẩu", "Cập nhật mật khẩu bảo mật", Colors.purple, _onChangePasswordTap),
                _buildActionItem(Icons.language, "Ngôn ngữ", settings.language, Colors.green, () {}),
              ],
            ),
            const SizedBox(height: 16),
            _buildActionSection(
              title: "Thông báo",
              items: [
                _buildSwitchItem(Icons.notifications_none_outlined, "Nhắc nhở thanh toán", "Nhận thông báo trước 3 ngày", Colors.orange, settings.isNotifyEnabled, (val) {
                  setState(() => settings.isNotifyEnabled = val);
                }),
              ],
            ),
            const SizedBox(height: 16),
            _buildActionSection(
              title: "Dữ liệu",
              items: [
                _buildSwitchItem(Icons.cloud_outlined, "Đồng bộ đám mây", "Lần cuối: vừa xong", Colors.cyan, settings.isSyncEnabled, (val) {
                  setState(() => settings.isSyncEnabled = val);
                }),
                _buildActionItem(Icons.backup_outlined, "Sao lưu dữ liệu", "Sao lưu / Khôi phục", Colors.indigo, () {}),
              ],
            ),
            const SizedBox(height: 24),
            _buildLogoutButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String displayName = user?.displayName ?? "Người dùng";
    String email = user?.email ?? "Chưa cập nhật email";
    String initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "U";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24, right: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2144E1), Color(0xFF192FA5)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              initial,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  email,
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                      SizedBox(width: 4),
                      Text(
                        "Tài khoản đã xác minh",
                        style: TextStyle(fontSize: 12, color: Colors.greenAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    String joinedDate = "Chưa rõ";
    if (user?.metadata.creationTime != null) {
      joinedDate = DateFormat('MM/yyyy').format(user!.metadata.creationTime!);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statItem("0", "Giao dịch"),
          const SizedBox(width: 12),
          _statItem("0đ", "Tiết kiệm"),
          const SizedBox(width: 12),
          _statItem(joinedDate, "Ngày tham gia"),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A4BD9).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String title, String subtitle, Color iconColor, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, String subtitle, Color iconColor, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () => FirebaseAuth.instance.signOut(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: Colors.red,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout),
            SizedBox(width: 8),
            Text("Đăng xuất", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
