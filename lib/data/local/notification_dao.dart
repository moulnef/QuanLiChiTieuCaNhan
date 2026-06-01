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

  Future<List<NotificationItem>> getAllNotifications() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => NotificationItem.fromMap(map)).toList();
  }

  Future<void> markAsRead(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllAsRead() async {
    final db = await _dbHelper.database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'isRead = ?',
      whereArgs: [0],
    );
  }

  Future<void> deleteNotification(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getUnreadCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE isRead = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteOldNotifications() async {
    final db = await _dbHelper.database;
    final limitDate = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    await db.delete(
      'notifications',
      where: 'createdAt < ?',
      whereArgs: [limitDate],
    );
  }
}
