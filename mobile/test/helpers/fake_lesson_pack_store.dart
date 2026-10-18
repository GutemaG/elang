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
  final Map<String, String> _courseTitles = {};
  final Map<String, String> _courseIds = {};

  /// The course a pack was saved under, or null if none was given.
  String? courseIdOf(String lessonId) => _courseIds[lessonId];

  /// Fixed per-pack size for tests that need a size but don't care about
  /// the exact number -- override per-test by seeding [fakeSizeBytes].
  int fakeSizeBytes = 1024;

  @override
  Future<bool> isDownloaded(String lessonId) async => _packs.containsKey(lessonId);

  @override
  Future<void> save(
    LessonContent content, {
    String? courseId,
    String? courseTitle,
  }) async {
    _packs[content.lessonId] = content;
    if (courseId != null) _courseIds[content.lessonId] = courseId;
    if (courseTitle != null) _courseTitles[content.lessonId] = courseTitle;
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
            courseTitle:
                _courseTitles[content.lessonId] ??
                DownloadedPackSummary.legacyPackCourseTitle,
          ),
        )
        .toList();
  }
}
