import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/model/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  IconData _getIconData(NotificationType type) {
    switch (type) {
      case NotificationType.transactionIncome:
        return Icons.south_west_rounded;
      case NotificationType.transactionExpense:
        return Icons.north_east_rounded;
      case NotificationType.savingLow:
        return Icons.savings_rounded;
      case NotificationType.budgetNearLimit:
        return Icons.warning_amber_rounded;
      case NotificationType.budgetExceeded:
        return Icons.error_outline_rounded;
      case NotificationType.budgetNegative:
        return Icons.money_off_csred_rounded;
      case NotificationType.monthlyOverspend:
        return Icons.trending_up_rounded;
      case NotificationType.debtDueSoon:
        return Icons.monetization_on_rounded;
      case NotificationType.installmentDue:
        return Icons.credit_card_rounded;
    }
  }

  Color _getIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.transactionIncome:
        return const Color(0xFF16A34A); // green
      case NotificationType.transactionExpense:
        return const Color(0xFF2563EB); // blue
      case NotificationType.savingLow:
        return const Color(0xFF10B981); // green
      case NotificationType.budgetNearLimit:
        return const Color(0xFFF59E0B); // orange
      case NotificationType.budgetExceeded:
        return const Color(0xFFEF4444); // red
      case NotificationType.budgetNegative:
        return const Color(0xFFDC2626); // red
      case NotificationType.monthlyOverspend:
        return const Color(0xFFEF4444); // red
      case NotificationType.debtDueSoon:
        return const Color(0xFF3B82F6); // blue
      case NotificationType.installmentDue:
        return const Color(0xFF8B5CF6); // purple
    }
  }

  Color _getIconBgColor(NotificationType type) {
    return _getIconColor(type).withValues(alpha: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8FAFC);
    const primary = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => provider.markAllAsRead(),
                icon: const Icon(
                  Icons.done_all_rounded,
                  size: 18,
                  color: primary,
                ),
                label: const Text(
                  'Đọc tất cả',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }

          if (provider.notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(),
            color: primary,
            child: ListView.separated(
              itemCount: provider.notifications.length,
              padding: const EdgeInsets.symmetric(vertical: 12),
              separatorBuilder: (context, index) => const SizedBox(height: 1),
              itemBuilder: (context, index) {
                final item = provider.notifications[index];
                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: const Color(0xFFEF4444),
                    child: const Icon(
                      Icons.delete_sweep_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  onDismissed: (_) {
                    provider.deleteNotification(item.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa thông báo'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: InkWell(
                    onTap: () {
                      if (!item.isRead) {
                        provider.markAsRead(item.id);
                      }
                    },
                    child: Container(
                      color: item.isRead
                          ? Colors.white
                          : const Color(0xFFEFF6FF), // blue-ish highlight
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Icon decoration
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getIconBgColor(item.type),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIconData(item.type),
                              color: _getIconColor(item.type),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Content Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          fontWeight: item.isRead
                                              ? FontWeight.w600
                                              : FontWeight.bold,
                                          fontSize: 15,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _timeAgo(item.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.body,
                                  style: TextStyle(
                                    fontWeight: item.isRead
                                        ? FontWeight.normal
                                        : FontWeight.w500,
                                    fontSize: 13.5,
                                    color: item.isRead
                                        ? const Color(0xFF475569)
                                        : const Color(0xFF1E293B),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: 12),
                            // Tiny Blue Unread Dot
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xFFE2E8F0), blurRadius: 20),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Không có thông báo nào',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tất cả thông báo tài chính cá nhân của bạn sẽ hiển thị tại đây khi hệ thống kiểm tra số liệu.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
}
