import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/data/repository/finance_repository.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/utils/snackbar_utils.dart';
import 'package:ai_quan_ly_chi_tieu_ca_nhan/utils/app_localizer.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key});

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  static const String _demoUserId = 'user_001';
  final _user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final FinanceRepository _repository = FinanceRepository();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;

  bool _isLoading = false;
  String _photoUrl = '';

  String get _currentUserId => _user?.uid ?? _demoUserId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user?.displayName ?? "");
    _emailController = TextEditingController(text: _user?.email ?? "");
    _phoneController = TextEditingController(text: "");
    _dobController = TextEditingController(text: "");
    _photoUrl = _user?.photoURL ?? '';
    _loadProfileFromDatabase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileFromDatabase() async {
    try {
      final session = await _repository.getAuthSessionByUserId(_currentUserId);
      if (session == null || !mounted) return;

      setState(() {
        _nameController.text =
            (session['displayName']?.toString().isNotEmpty == true)
            ? session['displayName'].toString()
            : _nameController.text;
        _emailController.text =
            (session['email']?.toString().isNotEmpty == true)
            ? session['email'].toString()
            : _emailController.text;
        _phoneController.text = session['phone']?.toString() ?? '';

        final rawDob = session['dateOfBirth']?.toString() ?? '';
        final parsedDob = DateTime.tryParse(rawDob);
        _dobController.text = parsedDob == null
            ? rawDob
            : DateFormat('dd/MM/yyyy').format(parsedDob);
        _photoUrl = session['photoURL']?.toString() ?? session['photo_url']?.toString() ?? (_user?.photoURL ?? '');
      });
    } catch (_) {
    }
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
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
                Text(
                  'Chọn nguồn ảnh đại diện'.xtr(context),
                  style: const TextStyle(
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
                  title: Text(
                    'Chụp ảnh mới'.xtr(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
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
                  title: Text(
                    'Chọn từ thư viện'.xtr(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 150,
        maxHeight: 150,
        imageQuality: 65,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = 'data:image/png;base64,${base64Encode(bytes)}';
        setState(() {
          _photoUrl = base64Image;
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Lỗi chọn ảnh: $e');
      }
    }
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
      setState(
        () => _dobController.text = DateFormat('dd/MM/yyyy').format(picked),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_nameController.text != _user?.displayName) {
        await _user?.updateDisplayName(_nameController.text);
      }
      if (_emailController.text != _user?.email &&
          _emailController.text.isNotEmpty) {
        try {
          await _user?.updateEmail(_emailController.text);
        } catch (_) {
          // SQLite profile update is still saved even when Firebase requires re-auth.
        }
      }
      if (_photoUrl != _user?.photoURL && !_photoUrl.startsWith('data:') && _photoUrl.length <= 2048) {
        await _user?.updatePhotoURL(_photoUrl);
      }

      DateTime? parsedDob;
      if (_dobController.text.trim().isNotEmpty) {
        parsedDob = DateFormat(
          'dd/MM/yyyy',
        ).parseStrict(_dobController.text.trim());
      }

      await _repository.upsertAuthSession({
        'userId': _currentUserId,
        'token': 'local_profile_token',
        'lastLogin': DateTime.now().millisecondsSinceEpoch,
        'isLoggedIn': 1,
        'displayName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dateOfBirth': parsedDob?.toIso8601String() ?? '',
        'photoURL': _photoUrl,
        'photo_url': _photoUrl,
      });

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Cập nhật hồ sơ thành công'.xtr(context));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Lỗi cập nhật hồ sơ: '.xtr(context) + e.toString());
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
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        title: Text(
          "Thông tin cá nhân".xtr(context),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
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
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E).withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: _photoUrl.isNotEmpty
                                      ? (_photoUrl.startsWith('data:image') || !_photoUrl.startsWith('http')
                                          ? Image.memory(
                                              base64Decode(_photoUrl.split(',').last),
                                              fit: BoxFit.cover,
                                              width: 86,
                                              height: 86,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    fontSize: 36,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1A1A2E),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Image.network(
                                              _photoUrl,
                                              fit: BoxFit.cover,
                                              width: 86,
                                              height: 86,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    fontSize: 36,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1A1A2E),
                                                  ),
                                                ),
                                              ),
                                            ))
                                      : Center(
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
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user?.email ?? "",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
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
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildField(
                            label: "Họ và tên".xtr(context),
                            controller: _nameController,
                            icon: Icons.person_outline_rounded,
                            hint: "Nhập họ và tên".xtr(context),
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: "Email".xtr(context),
                            controller: _emailController,
                            icon: Icons.email_outlined,
                            hint: "example@gmail.com",
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: "Số điện thoại".xtr(context),
                            controller: _phoneController,
                            icon: Icons.phone_outlined,
                            hint: "Chưa cập nhật".xtr(context),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: "Ngày sinh".xtr(context),
                            controller: _dobController,
                            icon: Icons.calendar_today_outlined,
                            hint: "dd/MM/yyyy",
                            readOnly: true,
                            onTap: () => _selectDate(context),
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Lưu thay đổi".xtr(context),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A2E),
          ),
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
              borderSide: const BorderSide(
                color: Color(0xFF1A1A2E),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
