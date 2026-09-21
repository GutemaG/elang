import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/course.dart';
import '../models/lesson_content.dart';
import '../models/skill_tree.dart';
import 'lesson_pack_store.dart';

/// A cached skill tree plus the account-wide Amole balance seen with it, so
/// the dashboard can render offline (010-multi-language-courses, story 003).
class CachedDashboard {
  const CachedDashboard({
    required this.tree,
    required this.amoleBalance,
    this.dueCount = 0,
  });

  final SkillTreeResponse tree;
  final int amoleBalance;

  /// The Practice badge's count as last seen; 0 for an entry saved before
  /// this was stored.
  final int dueCount;
}

/// A lesson's content as last fetched, so opening it again is instant
/// instead of a round trip.
///
/// [skillVersion] is the owning skill node's `contentVersion` when the
/// content was fetched. The dashboard compares it with the node's current
/// one: a mismatch means the lesson was edited server-side and the copy must
/// not be played, because the server would reject its `total_count`.
class CachedLesson {
  const CachedLesson({required this.content, this.skillVersion});

  final LessonContent content;
  final DateTime? skillVersion;

  /// Whether this copy still matches a node whose version is [current].
  /// Unknown on either side counts as fresh: there is nothing to compare.
  bool isFreshFor(DateTime? current) {
    final saved = skillVersion;
    if (current == null || saved == null) return true;
    return saved.isAtSameMomentAs(current);
  }
}

/// Local, per-course cache that lets the app show a course and switch
/// courses while offline.
///
/// Holds one skill tree per course id (so course A's tree is never shown for
/// course B), the last course list, the last known active course, and an
/// offline switch that still has to be sent to the server.
///
/// Kept as an interface (mirrors `LessonPackStore`) so widget tests never
/// touch the file system.
abstract class CourseCacheStore {
  Future<void> saveDashboard(
    String courseId,
    SkillTreeResponse tree, {
    required int amoleBalance,
    int dueCount = 0,
  });

  /// `null` if [courseId] was never cached (or the cache is unreadable).
  Future<CachedDashboard?> loadDashboard(String courseId);

  /// Every course with a saved dashboard.
  ///
  /// A dashboard is written after each successful load, so this is exactly
  /// "the courses this learner has opened" -- which is what the dashboard's
  /// course rail is built from (011-dashboard-ui-polish, ADR-15).
  Future<List<String>> cachedCourseIds();

  Future<void> saveCourseList(CourseList list);

  Future<CourseList?> loadCourseList();

  /// The course last known to be active: the server's, or the one chosen
  /// offline. `null` before anything has been cached.
  Future<String?> activeCourseId();

  /// Records [courseId] as active. With [pendingSync] the choice was made
  /// offline and still has to reach the server.
  Future<void> setActiveCourseId(String courseId, {bool pendingSync = false});

  /// The offline-chosen course not yet sent to the server, or `null`.
  Future<String?> pendingSwitchCourseId();

  Future<void> clearPendingSwitch();

  /// Stores [content] as the latest copy of its lesson. Its listening audio
  /// stays remote -- this is a speed cache, not a download (see
  /// `LessonPackStore` for that).
  Future<void> saveLesson(LessonContent content, {DateTime? skillVersion});

  /// `null` if the lesson was never fetched (or the cache is unreadable).
  Future<CachedLesson?> loadLesson(String lessonId);
}

/// Shared logic over one JSON-shaped state map; subclasses only say where the
/// map lives. Writes are serialised so overlapping read-modify-write calls
/// (a tree save and an active-course update) cannot lose each other's data.
abstract class MapBackedCourseCacheStore implements CourseCacheStore {
  Future<Map<String, dynamic>> readState();
  Future<void> writeState(Map<String, dynamic> state);

  Future<void> _lock = Future<void>.value();

  Future<T> _mutate<T>(Future<T> Function(Map<String, dynamic> state) change) {
    final result = _lock.then((_) async {
      final state = await readState();
      final value = await change(state);
      await writeState(state);
      return value;
    });
    _lock = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, dynamic>> _read() {
    final result = _lock.then((_) => readState());
    return result;
  }

  @override
  Future<void> saveDashboard(
    String courseId,
    SkillTreeResponse tree, {
    required int amoleBalance,
    int dueCount = 0,
  }) => _mutate((state) async {
    final dashboards = _map(state['dashboards']);
    dashboards[courseId] = {
      'tree': tree.toJson(),
      'amole_balance': amoleBalance,
      'due_count': dueCount,
    };
    state['dashboards'] = dashboards;
  });

  @override
  Future<CachedDashboard?> loadDashboard(String courseId) async {
    final entry = _map((await _read())['dashboards'])[courseId];
    if (entry is! Map<String, dynamic>) return null;
    final tree = SkillTreeResponse.fromJson(entry['tree']);
    final amole = entry['amole_balance'];
    if (tree == null || amole is! int) return null;
    final due = entry['due_count'];
    return CachedDashboard(
      tree: tree,
      amoleBalance: amole,
      dueCount: due is int ? due : 0,
    );
  }

  @override
  Future<List<String>> cachedCourseIds() async =>
      _map((await _read())['dashboards']).keys.toList();

  @override
  Future<void> saveCourseList(CourseList list) =>
      _mutate((state) async => state['course_list'] = list.toJson());

  @override
  Future<CourseList?> loadCourseList() async =>
      CourseList.fromJson((await _read())['course_list']);

  @override
  Future<String?> activeCourseId() async {
    final value = (await _read())['active_course_id'];
    return value is String ? value : null;
  }

  @override
  Future<void> setActiveCourseId(String courseId, {bool pendingSync = false}) =>
      _mutate((state) async {
        state['active_course_id'] = courseId;
        if (pendingSync) {
          state['pending_switch'] = courseId;
        } else {
          state.remove('pending_switch');
        }
      });

  @override
  Future<String?> pendingSwitchCourseId() async {
    final value = (await _read())['pending_switch'];
    return value is String ? value : null;
  }

  @override
  Future<void> clearPendingSwitch() =>
      _mutate((state) async => state.remove('pending_switch'));

  @override
  Future<void> saveLesson(LessonContent content, {DateTime? skillVersion}) =>
      _mutate((state) async {
        final lessons = _map(state['lessons']);
        lessons[content.lessonId] = {
          'content': packContentToJson(content),
          'skill_version': skillVersion?.toUtc().toIso8601String(),
        };
        state['lessons'] = lessons;
      });

  @override
  Future<CachedLesson?> loadLesson(String lessonId) async {
    final entry = _map((await _read())['lessons'])[lessonId];
    if (entry is! Map<String, dynamic>) return null;
    try {
      final content = packContentFromJson(
        entry['content'] as Map<String, dynamic>,
      );
      final version = entry['skill_version'];
      return CachedLesson(
        content: content,
        skillVersion: version is String ? DateTime.tryParse(version) : null,
      );
    } on Object {
      // A copy this build cannot read is just a cache miss.
      return null;
    }
  }

  static Map<String, dynamic> _map(Object? raw) =>
      raw is Map<String, dynamic> ? raw : <String, dynamic>{};
}

/// Real implementation: one JSON file in the app documents directory (the
/// same place lesson packs live). An unreadable or corrupt file reads as an
/// empty cache, never an error.
///
/// The file is read once and then kept in memory: this instance is its only
/// writer, and every screen change reads it, so decoding it from disk each
/// time would be the slow part of a cache meant to make navigation instant.
class FileCourseCacheStore extends MapBackedCourseCacheStore {
  static const _fileName = 'course_cache.json';

  Map<String, dynamic>? _memo;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<Map<String, dynamic>> readState() async =>
      _memo ??= await _readFile();

  Future<Map<String, dynamic>> _readFile() async {
    try {
      final file = await _file();
      if (!await file.exists()) return <String, dynamic>{};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on Object {
      return <String, dynamic>{};
    }
  }

  @override
  Future<void> writeState(Map<String, dynamic> state) async {
    _memo = state;
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(state));
    } on Object {
      // A cache that cannot be written just means no offline copy; the
      // online flow is unaffected.
    }
  }
}

/// In-memory implementation for tests. Stores the JSON-encoded state so it
/// exercises the same (de)serialisation as the file store.
class InMemoryCourseCacheStore extends MapBackedCourseCacheStore {
  String _json = '{}';

  /// Replaces the stored text, e.g. with garbage, to test a corrupt cache.
  set rawJson(String value) => _json = value;

  @override
  Future<Map<String, dynamic>> readState() async {
    try {
      final decoded = jsonDecode(_json);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on Object {
      return <String, dynamic>{};
    }
  }

  @override
  Future<void> writeState(Map<String, dynamic> state) async {
    _json = jsonEncode(state);
  }
}
