import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/model/budget.dart';
import '../domain/model/transaction_model.dart';
import '../domain/model/notification_model.dart';
import '../data/local/notification_dao.dart';
import '../data/repository/finance_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  NotificationService._init();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final NotificationDao _dao = NotificationDao();
  final FinanceRepository _financeRepo = FinanceRepository();

  bool _isInitialized = false;

  static String preferenceKey(String userId) => 'notification_enabled_$userId';

  Future<bool> isNotificationEnabledForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(preferenceKey(userId)) ?? true;
  }

  Future<void> setNotificationEnabledForUser(
    String userId,
    bool isEnabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKey(userId), isEnabled);
  }

  Future<void> init() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(initializationSettings);
    _isInitialized = true;
  }

  Future<bool> checkPermission() async {
    if (kIsWeb) return true;
    return await Permission.notification.isGranted;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> notifyTransactionRecorded(
    String userId,
    TransactionModel transaction,
  ) async {
    if (userId.isEmpty) return;

    final canNotify = await _ensureReadyForPush(
      userId,
      requestOsPermission: true,
    );
    if (!canNotify) {
      return;
    }

    final amountText = _money(transaction.amount);
    final label = transaction.note.trim().isNotEmpty
        ? transaction.note.trim()
        : transaction.categoryName.trim().isNotEmpty
        ? transaction.categoryName.trim()
        : 'giao dich moi';

    if (transaction.type.toLowerCase() == 'income') {
      await _triggerPushAndSave(
        userId,
        NotificationType.transactionIncome,
        'Thu nhập mới',
        'Bạn vừa ghi nhận thu nhập $amountText từ $label.',
        transaction.id,
      );
      return;
    }

    await _triggerPushAndSave(
      userId,
      NotificationType.transactionExpense,
      'Chi tiêu mới',
      'Bạn vừa chi $amountText cho $label.',
      transaction.id,
    );

    await _notifyBudgetIfNegative(userId, transaction);
  }

  Future<void> checkAndTriggerNotifications(String userId) async {
    if (userId.isEmpty) return;

    final canNotify = await _ensureReadyForPush(userId);
    if (!canNotify) {
      return;
    }

    // Delete notifications older than 30 days
    await _dao.deleteOldNotifications(userId);

    final existingNotifications = await _dao.getAllNotifications(userId);
    final now = DateTime.now();

    // 1. Check Saving Goals (SavingLow: progress < 20%)
    try {
      final savings = await _financeRepo.getAllSavingGoals(userId);
      for (final goal in savings) {
        if (goal.status.toLowerCase() != 'settled' && goal.targetAmount > 0) {
          final percent = (goal.currentAmount * 100) / goal.targetAmount;
          if (percent < 20) {
            final type = NotificationType.savingLow;
            final relatedId = goal.id;
            final alreadyNotified = existingNotifications.any(
              (n) => n.type == type && n.relatedId == relatedId,
            );

            if (!alreadyNotified) {
              final percentStr = percent.toStringAsFixed(0);
              final title = 'Mục tiêu tiết kiệm';
              final body = _translate(
                'notification_saving_low',
                namedArgs: {'name': goal.title, 'percent': percentStr},
                fallback: "Tiết kiệm '{name}' còn {percent}% - sắp hết!",
              );
              await _triggerPushAndSave(userId, type, title, body, relatedId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking savings for notifications: $e');
    }

    // 2. Check Budgets (BudgetNearLimit: spent >= 80% & < 100%, BudgetExceeded: spent >= 100%)
    try {
      await _financeRepo.refreshBudgetSpentForPeriod(
        userId,
        now.month,
        now.year,
      );
      final budgets = await _financeRepo.getBudgets(
        userId,
        now.month,
        now.year,
      );
      for (final budget in budgets) {
        if (budget.limitAmount > 0) {
          final spentPercent = (budget.spentAmount * 100) / budget.limitAmount;
          if (spentPercent >= 100) {
            final type = NotificationType.budgetExceeded;
            final relatedId = budget.id;
            final alreadyNotified = existingNotifications.any(
              (n) => n.type == type && n.relatedId == relatedId,
            );

            if (!alreadyNotified) {
              final title = 'Vượt giới hạn ngân sách';
              final body = _translate(
                'notification_budget_exceeded',
                namedArgs: {'name': budget.categoryName},
                fallback: "Ngân sách '{name}' đã vượt mức!",
              );
              await _triggerPushAndSave(userId, type, title, body, relatedId);
            }
          } else if (spentPercent >= 80) {
            final type = NotificationType.budgetNearLimit;
            final relatedId = budget.id;
            final alreadyNotified = existingNotifications.any(
              (n) => n.type == type && n.relatedId == relatedId,
            );

            if (!alreadyNotified) {
              final percentStr = spentPercent.toStringAsFixed(0);
              final title = 'Sắp đạt giới hạn ngân sách';
              final body = _translate(
                'notification_budget_near',
                namedArgs: {'name': budget.categoryName, 'percent': percentStr},
                fallback: "Ngân sách '{name}' đã dùng {percent}%",
              );
              await _triggerPushAndSave(userId, type, title, body, relatedId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking budgets for notifications: $e');
    }

    // 3. Check Monthly Overspend (monthly expense > income)
    try {
      final transactions = await _financeRepo.getAllTransactionsByUserId(
        userId,
      );
      final monthlyTx = transactions.where((tx) {
        return tx.transactionDate.month == now.month &&
            tx.transactionDate.year == now.year &&
            !tx.isDeleted;
      }).toList();

      double totalIncome = 0;
      double totalExpense = 0;
      for (final tx in monthlyTx) {
        if (tx.type == 'income') {
          totalIncome += tx.amount;
        } else {
          totalExpense += tx.amount;
        }
      }

      if (totalExpense > totalIncome) {
        final type = NotificationType.monthlyOverspend;
        final relatedId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final alreadyNotified = existingNotifications.any(
          (n) => n.type == type && n.relatedId == relatedId,
        );

        if (!alreadyNotified) {
          final overspend = totalExpense - totalIncome;
          final formatter = NumberFormat('#,###', 'vi_VN');
          final overspendStr = '${formatter.format(overspend)} đ';

          final title = 'Cảnh báo chi tiêu';
          final body = _translate(
            'notification_monthly_overspend',
            namedArgs: {'amount': overspendStr},
            fallback: "Tháng này chi tiêu vượt thu nhập {amount}",
          );
          await _triggerPushAndSave(userId, type, title, body, relatedId);
        }
      }
    } catch (e) {
      debugPrint('Error checking monthly overspend for notifications: $e');
    }

    // 4. Check Debt Due Soon (due in <= 3 days)
    try {
      final debts = await _financeRepo.getDebtsByUserId(userId);
      for (final debt in debts) {
        if (debt.remainingAmount > 0) {
          final daysLeft = debt.dueDate.difference(now).inDays;
          if (daysLeft >= 0 && daysLeft <= 3) {
            final type = NotificationType.debtDueSoon;
            final relatedId = debt.id.toString();
            final alreadyNotified = existingNotifications.any(
              (n) => n.type == type && n.relatedId == relatedId,
            );

            if (!alreadyNotified) {
              final title = 'Khoản nợ đến hạn';
              final body = _translate(
                'notification_debt_due',
                namedArgs: {'name': debt.title, 'days': daysLeft.toString()},
                fallback: "Khoản nợ '{name}' đến hạn sau {days} ngày",
              );
              await _triggerPushAndSave(userId, type, title, body, relatedId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking debts for notifications: $e');
    }

    // 5. Check Installment Due (due in <= 1 day)
    try {
      final installments = await _financeRepo.getInstallmentsByUserId(userId);
      for (final inst in installments) {
        if (inst.remainingAmount > 0) {
          final daysLeft = inst.nextDueDate.difference(now).inDays;
          if (daysLeft >= 0 && daysLeft <= 1) {
            final type = NotificationType.installmentDue;
            final relatedId = inst.id.toString();
            final alreadyNotified = existingNotifications.any(
              (n) => n.type == type && n.relatedId == relatedId,
            );

            if (!alreadyNotified) {
              final title = 'Kỳ trả góp đến hạn';
              final body = _translate(
                'notification_installment_due',
                namedArgs: {'name': inst.title},
                fallback: "Trả góp '{name}' đến kỳ thanh toán",
              );
              await _triggerPushAndSave(userId, type, title, body, relatedId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking installments for notifications: $e');
    }
  }

  Future<void> _triggerPushAndSave(
    String userId,
    NotificationType type,
    String title,
    String body,
    String relatedId,
  ) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = NotificationItem(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      isRead: false,
      relatedId: relatedId,
    );

    // 1. Save to SQLite
    await _dao.insertNotification(item);

    // 2. Trigger push notification
    if (!kIsWeb) {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
            'financial_reminders',
            'Nhắc nhở tài chính',
            channelDescription: 'Kênh thông báo nhắc nhở tài chính cá nhân',
            importance: Importance.max,
            priority: Priority.high,
          );
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await _localNotifications.show(
        id.hashCode,
        title,
        body,
        notificationDetails,
      );
    }
  }

  Future<bool> _ensureReadyForPush(
    String userId, {
    bool requestOsPermission = false,
  }) async {
    final isEnabled = await isNotificationEnabledForUser(userId);
    if (!isEnabled) {
      debugPrint('Notifications are disabled by user preference.');
      return false;
    }

    var hasPermission = await checkPermission();
    if (!hasPermission && requestOsPermission) {
      hasPermission = await requestPermission();
    }

    if (!hasPermission) {
      debugPrint('Notification permission is not granted by OS.');
      return false;
    }

    await init();
    return true;
  }

  Future<void> _notifyBudgetIfNegative(
    String userId,
    TransactionModel transaction,
  ) async {
    final now = transaction.transactionDate;
    await _financeRepo.refreshBudgetSpentForPeriod(userId, now.month, now.year);
    final budgets = await _financeRepo.getBudgets(userId, now.month, now.year);

    Budget? impactedBudget;
    for (final budget in budgets) {
      if (budget.categoryId == transaction.categoryId &&
          budget.limitAmount > 0) {
        impactedBudget = budget;
        break;
      }
    }

    if (impactedBudget == null) {
      return;
    }

    final remaining = impactedBudget.limitAmount - impactedBudget.spentAmount;
    if (remaining >= 0) {
      return;
    }

    await _triggerPushAndSave(
      userId,
      NotificationType.budgetNegative,
      'Cảnh báo vượt ngân sách',
      'Danh mục ${impactedBudget.categoryName} đã âm ${_money(remaining.abs())} so với ngân sách.',
      '${impactedBudget.id}_${transaction.id}',
    );
  }

  String _money(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount.round())} đ';
  }

  String _translate(
    String key, {
    Map<String, String>? namedArgs,
    String? fallback,
  }) {
    try {
      String val = key.tr(namedArgs: namedArgs);
      if (val == key && fallback != null) {
        String res = fallback;
        namedArgs?.forEach((k, v) {
          res = res.replaceAll('{$k}', v);
        });
        return res;
      }
      return val;
    } catch (_) {
      if (fallback != null) {
        String res = fallback;
        namedArgs?.forEach((k, v) {
          res = res.replaceAll('{$k}', v);
        });
        return res;
      }
      return key;
    }
  }
}
