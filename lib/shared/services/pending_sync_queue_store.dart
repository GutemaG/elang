import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/pending_sync_entry.dart';

/// Local durable storage for offline-completed lessons awaiting sync
/// (010-offline-caching-and-sync-ui, story 003).
///
/// Kept as an interface (mirrors `LessonPackStore`/`ConnectivityMonitor`) so
/// widget tests never touch a real database. [SyncEngine] is the only
/// caller -- nothing else should reach into this store directly, so the
/// queue's contents and the sync-triggering logic that acts on them stay in
/// one place.
abstract class PendingSyncQueueStore {
  Future<void> enqueue(PendingSyncEntry entry);

  /// Every still-pending entry, oldest first (the order they were actually
  /// completed in, per FR-3) -- never re-sorted.
  Future<List<PendingSyncEntry>> listPending();

  Future<void> remove(String attemptId);

  Future<int> count();
}

/// Real implementation backed by `sqflite`, in its own database file --
/// this store's schema has no relationship to `LessonPackStore`'s, so
/// there's no reason to share a file.
class SqflitePendingSyncQueueStore implements PendingSyncQueueStore {
  static const _dbFileName = 'pending_sync_queue.db';
  static const _table = 'pending_sync_queue';

  Database? _db;

  Future<Database> _database() async {
    final existing = _db;
    if (existing != null) return existing;

    final documentsDir = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      '${documentsDir.path}/$_dbFileName',
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $_table ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'attempt_id TEXT UNIQUE NOT NULL, '
          'lesson_id TEXT NOT NULL, '
          'correct_count INTEGER NOT NULL, '
          'total_count INTEGER NOT NULL, '
          'time_spent_ms INTEGER NOT NULL, '
          'beans_remaining_at_end INTEGER NOT NULL, '
          'client_completed_at TEXT NOT NULL'
          ')',
        );
      },
    );
    _db = db;
    return db;
  }

  @override
  Future<void> enqueue(PendingSyncEntry entry) async {
    final db = await _database();
    await db.insert(_table, {
      'attempt_id': entry.attemptId,
      'lesson_id': entry.lessonId,
      'correct_count': entry.correctCount,
      'total_count': entry.totalCount,
      'time_spent_ms': entry.timeSpent.inMilliseconds,
      'beans_remaining_at_end': entry.beansRemainingAtEnd,
      'client_completed_at': entry.clientCompletedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<PendingSyncEntry>> listPending() async {
    final db = await _database();
    final rows = await db.query(_table, orderBy: 'id ASC');
    return rows.map(_entryFromRow).toList();
  }

  @override
  Future<void> remove(String attemptId) async {
    final db = await _database();
    await db.delete(_table, where: 'attempt_id = ?', whereArgs: [attemptId]);
  }

  @override
  Future<int> count() async {
    final db = await _database();
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return result.first['c'] as int;
  }

  PendingSyncEntry _entryFromRow(Map<String, Object?> row) {
    return PendingSyncEntry(
      attemptId: row['attempt_id'] as String,
      lessonId: row['lesson_id'] as String,
      correctCount: row['correct_count'] as int,
      totalCount: row['total_count'] as int,
      timeSpent: Duration(milliseconds: row['time_spent_ms'] as int),
      beansRemainingAtEnd: row['beans_remaining_at_end'] as int,
      clientCompletedAt: DateTime.parse(row['client_completed_at'] as String),
    );
  }
}
