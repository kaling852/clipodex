import 'package:clipodex/models/tag.dart';
import 'package:clipodex/models/clip_item.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

class DatabaseHelper {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getLibraryDirectory();
    final dbDir = Directory(p.join(directory.path, 'Database'));
    
    // Ensure the directory exists
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    
    final path = p.join(dbDir.path, 'clipodex.db');
    print('Database path (sandboxed): $path');

    final db = sqlite3.open(path);
    
    // Create tables if they don't exist
    db.execute('''
      CREATE TABLE IF NOT EXISTS clips (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        position INTEGER NOT NULL,
        copy_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        is_masked INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Migration: Add is_masked column if it doesn't exist
    try {
      final columns = db.select("PRAGMA table_info(clips)");
      final hasMaskedColumn = columns.any((col) => col['name'] == 'is_masked');
      
      if (!hasMaskedColumn) {
        db.execute('ALTER TABLE clips ADD COLUMN is_masked INTEGER NOT NULL DEFAULT 0');
      }
    } catch (e) {
      // If there's an error, it's safer to recreate the database
      db.execute('DROP TABLE IF EXISTS clips');
      db.execute('DROP TABLE IF EXISTS tags');
      db.execute('DROP TABLE IF EXISTS clip_tags');
      
      // Recreate tables
      db.execute('''
        CREATE TABLE clips (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          position INTEGER NOT NULL,
          copy_count INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          is_masked INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }

    db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS clip_tags (
        clip_id TEXT,
        tag_id TEXT,
        FOREIGN KEY (clip_id) REFERENCES clips (id),
        FOREIGN KEY (tag_id) REFERENCES tags (id),
        PRIMARY KEY (clip_id, tag_id)
      )
    ''');

    return db;
  }

  Future<void> insertClip(ClipItem clip, List<Tag> tags) async {
    final db = await database;
    db.execute(
      'INSERT INTO clips (id, title, content, position, copy_count, created_at, is_masked) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [clip.id, clip.title, clip.content, clip.position, clip.copyCount, clip.createdAt.toIso8601String(), clip.isMasked ? 1 : 0],
    );

    // Add tags
    for (var tag in tags) {
      await addTagToClip(clip.id, tag.id);
    }
  }

  Future<List<ClipItem>> getAllClips() async {
    final db = await database;
    final results = db.select('SELECT * FROM clips ORDER BY copy_count DESC, position ASC');
    
    return results.map((row) => ClipItem(
      id: row['id'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      position: row['position'] as int,
      copyCount: row['copy_count'] as int,
      isMasked: row['is_masked'] == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
    )).toList();
  }

  Future<void> deleteClip(String id) async {
    final db = await database;
    db.execute('DELETE FROM clips WHERE id = ?', [id]);
    // Delete associated tags
    db.execute('DELETE FROM clip_tags WHERE clip_id = ?', [id]);
  }

  Future<void> updateClip(ClipItem clip, List<Tag> tags) async {
    final db = await database;
    db.execute(
      'UPDATE clips SET title = ?, content = ?, position = ?, is_masked = ? WHERE id = ?',
      [clip.title, clip.content, clip.position, clip.isMasked ? 1 : 0, clip.id]
    );

    // Update tags
    db.execute('DELETE FROM clip_tags WHERE clip_id = ?', [clip.id]);
    for (var tag in tags) {
      await addTagToClip(clip.id, tag.id);
    }
  }

  Future<void> createTag(Tag tag) async {
    final db = await database;
    db.execute(
      'INSERT INTO tags (id, name) VALUES (?, ?)',
      [tag.id, tag.name],
    );
  }

  Future<List<Tag>> getAllTags() async {
    final db = await database;
    final results = db.select('SELECT * FROM tags ORDER BY name');
    return results.map((row) => Tag(
      id: row['id'] as String,
      name: row['name'] as String,
    )).toList();
  }

  Future<void> addTagToClip(String clipId, String tagId) async {
    final db = await database;
    db.execute(
      'INSERT INTO clip_tags (clip_id, tag_id) VALUES (?, ?)',
      [clipId, tagId],
    );
  }

  Future<List<Tag>> getTagsForClip(String clipId) async {
    final db = await database;
    final results = db.select('''
      SELECT t.* FROM tags t
      JOIN clip_tags ct ON ct.tag_id = t.id
      WHERE ct.clip_id = ?
      ORDER BY t.name
    ''', [clipId]);
    
    return results.map((row) => Tag(
      id: row['id'] as String,
      name: row['name'] as String,
    )).toList();
  }

  Future<bool> hasClipsWithTags() async {
    final db = await database;
    final result = db.select('SELECT COUNT(*) as count FROM clip_tags');
    return (result.first['count'] as int) > 0;
  }

  Future<List<ClipItem>> getClipsWithTag(String tagId) async {
    final db = await database;
    final results = db.select('''
      SELECT c.* FROM clips c
      JOIN clip_tags ct ON ct.clip_id = c.id
      WHERE ct.tag_id = ?
      ORDER BY c.copy_count DESC, c.position ASC
    ''', [tagId]);
    
    return results.map((row) => ClipItem(
      id: row['id'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      position: row['position'] as int,
      copyCount: row['copy_count'] as int,
      isMasked: row['is_masked'] == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
    )).toList();
  }

  Future<void> deleteTag(String tagId) async {
    final db = await database;
    db.execute('DELETE FROM tags WHERE id = ?', [tagId]);
    db.execute('DELETE FROM clip_tags WHERE tag_id = ?', [tagId]);
  }

  Future<void> renameTag(String tagId, String newName) async {
    final db = await database;
    db.execute(
      'UPDATE tags SET name = ? WHERE id = ?',
      [newName, tagId],
    );
  }

  Future<void> incrementCopyCount(String clipId) async {
    final db = await database;
    db.execute(
      'UPDATE clips SET copy_count = copy_count + 1 WHERE id = ?',
      [clipId],
    );
  }
} 