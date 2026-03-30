import 'package:sqflite/sqflite.dart';
import '../entity/transaction_entity.dart';
import '../database_helper.dart';

class TransactionDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> insert(TransactionEntity entity) async {
    final db = await _dbHelper.database;
    await db.insert('transactions', entity.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TransactionEntity>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map((map) => TransactionEntity.fromMap(map)).toList();
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}