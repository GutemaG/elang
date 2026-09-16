import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/downloaded_pack_summary.dart';
import '../models/exercise.dart';
import '../models/lesson_content.dart';

/// Local persistence for a downloaded lesson pack (009-offline-caching-and-
/// sync-ui, story 001).
///
/// Stores the fully-resolved [LessonContent] (same shape [LessonApi.startLesson]
/// already returns), not raw backend JSON -- avoids a second parsing code
/// path for the offline case. [save] expects any [ListeningExercise.audioUrl]
/// values to already be local file paths, not remote URLs -- rewriting a
/// remote URL to a local path after downloading the audio is
/// [LessonPackDownloader]'s job, not this store's.
///
/// Kept as an interface (mirrors [ConnectivityMonitor]/[LessonAudioPlayer])
/// so widget tests never touch a real database.
abstract class LessonPackStore {
  Future<bool> isDownloaded(String lessonId);

  Future<void> save(LessonContent content);

  /// `null` if [lessonId] was never downloaded (or was deleted).
  Future<LessonContent?> load(String lessonId);

  Future<void> delete(String lessonId);

  /// Every currently-downloaded lesson id, for `flutter test` assertions
  /// and as the basis for [listDownloadedPacks].
  Future<List<String>> listDownloadedLessonIds();

  /// One summary (title + approximate on-device size) per downloaded pack,
  /// for the download-management screen
  /// (010-offline-caching-and-sync-ui, story 005).
  Future<List<DownloadedPackSummary>> listDownloadedPacks();
}

/// Real implementation backed by `sqflite`. One row per downloaded lesson;
/// the pack's content is stored as a single JSON blob column rather than
/// a normalized schema -- there's exactly one shape to round-trip
/// ([LessonContent]), so normalizing into multiple tables would add
/// complexity with no query benefit (same "single JSON-backed shape" call
/// the backend's own ADR-3 made for its `exercises` table).
class SqfliteLessonPackStore implements LessonPackStore {
  static const _dbFileName = 'lesson_packs.db';
  static const _table = 'lesson_packs';

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
          'lesson_id TEXT PRIMARY KEY, '
          'content TEXT NOT NULL, '
          'downloaded_at TEXT NOT NULL'
          ')',
        );
      },
    );
    _db = db;
    return db;
  }

  @override
  Future<bool> isDownloaded(String lessonId) async {
    final db = await _database();
    final rows = await db.query(
      _table,
      columns: const ['lesson_id'],
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> save(LessonContent content) async {
    final db = await _database();
    await db.insert(_table, {
      'lesson_id': content.lessonId,
      'content': jsonEncode(_contentToJson(content)),
      'downloaded_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<LessonContent?> load(String lessonId) async {
    final db = await _database();
    final rows = await db.query(
      _table,
      columns: const ['content'],
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['content'] as String) as Map<String, dynamic>;
    return _contentFromJson(json);
  }

  @override
  Future<void> delete(String lessonId) async {
    // Deletes each downloaded audio file *before* the DB row, not just the
    // row -- fixes a leak from 009-offline-caching-and-sync-ui where
    // deleting a pack never freed the audio it had downloaded to disk.
    final cached = await load(lessonId);
    if (cached != null) {
      for (final exercise in cached.exercises) {
        if (exercise is ListeningExercise) {
          final file = File(exercise.audioUrl);
          if (await file.exists()) await file.delete();
        }
      }
    }
    final db = await _database();
    await db.delete(_table, where: 'lesson_id = ?', whereArgs: [lessonId]);
  }

  @override
  Future<List<String>> listDownloadedLessonIds() async {
    final db = await _database();
    final rows = await db.query(_table, columns: const ['lesson_id']);
    return rows.map((row) => row['lesson_id'] as String).toList();
  }

  @override
  Future<List<DownloadedPackSummary>> listDownloadedPacks() async {
    final db = await _database();
    final rows = await db.query(_table, columns: const ['lesson_id', 'content']);
    final summaries = <DownloadedPackSummary>[];
    for (final row in rows) {
      final contentJson = row['content'] as String;
      final decoded = jsonDecode(contentJson) as Map<String, dynamic>;
      final content = _contentFromJson(decoded);
      var sizeBytes = contentJson.length;
      for (final exercise in content.exercises) {
        if (exercise is ListeningExercise) {
          final file = File(exercise.audioUrl);
          if (await file.exists()) sizeBytes += await file.length();
        }
      }
      summaries.add(
        DownloadedPackSummary(
          lessonId: row['lesson_id'] as String,
          title: content.title,
          approximateSizeBytes: sizeBytes,
        ),
      );
    }
    return summaries;
  }

  Map<String, dynamic> _contentToJson(LessonContent content) => {
    'lessonId': content.lessonId,
    'skillId': content.skillId,
    'title': content.title,
    'beansAtStart': content.beansAtStart,
    'beansMax': content.beansMax,
    'contentVersion': content.contentVersion?.toIso8601String(),
    'exercises': content.exercises.map(_exerciseToJson).toList(),
  };

  LessonContent _contentFromJson(Map<String, dynamic> json) {
    final rawVersion = json['contentVersion'] as String?;
    return LessonContent(
      lessonId: json['lessonId'] as String,
      skillId: json['skillId'] as String,
      title: json['title'] as String,
      beansAtStart: json['beansAtStart'] as int,
      beansMax: json['beansMax'] as int,
      contentVersion: rawVersion == null ? null : DateTime.tryParse(rawVersion),
      exercises: (json['exercises'] as List)
          .cast<Map<String, dynamic>>()
          .map(_exerciseFromJson)
          .toList(),
    );
  }

  Map<String, dynamic> _exerciseToJson(Exercise exercise) => switch (exercise) {
    MultipleChoiceExercise e => {
      'type': 'multiple_choice',
      'id': e.id,
      'prompt': e.prompt,
      'promptTranslation': e.promptTranslation,
      'options': e.options,
      'correctOptionIndex': e.correctOptionIndex,
    },
    ListeningExercise e => {
      'type': 'listening',
      'id': e.id,
      'audioUrl': e.audioUrl,
      'instruction': e.instruction,
      'options': e.options,
      'correctOptionIndex': e.correctOptionIndex,
    },
    SentenceConstructionExercise e => {
      'type': 'sentence_construction',
      'id': e.id,
      'promptTranslation': e.promptTranslation,
      'wordBank': e.wordBank,
      'correctSentence': e.correctSentence,
    },
  };

  Exercise _exerciseFromJson(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'multiple_choice':
        return MultipleChoiceExercise(
          id: json['id'] as String,
          prompt: json['prompt'] as String,
          promptTranslation: json['promptTranslation'] as String,
          options: (json['options'] as List).cast<String>(),
          correctOptionIndex: json['correctOptionIndex'] as int,
        );
      case 'listening':
        return ListeningExercise(
          id: json['id'] as String,
          audioUrl: json['audioUrl'] as String,
          instruction: json['instruction'] as String,
          options: (json['options'] as List).cast<String>(),
          correctOptionIndex: json['correctOptionIndex'] as int,
        );
      case 'sentence_construction':
        return SentenceConstructionExercise(
          id: json['id'] as String,
          promptTranslation: json['promptTranslation'] as String,
          wordBank: (json['wordBank'] as List).cast<String>(),
          correctSentence: (json['correctSentence'] as List).cast<String>(),
        );
      default:
        throw StateError('Unknown exercise type in cached pack: ${json['type']}');
    }
  }
}
