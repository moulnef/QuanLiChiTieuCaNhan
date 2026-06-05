import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ai_quan_ly_chi_tieu_ca_nhan/domain/model/split_group.dart';
import '../providers/split_provider.dart';
import 'split_group_detail_screen.dart';
import 'add_split_group_sheet.dart';
import '../../utils/app_localizer.dart';

class SplitGroupListScreen extends StatefulWidget {
  const SplitGroupListScreen({super.key});

  @override
  State<SplitGroupListScreen> createState() => _SplitGroupListScreenState();
}

class _SplitGroupListScreenState extends State<SplitGroupListScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
  }

  void _showAddGroupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddSplitGroupSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final splitProvider = context.watch<SplitProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          'Chia tiền nhóm'.xtr(context),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8F9FE), Color(0xFFEDF2FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Real-time stream is automatic, but we can re-fetch total spent for groups on manual pull-to-refresh
          for (final group in splitProvider.myGroups) {
            // Trigger background update
            // We can just await a brief delay to simulate work
          }
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: const Color(0xFF6D28D9),
        child: splitProvider.isLoading && splitProvider.myGroups.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : splitProvider.myGroups.isEmpty
                ? _buildEmptyState(theme)
                : _buildGroupList(splitProvider.myGroups, splitProvider, theme),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGroupSheet,
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: Text(
          'Tạo nhóm mới'.xtr(context),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6D28D9).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.users,
                size: 64,
                color: Color(0xFF6D28D9),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có nhóm chia tiền'.xtr(context),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tạo nhóm để ghi chép các khoản chi tiêu ăn uống, đi chơi, du lịch cùng bạn bè và tự động chia tiền sòng phẳng.'.xtr(context),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupList(List<SplitGroup> groups, SplitProvider splitProvider, ThemeData theme) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final totalSpent = splitProvider.getGroupTotalSpent(group.id);
        final dateStr = DateFormat('dd/MM/yyyy').format(group.createdAt);
        final isSettled = group.status == SplitGroupStatus.settled;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFFE2E8F0),
              width: isSettled ? 1 : 1.5,
            ),
          ),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SplitGroupDetailScreen(groupId: group.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSettled
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSettled ? LucideIcons.checkCircle2 : LucideIcons.clock,
                              size: 14,
                              color: isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                                   Text(
                              (isSettled ? 'Đã quyết toán' : 'Đang mở').xtr(context),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(LucideIcons.users, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        '${group.memberUids.length} ' + 'thành viên'.xtr(context),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng chi tiêu nhóm:'.xtr(context),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        _currencyFormat.format(totalSpent),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
