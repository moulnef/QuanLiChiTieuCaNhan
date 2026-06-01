import 'package:flutter/material.dart';
import '../../domain/model/notification_model.dart';
import '../../data/local/notification_dao.dart';
import '../../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationDao _dao = NotificationDao();
  
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await _dao.getAllNotifications();
      _unreadCount = await _dao.getUnreadCount();
    } catch (e) {
      debugPrint('Error loading notifications in provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _dao.markAsRead(id);
      await loadNotifications();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _dao.markAllAsRead();
      await loadNotifications();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _dao.deleteNotification(id);
      await loadNotifications();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> checkNewNotifications(String userId) async {
    try {
      await NotificationService.instance.checkAndTriggerNotifications(userId);
      await loadNotifications();
    } catch (e) {
      debugPrint('Error checking new notifications: $e');
    }
  }
}
