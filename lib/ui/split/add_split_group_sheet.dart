import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  final List<TextEditingController> _memberControllers = [];

  @override
  void initState() {
    super.initState();
    // Add two empty member fields by default
    _addMemberField();
    _addMemberField();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _memberControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addMemberField() {
    setState(() {
      _memberControllers.add(TextEditingController());
    });
  }

  void _removeMemberField(int index) {
    setState(() {
      _memberControllers[index].dispose();
      _memberControllers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final groupName = _nameController.text.trim();
    final memberNames = _memberControllers
        .map((c) => c.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    try {
      await context.read<SplitProvider>().addGroup(groupName, memberNames);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo nhóm chia tiền thành công!'),
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thành viên nhóm',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addMemberField,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Thêm người'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6D28D9),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Default User display (cannot edit)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
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
              // Dynamic Member inputs
              ...List.generate(_memberControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _memberControllers[index],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'Tên thành viên ${index + 1}',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            floatingLabelStyle: const TextStyle(color: Color(0xFF6D28D9)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                            ),
                            prefixIcon: const Icon(LucideIcons.user, color: Color(0xFF94A3B8), size: 18),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FE),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            if (index == 0 && (value == null || value.trim().isEmpty) && _memberControllers.length == 1) {
                              return 'Nhóm cần có ít nhất một thành viên khác ngoài trưởng nhóm';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _removeMemberField(index),
                        icon: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444)),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE2E2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
