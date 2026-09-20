import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/course.dart';
import '../models/skill_tree.dart';

/// A cached skill tree plus the account-wide Amole balance seen with it, so
/// the dashboard can render offline (010-multi-language-courses, story 003).
class CachedDashboard {
  const CachedDashboard({required this.tree, required this.amoleBalance});

  final SkillTreeResponse tree;
  final int amoleBalance;
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
  }) => _mutate((state) async {
    final dashboards = _map(state['dashboards']);
    dashboards[courseId] = {
      'tree': tree.toJson(),
      'amole_balance': amoleBalance,
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
    return CachedDashboard(tree: tree, amoleBalance: amole);
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

  static Map<String, dynamic> _map(Object? raw) =>
      raw is Map<String, dynamic> ? raw : <String, dynamic>{};
}

/// Real implementation: one JSON file in the app documents directory (the
/// same place lesson packs live). An unreadable or corrupt file reads as an
/// empty cache, never an error.
class FileCourseCacheStore extends MapBackedCourseCacheStore {
  static const _fileName = 'course_cache.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<Map<String, dynamic>> readState() async {
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
