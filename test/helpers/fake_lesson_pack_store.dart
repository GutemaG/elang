// In-memory stand-in for [LessonPackStore], used across widget tests so
// offline lesson-taking can be exercised without a real sqflite database.
//
// Mocking here is at the plugin boundary only, per `coding-standards.md`'s
// "mock at the network/DB boundary only" testing convention.

import 'package:elang/shared/models/downloaded_pack_summary.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/lesson_pack_store.dart';

class FakeLessonPackStore implements LessonPackStore {
  final Map<String, LessonContent> _packs = {};

  /// Fixed per-pack size for tests that need a size but don't care about
  /// the exact number -- override per-test by seeding [fakeSizeBytes].
  int fakeSizeBytes = 1024;

  @override
  Future<bool> isDownloaded(String lessonId) async => _packs.containsKey(lessonId);

  @override
  Future<void> save(LessonContent content) async {
    _packs[content.lessonId] = content;
  }

  @override
  Future<LessonContent?> load(String lessonId) async => _packs[lessonId];

  @override
  Future<void> delete(String lessonId) async {
    _packs.remove(lessonId);
  }

  @override
  Future<List<String>> listDownloadedLessonIds() async => _packs.keys.toList();

  @override
  Future<List<DownloadedPackSummary>> listDownloadedPacks() async {
    return _packs.values
        .map(
          (content) => DownloadedPackSummary(
            lessonId: content.lessonId,
            title: content.title,
            approximateSizeBytes: fakeSizeBytes,
          ),
        )
        .toList();
  }
}
