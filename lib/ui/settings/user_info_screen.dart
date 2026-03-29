import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key});

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  final _user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user?.displayName ?? "");
    _emailController = TextEditingController(text: _user?.email ?? "");
    _phoneController = TextEditingController(text: "");
    _dobController = TextEditingController(text: "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A1A2E),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dobController.text = DateFormat('dd/MM/yyyy').format(picked));
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_nameController.text != _user?.displayName) {
        await _user?.updateDisplayName(_nameController.text);
      }
      if (_emailController.text != _user?.email && _emailController.text.isNotEmpty) {
        await _user?.updateEmail(_emailController.text);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Cập nhật thành công!"),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.displayName ?? "U";
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "U";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF1A1A2E)),
          ),
        ),
        title: const Text(
          "Thông tin cá nhân",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // Header avatar section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              color: const Color(0xFFF5F7FA),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A2E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user?.email ?? "",
                    style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),

            // Form
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(label: "Họ và tên", controller: _nameController,
                        icon: Icons.person_outline_rounded, hint: "Nhập họ và tên"),
                    const SizedBox(height: 16),
                    _buildField(label: "Email", controller: _emailController,
                        icon: Icons.email_outlined, hint: "example@gmail.com",
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _buildField(label: "Số điện thoại", controller: _phoneController,
                        icon: Icons.phone_outlined, hint: "Chưa cập nhật",
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildField(label: "Ngày sinh", controller: _dobController,
                        icon: Icons.calendar_today_outlined, hint: "dd/MM/yyyy",
                        readOnly: true, onTap: () => _selectDate(context)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    "Lưu thay đổi",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280), letterSpacing: 0.3),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1A1A2E), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}