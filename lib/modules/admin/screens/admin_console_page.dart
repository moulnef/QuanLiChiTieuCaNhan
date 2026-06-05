import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../domain/model/app_feedback.dart';
import '../../../ui/providers/auth_provider.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String _userKeyword = '';
  String _feedbackKeyword = '';
  int _ratingFilter = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản trị')),
        body: const Center(
          child: Text(
            'Bạn không có quyền truy cập trang quản trị.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Trang quản trị'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tổng quan'),
              Tab(text: 'Người dùng'),
              Tab(text: 'Lịch sử đánh giá'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => context.read<AuthProvider>().signOut(),
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Đăng xuất',
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.hasError) {
              return _buildError(usersSnapshot.error.toString());
            }
            if (!usersSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('transactions')
                  .snapshots(),
              builder: (context, txSnapshot) {
                if (txSnapshot.hasError) {
                  return _buildError(txSnapshot.error.toString());
                }
                if (!txSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('feedbacks')
                      .snapshots(),
                  builder: (context, feedbackSnapshot) {
                    if (feedbackSnapshot.hasError) {
                      return _buildError(feedbackSnapshot.error.toString());
                    }
                    if (!feedbackSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final users = usersSnapshot.data!.docs
                        .map((doc) => doc.data())
                        .toList();
                    final transactionCount = txSnapshot.data!.docs.length;
                    final adminCount = users.where((u) {
                      return (u['role'] ?? '').toString().toLowerCase() ==
                          'admin';
                    }).length;
                    final feedbacks = feedbackSnapshot.data!.docs
                        .map(
                          (doc) => AppFeedback.fromMap(
                            Map<String, dynamic>.from(doc.data()),
                            doc.id,
                          ),
                        )
                        .toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    return TabBarView(
                      children: [
                        _OverviewTab(
                          userCount: users.length,
                          adminCount: adminCount,
                          transactionCount: transactionCount,
                          feedbackCount: feedbacks.length,
                        ),
                        _UsersTab(
                          users: users,
                          keyword: _userKeyword,
                          onKeywordChanged: (value) {
                            setState(() => _userKeyword = value);
                          },
                        ),
                        _FeedbackTab(
                          feedbacks: feedbacks,
                          keyword: _feedbackKeyword,
                          ratingFilter: _ratingFilter,
                          onKeywordChanged: (value) {
                            setState(() => _feedbackKeyword = value);
                          },
                          onRatingFilterChanged: (value) {
                            setState(() => _ratingFilter = value);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Không thể tải dữ liệu quản trị.\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.userCount,
    required this.adminCount,
    required this.transactionCount,
    required this.feedbackCount,
  });

  final int userCount;
  final int adminCount;
  final int transactionCount;
  final int feedbackCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              title: 'Tổng người dùng',
              value: userCount.toString(),
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF2563EB),
            ),
            _MetricCard(
              title: 'Quản trị viên',
              value: adminCount.toString(),
              icon: Icons.admin_panel_settings_rounded,
              color: const Color(0xFF7C3AED),
            ),
            _MetricCard(
              title: 'Tổng giao dịch',
              value: transactionCount.toString(),
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFEA580C),
            ),
            _MetricCard(
              title: 'Lượt đánh giá',
              value: feedbackCount.toString(),
              icon: Icons.reviews_rounded,
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
      ],
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.users,
    required this.keyword,
    required this.onKeywordChanged,
  });

  final List<Map<String, dynamic>> users;
  final String keyword;
  final ValueChanged<String> onKeywordChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = keyword.trim().toLowerCase();
    final filtered = users.where((user) {
      if (normalized.isEmpty) return true;
      final name = (user['displayName'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      return name.contains(normalized) || email.contains(normalized);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Tìm theo tên hoặc email',
            prefixIcon: Icon(Icons.search_rounded),
            border: OutlineInputBorder(),
          ),
          onChanged: onKeywordChanged,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Danh sách người dùng',
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Không tìm thấy người dùng phù hợp.'),
                )
              : Column(
                  children: filtered.take(100).map((user) {
                    final name = (user['displayName'] ?? 'Người dùng')
                        .toString();
                    final email = (user['email'] ?? 'Chưa cập nhật').toString();
                    final role = (user['role'] ?? 'user').toString();
                    final roleLabel = role.toLowerCase() == 'admin'
                        ? 'Quản trị viên'
                        : 'Người dùng';
                    final createdAt = _formatDate(user['createdAt']);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text('$email\nĐăng ký: $createdAt'),
                      isThreeLine: true,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: role.toLowerCase() == 'admin'
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            color: role.toLowerCase() == 'admin'
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF475569),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab({
    required this.feedbacks,
    required this.keyword,
    required this.ratingFilter,
    required this.onKeywordChanged,
    required this.onRatingFilterChanged,
  });

  final List<AppFeedback> feedbacks;
  final String keyword;
  final int ratingFilter;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<int> onRatingFilterChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = keyword.trim().toLowerCase();
    final filtered = feedbacks.where((feedback) {
      final matchesKeyword = normalized.isEmpty ||
          feedback.userDisplayName.toLowerCase().contains(normalized) ||
          feedback.userEmail.toLowerCase().contains(normalized) ||
          feedback.comment.toLowerCase().contains(normalized);
      final matchesRating =
          ratingFilter == 0 || feedback.rating == ratingFilter;
      return matchesKeyword && matchesRating;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Tìm theo tên người dùng hoặc nội dung đánh giá',
            prefixIcon: Icon(Icons.search_rounded),
            border: OutlineInputBorder(),
          ),
          onChanged: onKeywordChanged,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'Tất cả',
              selected: ratingFilter == 0,
              onTap: () => onRatingFilterChanged(0),
            ),
            ...List.generate(5, (index) {
              final star = index + 1;
              return _FilterChip(
                label: '$star sao',
                selected: ratingFilter == star,
                onTap: () => onRatingFilterChanged(star),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Lịch sử đánh giá góp ý',
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có đánh giá nào phù hợp.'),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${filtered.length} đánh giá hiển thị',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    ...filtered.take(150).map((feedback) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        feedback.userDisplayName.isEmpty
                                            ? 'Người dùng'
                                            : feedback.userDisplayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        feedback.userEmail.isEmpty
                                            ? 'Chưa có email'
                                            : feedback.userEmail,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(
                                    feedback.createdAt,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _StarRating(rating: feedback.rating),
                            const SizedBox(height: 10),
                            Text(
                              feedback.comment,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDBEAFE) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            index < rating ? Icons.star_rounded : Icons.star_border_rounded,
            size: 18,
            color: const Color(0xFFF59E0B),
          ),
        );
      }),
    );
  }
}

String _formatDate(dynamic raw) {
  DateTime? date;
  if (raw is Timestamp) {
    date = raw.toDate();
  } else if (raw is DateTime) {
    date = raw;
  } else if (raw is String) {
    date = DateTime.tryParse(raw);
  }

  if (date == null) {
    return 'Chưa rõ';
  }

  return DateFormat('dd/MM/yyyy').format(date);
}
