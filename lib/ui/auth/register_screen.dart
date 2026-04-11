import 'package:flutter/material.dart';
import '../../core/config/otp_service.dart';
import 'otp_screen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Vui lòng nhập email";
    if (!RegExp(r'^[\w-\.]+@gmail\.com$').hasMatch(value)) return "Email phải đúng định dạng @gmail.com";
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Vui lòng nhập mật khẩu";
    if (value.length < 8) return "Mật khẩu tối thiểu 8 ký tự";
    if (!RegExp(r'^(?=.*[A-Z])(?=.*\d).+$').hasMatch(value)) return "Cần có chữ hoa và số";
    return null;
  }

  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      await OtpService.sendOTP(email);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(email: email, password: password)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Lỗi: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F5FF),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF1E293B)),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Step indicator
                  Row(
                    children: [
                      _stepDot(active: true, label: "1"),
                      _stepLine(),
                      _stepDot(active: false, label: "2"),
                      _stepLine(),
                      _stepDot(active: false, label: "3"),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    "Tạo tài khoản",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Thông tin của bạn được bảo mật tuyệt đối",
                    style: TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 36),

                  // Email
                  _buildLabel("Email"),
                  const SizedBox(height: 8),
                  _buildFormField(
                    controller: _emailController,
                    hint: "your@gmail.com",
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 20),

                  // Password
                  _buildLabel("Mật khẩu"),
                  const SizedBox(height: 8),
                  _buildFormField(
                    controller: _passwordController,
                    hint: "Tối thiểu 8 ký tự, có chữ hoa và số",
                    isPassword: true,
                    obscure: _obscurePassword,
                    toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 20),

                  // Confirm password
                  _buildLabel("Xác nhận mật khẩu"),
                  const SizedBox(height: 8),
                  _buildFormField(
                    controller: _confirmPasswordController,
                    hint: "Nhập lại mật khẩu",
                    isPassword: true,
                    obscure: _obscureConfirm,
                    toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (val) => val != _passwordController.text ? "Mật khẩu không khớp" : null,
                  ),

                  // Password hint
                  const SizedBox(height: 16),
                  _buildPasswordHints(),

                  const SizedBox(height: 36),

                  // Submit button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isLoading
                            ? [const Color(0xFF94A3B8), const Color(0xFF94A3B8)]
                            : [const Color(0xFF1D4ED8), const Color(0xFF6D28D9)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isLoading ? [] : [
                        BoxShadow(
                          color: const Color(0xFF6D28D9).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        "GỬI MÃ OTP",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155), letterSpacing: 0.3),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: const Color(0xFF94A3B8),
              size: 20,
            ),
            onPressed: toggleObscure,
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildPasswordHints() {
    final password = _passwordController.text;
    return ValueListenableBuilder(
      valueListenable: _passwordController,
      builder: (_, __, ___) {
        return Row(
          children: [
            _hintChip("8+ ký tự", password.length >= 8),
            const SizedBox(width: 8),
            _hintChip("Chữ hoa", password.contains(RegExp(r'[A-Z]'))),
            const SizedBox(width: 8),
            _hintChip("Có số", password.contains(RegExp(r'\d'))),
          ],
        );
      },
    );
  }

  Widget _hintChip(String label, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: met ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: met ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(met ? Icons.check_circle_outline : Icons.radio_button_unchecked,
              size: 14, color: met ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: met ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepDot({required bool active, required String label}) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1D4ED8) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _stepLine() {
    return Expanded(
      child: Container(height: 2, color: const Color(0xFFE2E8F0)),
    );
  }
}