import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  
  // Hardcoded key for academic demo purposes. In production, use FlutterSecureStorage.
  final String _dbPassword = 'smartstore_secure_key_2026';

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smartstore_lite.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      password: _dbPassword,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        role TEXT CHECK(role IN ('Manager', 'Staff')) NOT NULL,
        default_location_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE locations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        is_warehouse INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        brand TEXT,
        category TEXT NOT NULL,
        image_url TEXT,
        price REAL NOT NULL CHECK(price > 0),
        min_stock_threshold INTEGER DEFAULT 5,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        movement_type TEXT CHECK(movement_type IN ('IN', 'OUT', 'ADJUSTMENT', 'TRANSFER')) NOT NULL,
        from_location_id TEXT,
        to_location_id TEXT,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        user_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        sync_status TEXT CHECK(sync_status IN ('PENDING', 'SYNCED', 'CONFLICT')) DEFAULT 'PENDING',
        FOREIGN KEY(product_id) REFERENCES products(id),
        FOREIGN KEY(from_location_id) REFERENCES locations(id),
        FOREIGN KEY(to_location_id) REFERENCES locations(id),
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_changes (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action_type TEXT CHECK(action_type IN ('CREATE', 'UPDATE', 'DELETE')) NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE api_cache (
        barcode TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
  }
}