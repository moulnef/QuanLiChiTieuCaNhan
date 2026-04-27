import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const int _databaseVersion = 2;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await _createAllTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _createAllTables(db);
    await _migrateTransactionsColumns(db);
  }

  Future<void> _createAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        userId TEXT,
        user_id TEXT,
        walletId TEXT,
        wallet_id TEXT,
        categoryId TEXT,
        category_id TEXT,
        categoryName TEXT,
        category_name TEXT,
        type TEXT,
        amount REAL,
        note TEXT,
        transactionDate TEXT,
        transaction_date TEXT,
        date TEXT,
        createdAt TEXT,
        created_at TEXT,
        updatedAt TEXT,
        updated_at TEXT,
        person TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id TEXT PRIMARY KEY,
        userId TEXT,
        user_id TEXT,
        categoryId TEXT,
        category_id TEXT,
        categoryName TEXT,
        category_name TEXT,
        icon TEXT,
        month INTEGER,
        year INTEGER,
        limitAmount INTEGER,
        limit_amount INTEGER,
        spentAmount INTEGER,
        spent_amount INTEGER,
        status TEXT,
        createdAt INTEGER,
        created_at INTEGER,
        updatedAt INTEGER,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS savings (
        id INTEGER PRIMARY KEY,
        userId TEXT,
        user_id TEXT,
        icon TEXT,
        title TEXT,
        currentAmount INTEGER,
        current_amount INTEGER,
        targetAmount INTEGER,
        target_amount INTEGER,
        deadline TEXT,
        targetDate INTEGER,
        target_date INTEGER,
        colorValue INTEGER,
        color_value INTEGER,
        createdAt INTEGER,
        created_at INTEGER,
        updatedAt INTEGER,
        updated_at INTEGER,
        status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS installments (
        id INTEGER PRIMARY KEY,
        userId TEXT,
        user_id TEXT,
        icon TEXT,
        title TEXT,
        totalAmount INTEGER,
        total_amount INTEGER,
        paidAmount INTEGER,
        paid_amount INTEGER,
        monthlyPayment INTEGER,
        monthly_payment INTEGER,
        currentPeriod INTEGER,
        current_period INTEGER,
        paidPeriods INTEGER,
        paid_periods INTEGER,
        totalPeriods INTEGER,
        total_periods INTEGER,
        nextDueDate TEXT,
        next_due_date TEXT,
        nextDueDateEpoch INTEGER,
        next_due_date_epoch INTEGER,
        colorValue INTEGER,
        color_value INTEGER,
        createdAt INTEGER,
        created_at INTEGER,
        updatedAt INTEGER,
        updated_at INTEGER,
        status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS debts (
        id INTEGER PRIMARY KEY,
        userId TEXT,
        user_id TEXT,
        icon TEXT,
        title TEXT,
        lender TEXT,
        lenderName TEXT,
        lender_name TEXT,
        totalAmount INTEGER,
        total_amount INTEGER,
        paidAmount INTEGER,
        paid_amount INTEGER,
        monthlyPayment INTEGER,
        monthly_payment INTEGER,
        interestRate REAL,
        interest_rate REAL,
        interestText TEXT,
        interest_text TEXT,
        dueDate TEXT,
        due_date TEXT,
        nextDueDate INTEGER,
        next_due_date INTEGER,
        colorValue INTEGER,
        color_value INTEGER,
        createdAt INTEGER,
        created_at INTEGER,
        updatedAt INTEGER,
        updated_at INTEGER,
        status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS wallets (
        id TEXT PRIMARY KEY,
        userId TEXT,
        user_id TEXT,
        name TEXT,
        balance REAL,
        createdAt INTEGER,
        created_at INTEGER,
        updatedAt INTEGER,
        updated_at INTEGER,
        status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_session (
        userId TEXT PRIMARY KEY,
        user_id TEXT,
        email TEXT,
        displayName TEXT,
        photoURL TEXT,
        photo_url TEXT,
        role TEXT,
        createdAt INTEGER,
        created_at INTEGER,
        updatedAt INTEGER,
        updated_at INTEGER
      )
    ''');

    await _migrateTransactionsColumns(db);
  }

  Future<void> _migrateTransactionsColumns(Database db) async {
    const requiredColumns = <String>[
      'userId TEXT',
      'user_id TEXT',
      'walletId TEXT',
      'wallet_id TEXT',
      'categoryId TEXT',
      'category_id TEXT',
      'categoryName TEXT',
      'category_name TEXT',
      'transactionDate TEXT',
      'transaction_date TEXT',
      'createdAt TEXT',
      'created_at TEXT',
      'updatedAt TEXT',
      'updated_at TEXT',
      'note TEXT',
      'amount REAL',
      'type TEXT',
      'date TEXT',
    ];

    for (final columnDef in requiredColumns) {
      await _addColumnIfMissing(db, 'transactions', columnDef);
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String columnDef,
  ) async {
    final columnName = columnDef.split(' ').first;
    final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
    final exists = tableInfo.any((row) => row['name'] == columnName);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
    }
  }
}
