import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../../domain/model/notification_model.dart';

class NotificationDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> insertNotification(NotificationItem item) async {
    final db = await _dbHelper.database;
    await db.insert(
      'notifications',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<NotificationItem>> getAllNotifications(String userId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => NotificationItem.fromMap(map)).toList();
  }

  Future<void> markAsRead(String id, String userId) async {
    final db = await _dbHelper.database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<void> markAllAsRead(String userId) async {
    final db = await _dbHelper.database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'isRead = ? AND userId = ?',
      whereArgs: [0, userId],
    );
  }

  Future<void> deleteNotification(String id, String userId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'notifications',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<int> getUnreadCount(String userId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE isRead = 0 AND userId = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteOldNotifications(String userId) async {
    final db = await _dbHelper.database;
    final limitDate = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    await db.delete(
      'notifications',
      where: 'createdAt < ? AND userId = ?',
      whereArgs: [limitDate, userId],
    );
  }
}
