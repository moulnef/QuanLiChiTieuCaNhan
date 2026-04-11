import 'package:flutter/material.dart';
import '../../core/config/otp_service.dart';
import '../../core/config/auth_service.dart';
import '../home/main_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String password;
  const OtpScreen({required this.email, required this.password, super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _countdown = 60;
  bool _canResend = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _startCountdown();
  }

  void _startCountdown() {
    if (!mounted) return;
    setState(() { _canResend = false; _countdown = 60; });
    _runTimer();
  }

  void _runTimer() async {
    while (_countdown > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _countdown--);
    }
    if (mounted) setState(() => _canResend = true);
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otpCode.length < 6) {
      _showSnack('Vui lòng nhập đủ 6 số', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await OtpService.verifyOTP(widget.email, _otpCode);
      await AuthService.registerAfterOTP(widget.email, widget.password);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isLoading = true);
    try {
      await OtpService.sendOTP(widget.email);
      _startCountdown();
      _showSnack('Đã gửi lại mã OTP', Colors.green);
    } catch (e) {
      _showSnack('Gửi lại thất bại', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    for (var c in _controllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
    super.dispose();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Step indicator
                Row(
                  children: [
                    _stepDot(done: true, label: "1"),
                    _stepLine(),
                    _stepDot(active: true, done: false, label: "2"),
                    _stepLine(),
                    _stepDot(done: false, label: "3"),
                  ],
                ),
                const SizedBox(height: 32),

                // Icon Gradient
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, size: 28, color: Colors.white),
                ),
                const SizedBox(height: 24),

                const Text(
                  "Xác minh email",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.6),
                    children: [
                      const TextSpan(text: "Mã OTP đã được gửi đến\n"),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // OTP boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _buildOtpBox(i)),
                ),
                const SizedBox(height: 28),

                // Resend
                Center(
                  child: _canResend
                      ? GestureDetector(
                    onTap: _isLoading ? null : _resend,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF6D28D9)),
                          SizedBox(width: 6),
                          Text(
                            "Gửi lại mã",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Gửi lại sau ", style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                      Text(
                        "$_countdown giây",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Verify button
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
                    onPressed: _isLoading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Text(
                      "XÁC MINH",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int i) {
    return Container(
      width: 50,
      height: 58,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
          if (val.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
          if (val.isNotEmpty && i == 5) {
            FocusScope.of(context).unfocus();
            _verify();
          }
        },
      ),
    );
  }

  Widget _stepDot({required bool done, bool active = false, required String label}) {
    Color bg = done
        ? const Color(0xFF10B981)
        : active
        ? const Color(0xFF1D4ED8)
        : Colors.white;
    Color border = done
        ? const Color(0xFF10B981)
        : active
        ? const Color(0xFF1D4ED8)
        : const Color(0xFFE2E8F0);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: border)),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: active ? Colors.white : const Color(0xFF94A3B8))),
      ),
    );
  }

  Widget _stepLine() {
    return Expanded(child: Container(height: 2, color: const Color(0xFFE2E8F0)));
  }
}