import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/backup_service.dart';
import '../providers/sync_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/budget_provider.dart';
import '../../utils/app_localizer.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BackupService _backupService = BackupService();
  bool _isLoading = false;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateCloudBackup() async {
    final nameController = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tên bản sao lưu'.xtr(context)),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'Ví dụ: Bản sao lưu đầu tháng 6'.xtr(context),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'.xtr(context)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Tạo ngay'.xtr(context)),
          ),
        ],
      ),
    );

    if (confirm == true && nameController.text.isNotEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await _backupService.createCloudBackupPoint(
          _userId,
          nameController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tạo bản sao lưu thành công'.xtr(context)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi tạo sao lưu: $e'.xtr(context))),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRestoreCloud(String label, String dataJson) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Xác nhận khôi phục'.xtr(context),
          style: const TextStyle(color: Colors.red),
        ),
        content: Text(
          'Dữ liệu hiện tại của bạn trên máy sẽ bị thay thế bởi bản sao lưu "$label". Bạn có chắc chắn muốn khôi phục?'
              .xtr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'.xtr(context)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Khôi phục ngay'.xtr(context)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await _backupService.restoreFromCloudBackup(_userId, dataJson);
        if (mounted) {
          // Làm mới dữ liệu trong các Provider để UI cập nhật ngay lập tức
          final now = DateTime.now();
          context.read<FinanceProvider>().refreshFinancialSummary(_userId);
          context.read<BudgetProvider>().loadMonthlyBudgets(
            _userId,
            now.month,
            now.year,
          );
          context.read<SyncProvider>().syncNow(_userId);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Dữ liệu đã được khôi phục thành công'.xtr(context),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi khôi phục: $e'.xtr(context))),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleExportFile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _backupService.exportToLocalFile(_userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xuất file: $e'.xtr(context))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImportFile() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chọn file khôi phục'.xtr(context)),
        content: Text(
          'Vui lòng chọn file .json đã xuất trước đó. Dữ liệu hiện tại sẽ bị xóa sạch trước khi nhập.'
              .xtr(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'.xtr(context)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Chọn file'.xtr(context)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final success = await _backupService.importFromLocalFile(_userId);
        if (success && mounted) {
          // Làm mới dữ liệu trong các Provider để UI cập nhật ngay lập tức
          final now = DateTime.now();
          context.read<FinanceProvider>().refreshFinancialSummary(_userId);
          context.read<BudgetProvider>().loadMonthlyBudgets(
            _userId,
            now.month,
            now.year,
          );
          context.read<SyncProvider>().syncNow(_userId);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã nhập dữ liệu thành công từ file'.xtr(context)),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Không thể nhập dữ liệu. File có thể không hợp lệ.'.xtr(
                  context,
                ),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi nhập file: $e'.xtr(context))),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sao lưu & Khôi phục'.xtr(context),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Đám mây'.xtr(context)),
            Tab(text: 'Tệp tin'.xtr(context)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [_buildCloudTab(), _buildFileTab()],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCloudTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleCreateCloudBackup,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text('Tạo điểm khôi phục đám mây'.xtr(context)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _backupService.streamCloudBackupPoints(_userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có bản sao lưu nào'.xtr(context),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt =
                      (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final label = data['label'] ?? 'Không tên';
                  final counts =
                      data['recordsCount'] as Map<String, dynamic>? ?? <String, dynamic>{};

                  return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final bool?
                                      confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            'Xóa bản sao lưu'.xtr(context),
                                          ),
                                          content: Text(
                                            'Bạn có chắc chắn muốn xóa bản sao lưu này không?'
                                                .xtr(context),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text('Hủy'.xtr(context)),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text(
                                                'Xóa'.xtr(context),
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _backupService
                                            .deleteCloudBackupPoint(
                                              _userId,
                                              doc.id,
                                            );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                DateFormat(
                                  'HH:mm dd/MM/yyyy',
                                ).format(createdAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const Divider(height: 24),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: counts.entries.map((e) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${e.key}: ${e.value}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleRestoreCloud(
                                    label,
                                    data['dataJson'],
                                  ),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: Text('Khôi phục'.xtr(context)),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                      .slideX(begin: 0.1, end: 0);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          icon: Icons.file_upload_outlined,
          title: 'Xuất dữ liệu local'.xtr(context),
          description:
              'Xuất toàn bộ dữ liệu của bạn thành tệp .json để lưu trữ ngoại tuyến hoặc gửi qua email, Drive...'
                  .xtr(context),
          buttonText: 'Xuất tệp sao lưu (.json)'.xtr(context),
          onPressed: _handleExportFile,
          color: Colors.indigo,
        ),
        const SizedBox(height: 20),
        _buildInfoCard(
          icon: Icons.file_download_outlined,
          title: 'Khôi phục từ tệp'.xtr(context),
          description:
              'Chọn một tệp sao lưu .json từ bộ nhớ thiết bị để khôi phục lại toàn bộ dữ liệu. Lưu ý: Dữ liệu hiện tại sẽ bị xóa sạch.'
                  .xtr(context),
          buttonText: 'Nhập tệp sao lưu (.json)'.xtr(context),
          onPressed: _handleImportFile,
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9));
  }
}
