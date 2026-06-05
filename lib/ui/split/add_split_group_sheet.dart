import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../domain/model/split_member_info.dart';
import '../../services/split_service.dart';
import '../providers/auth_provider.dart';
import '../providers/split_provider.dart';

class AddSplitGroupSheet extends StatefulWidget {
  const AddSplitGroupSheet({super.key});

  @override
  State<AddSplitGroupSheet> createState() => _AddSplitGroupSheetState();
}

class _AddSplitGroupSheetState extends State<AddSplitGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  final List<SplitMemberInfo> _addedMembers = [];
  SplitMemberInfo? _foundMember;
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchUser(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      setState(() {
        _foundMember = null;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _foundMember = null;
    });

    try {
      final user = await SplitService.instance.findUserByEmail(cleanEmail);
      setState(() {
        _isSearching = false;
        if (user != null) {
          _foundMember = user;
        } else {
          _searchError = 'Không tìm thấy tài khoản với email này.';
        }
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchError = 'Lỗi tìm kiếm: $e';
      });
    }
  }

  void _addMember(SplitMemberInfo member) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.uid ?? '';
    
    if (member.uid == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã là trưởng nhóm rồi!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_addedMembers.any((m) => m.uid == member.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thành viên này đã được thêm.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _addedMembers.add(member);
      _foundMember = null;
      _emailController.clear();
    });
  }

  void _removeMember(int index) {
    setState(() {
      _addedMembers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final groupName = _nameController.text.trim();
    final groupDesc = _descriptionController.text.trim();
    final splitProvider = context.read<SplitProvider>();

    try {
      // 1. Tạo nhóm
      await splitProvider.createGroup(groupName, groupDesc);
      
      // Đợi nhóm được tạo xong và lấy ID nhóm vừa tạo (nhóm mới nhất trong list)
      // Chờ stream update
      await Future.delayed(const Duration(milliseconds: 600));
      
      if (splitProvider.myGroups.isNotEmpty) {
        final newGroupId = splitProvider.myGroups.first.id;
        
        // 2. Thêm các thành viên bằng email
        for (final member in _addedMembers) {
          await splitProvider.addMemberByEmail(newGroupId, member.email);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo nhóm và mời thành viên thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tạo nhóm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserName = authProvider.currentUser?.displayName ?? 'Tôi';
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tạo nhóm chia tiền mới',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              // Group Name Input
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Tên nhóm (ví dụ: Đi Đà Lạt, Ăn uống cuối tuần)',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  floatingLabelStyle: const TextStyle(color: Color(0xFF6D28D9)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                  ),
                  prefixIcon: const Icon(LucideIcons.tag, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên nhóm';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Group Description Input
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Mô tả nhóm (không bắt buộc)',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  floatingLabelStyle: const TextStyle(color: Color(0xFF6D28D9)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                  ),
                  prefixIcon: const Icon(LucideIcons.fileText, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Mời thành viên (bằng email đăng ký app)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),
              // Email Search Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Nhập email thành viên...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                        ),
                        prefixIcon: const Icon(LucideIcons.mail, color: Color(0xFF94A3B8), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FE),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (val) {
                        if (val.contains('@')) {
                          _searchUser(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _searchUser(_emailController.text),
                    icon: const Icon(LucideIcons.search, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search Status / Found User Display
              if (_isSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_searchError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _searchError!,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                )
              else if (_foundMember != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF86EFAC),
                        backgroundImage: _foundMember!.photoUrl.isNotEmpty ? NetworkImage(_foundMember!.photoUrl) : null,
                        child: _foundMember!.photoUrl.isEmpty
                            ? const Icon(LucideIcons.user, color: Color(0xFF166534), size: 18)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _foundMember!.displayName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                            ),
                            Text(
                              _foundMember!.email,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _addMember(_foundMember!),
                        icon: const Icon(LucideIcons.plus, size: 14),
                        label: const Text('Thêm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF166534),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Default Creator display (cannot edit)
              const Text(
                'Danh sách thành viên hiện tại:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD0E0FF)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.userCheck, color: Color(0xFF1D4ED8), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$currentUserName (Trưởng nhóm - Bạn)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Added members list
              ...List.generate(_addedMembers.length, (index) {
                final member = _addedMembers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFCBD5E1),
                        backgroundImage: member.photoUrl.isNotEmpty ? NetworkImage(member.photoUrl) : null,
                        child: member.photoUrl.isEmpty
                            ? const Icon(LucideIcons.user, color: Color(0xFF475569), size: 14)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.displayName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              member.email,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeMember(index),
                        icon: const Icon(LucideIcons.x, color: Color(0xFFEF4444), size: 16),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE2E2),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D28D9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: const Text(
                  'Tạo nhóm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
