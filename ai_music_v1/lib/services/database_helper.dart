import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/record_entry.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('records.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  filePath TEXT NOT NULL,
  comment TEXT NOT NULL,
  videoPath TEXT
)
''');
  }

  Future<int> insertRecord(RecordEntry record) async {
    final db = await instance.database;
    return await db.insert('records', record.toMap());
  }

  Future<List<RecordEntry>> getAllRecords() async {
    final db = await instance.database;
    final result = await db.query('records', orderBy: 'id DESC');
    return result.map((json) => RecordEntry.fromMap(json)).toList();
  }

  Future<int> deleteRecord(int id) async {
    final db = await instance.database;
    return await db.delete(
      'records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
