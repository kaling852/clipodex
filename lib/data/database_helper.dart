import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ClipItem {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  ClipItem({
    required this.id,
    required this.title,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class DatabaseHelper {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'clipodex.db');

    final db = sqlite3.open(path);
    
    // Create tables if they don't exist
    db.execute('''
      CREATE TABLE IF NOT EXISTS clips (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    return db;
  }

  Future<void> insertClip(ClipItem clip) async {
    final db = await database;
    db.execute(
      'INSERT INTO clips (id, title, content, created_at) VALUES (?, ?, ?, ?)',
      [clip.id, clip.title, clip.content, clip.createdAt.toIso8601String()],
    );
  }

  Future<List<ClipItem>> getAllClips() async {
    final db = await database;
    final results = db.select('SELECT * FROM clips ORDER BY created_at DESC');
    
    return results.map((row) => ClipItem(
      id: row['id'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    )).toList();
  }

  Future<void> deleteClip(String id) async {
    final db = await database;
    db.execute('DELETE FROM clips WHERE id = ?', [id]);
  }

  Future<void> updateClip(ClipItem clip) async {
    final db = await database;
    db.execute(
      'UPDATE clips SET title = ?, content = ? WHERE id = ?',
      [clip.title, clip.content, clip.id]
    );
  }
} 