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

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _countdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
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
      if (mounted) {
        setState(() => _countdown--);
      }
    }
    if (mounted) {
      setState(() => _canResend = true);
    }
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otpCode.length < 6) {
      _showSnack('Nhập đủ 6 số!', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await OtpService.verifyOTP(widget.email, _otpCode);
      await AuthService.registerAfterOTP(widget.email, widget.password);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
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
      _showSnack('Đã gửi lại mã OTP!', Colors.green);
    } catch (e) {
      _showSnack('Gửi lại thất bại!', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
          leading: const BackButton(color: Colors.black)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.email_outlined,
                    size: 40, color: Color(0xFF1a237e)),
              ),
              const SizedBox(height: 24),
              const Text('Nhập mã xác minh',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Mã OTP đã được gửi đến\n${widget.email}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
              const SizedBox(height: 36),
  
              // 6 ô OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _buildBox(i)),
              ),
              const SizedBox(height: 20),
  
              // Đếm ngược / Gửi lại
              Center(
                child: _canResend
                    ? TextButton.icon(
                        onPressed: _isLoading ? null : _resend,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Gửi lại mã'),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1a237e)),
                      )
                    : Text('Gửi lại sau $_countdown giây',
                        style: const TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 32),
  
              // Nút xác minh
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a237e),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Xác minh',
                          style: TextStyle(fontSize: 17, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBox(int i) {
    return SizedBox(
      width: 48, height: 58,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1a237e), width: 2)),
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
}
