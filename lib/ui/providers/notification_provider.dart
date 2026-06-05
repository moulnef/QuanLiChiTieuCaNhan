import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  String? _currentUserId() => FirebaseAuth.instance.currentUser?.uid;

  Future<void> loadNotifications() async {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      _notifications = [];
      _unreadCount = 0;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await _dao.getAllNotifications(userId);
      _unreadCount = await _dao.getUnreadCount(userId);
    } catch (e) {
      debugPrint('Error loading notifications in provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) return;
    try {
      await _dao.markAsRead(id, userId);
      await loadNotifications();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) return;
    try {
      await _dao.markAllAsRead(userId);
      await loadNotifications();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) return;
    try {
      await _dao.deleteNotification(id, userId);
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
