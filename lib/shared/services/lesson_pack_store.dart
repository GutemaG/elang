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

  /// [courseId]/[courseTitle] record which course the pack belongs to
  /// (010-multi-language-courses); omit them when unknown.
  Future<void> save(
    LessonContent content, {
    String? courseId,
    String? courseTitle,
  });

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
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $_table ('
          'lesson_id TEXT PRIMARY KEY, '
          'content TEXT NOT NULL, '
          'downloaded_at TEXT NOT NULL, '
          'course_id TEXT, '
          'course_title TEXT'
          ')',
        );
      },
      // 010-multi-language-courses: a pack downloaded before this has no
      // course; NULL is read back as English to Amharic, so nothing is lost.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN course_id TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN course_title TEXT');
        }
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
  Future<void> save(
    LessonContent content, {
    String? courseId,
    String? courseTitle,
  }) async {
    final db = await _database();
    await db.insert(_table, {
      'lesson_id': content.lessonId,
      'content': jsonEncode(packContentToJson(content)),
      'downloaded_at': DateTime.now().toUtc().toIso8601String(),
      'course_id': courseId,
      'course_title': courseTitle,
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
    return packContentFromJson(json);
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
    final rows = await db.query(
      _table,
      columns: const ['lesson_id', 'content', 'course_title'],
    );
    final summaries = <DownloadedPackSummary>[];
    for (final row in rows) {
      final contentJson = row['content'] as String;
      final decoded = jsonDecode(contentJson) as Map<String, dynamic>;
      final content = packContentFromJson(decoded);
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
          courseTitle:
              row['course_title'] as String? ??
              DownloadedPackSummary.legacyPackCourseTitle,
        ),
      );
    }
    return summaries;
  }
}

/// The pack's JSON mapping, deliberately at the top level rather than
/// private to [SqfliteLessonPackStore].
///
/// These are pure functions with no database in them, but while they were
/// private methods the only way to reach them was through `sqflite`, which
/// a `flutter test` cannot open — so the round trip every downloaded pack
/// depends on had no test at all, for any exercise type. That matters most
/// here of anywhere: [packExerciseToJson] is a switch over a sealed class
/// and will not compile if a type is missed, but [packExerciseFromJson] is
/// a switch over a *string* and fails only at runtime, inside a downloaded
/// pack, offline (bolt 031).
Map<String, dynamic> packContentToJson(LessonContent content) => {
  'lessonId': content.lessonId,
  'skillId': content.skillId,
  'title': content.title,
  'beansAtStart': content.beansAtStart,
  'beansMax': content.beansMax,
  'contentVersion': content.contentVersion?.toIso8601String(),
  // Must round-trip: a pack only ever stores the exercises this build could
  // render, so without this an offline completion would report a
  // `total_count` lower than the server's and be rejected on sync.
  'unrenderableCount': content.unrenderableCount,
  'exercises': content.exercises.map(packExerciseToJson).toList(),
};

LessonContent packContentFromJson(Map<String, dynamic> json) {
  final rawVersion = json['contentVersion'] as String?;
  return LessonContent(
    lessonId: json['lessonId'] as String,
    skillId: json['skillId'] as String,
    title: json['title'] as String,
    beansAtStart: json['beansAtStart'] as int,
    beansMax: json['beansMax'] as int,
    contentVersion: rawVersion == null ? null : DateTime.tryParse(rawVersion),
    // Absent in packs written before this field existed; those packs were
    // downloaded by a build that dropped nothing, so zero is correct.
    unrenderableCount: (json['unrenderableCount'] as int?) ?? 0,
    exercises: (json['exercises'] as List)
        .cast<Map<String, dynamic>>()
        .map(packExerciseFromJson)
        .toList(),
  );
}

Map<String, dynamic> packExerciseToJson(Exercise exercise) => switch (exercise) {
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
  MatchPairsExercise e => {
    'type': 'match_pairs',
    'id': e.id,
    'prompt': e.prompt,
    'leftTiles': e.leftTiles.map((t) => {'id': t.id, 'text': t.text}).toList(),
    'rightTiles': e.rightTiles.map((t) => {'id': t.id, 'text': t.text}).toList(),
    'correctPairs': e.correctPairs,
  },
  // Unlike every other seam a new exercise type touches, this map and its
  // matching `case` below are NOT checked by the compiler in both
  // directions: the switch above is exhaustive over the sealed class, but
  // `packExerciseFromJson` is a string switch that would simply throw at
  // runtime, inside a downloaded pack, offline. Change the two together.
  GapFillExercise e => {
    'type': 'gap_fill',
    'id': e.id,
    'prompt': e.prompt,
    'sentenceBefore': e.sentenceBefore,
    'sentenceAfter': e.sentenceAfter,
    'options': e.options,
    'correctOptionIndex': e.correctOptionIndex,
  },
  // Bolt 053: the picture addresses are kept as they came. Downloading the
  // pictures into a pack, and rewriting these to local files, is bolt 054's.
  ImageChoiceExercise e => {
    'type': 'image_choice',
    'id': e.id,
    'prompt': e.prompt,
    'choices': e.choices.map(_pictureToJson).toList(),
    'correctOptionIndex': e.correctOptionIndex,
  },
  AudioImageChoiceExercise e => {
    'type': 'audio_image_choice',
    'id': e.id,
    'audioUrl': e.audioUrl,
    'instruction': e.instruction,
    'choices': e.choices.map(_pictureToJson).toList(),
    'correctOptionIndex': e.correctOptionIndex,
  },
};

Map<String, dynamic> _pictureToJson(PictureChoice picture) => {
  'imageUrl': picture.imageUrl,
  'altText': picture.altText,
};

List<PictureChoice> _picturesFromJson(Object? json) => (json as List)
    .cast<Map<String, dynamic>>()
    .map(
      (p) => PictureChoice(
        imageUrl: p['imageUrl'] as String,
        altText: p['altText'] as String,
      ),
    )
    .toList();

Exercise packExerciseFromJson(Map<String, dynamic> json) {
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
    case 'match_pairs':
      final leftTiles = (json['leftTiles'] as List).cast<Map<String, dynamic>>();
      final rightTiles = (json['rightTiles'] as List).cast<Map<String, dynamic>>();
      return MatchPairsExercise(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        leftTiles: leftTiles
            .map((t) => MatchPairsTile(id: t['id'] as String, text: t['text'] as String))
            .toList(),
        rightTiles: rightTiles
            .map((t) => MatchPairsTile(id: t['id'] as String, text: t['text'] as String))
            .toList(),
        correctPairs: (json['correctPairs'] as Map).cast<String, String>(),
      );
    case 'gap_fill':
      return GapFillExercise(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        sentenceBefore: json['sentenceBefore'] as String,
        sentenceAfter: json['sentenceAfter'] as String,
        options: (json['options'] as List).cast<String>(),
        correctOptionIndex: json['correctOptionIndex'] as int,
      );
    case 'image_choice':
      return ImageChoiceExercise(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        choices: _picturesFromJson(json['choices']),
        correctOptionIndex: json['correctOptionIndex'] as int,
      );
    case 'audio_image_choice':
      return AudioImageChoiceExercise(
        id: json['id'] as String,
        audioUrl: json['audioUrl'] as String,
        instruction: json['instruction'] as String,
        choices: _picturesFromJson(json['choices']),
        correctOptionIndex: json['correctOptionIndex'] as int,
      );
    default:
      throw StateError('Unknown exercise type in cached pack: ${json['type']}');
  }
}
