import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // Tạo file database phiên bản 1
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Tạo bảng transactions (giao dịch)
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY, 
        amount REAL, 
        type TEXT, 
        categoryId TEXT, 
        walletId TEXT, 
        date TEXT, 
        note TEXT, 
        person TEXT
      )
    ''');
  }
}