import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/auth_config.dart';
import '../models/beans_status.dart';
import '../models/course.dart';
import '../models/due_item.dart';
import '../models/exercise.dart';
import '../models/lesson_completion_result.dart';
import '../models/lesson_content.dart';
import '../models/practice_completion_result.dart';
import '../models/skill_tree.dart';
import 'lesson_api.dart';
import 'lesson_api_exception.dart';
import 'session_repository.dart';

/// Real, HTTP-backed [LessonApi] implementation calling the now-complete
/// `001-lesson-service` endpoints (bolts 004/005): `GET /skill-tree`,
/// `GET /lessons/{id}`, `GET /beans`, `POST /beans/refill`,
/// `POST /lessons/{id}/complete`.
///
/// Every call is authenticated -- unlike [HttpAuthApi] (which has no
/// session yet to attach), this reads the current token from
/// [SessionRepository] fresh on every request rather than once at
/// construction, since this class is built at app start-up, before any
/// sign-in has happened (see `lesson_dependencies.dart`).
///
/// Never logs tokens, request bodies, or response bodies -- only, at most,
/// an HTTP status code -- per `coding-standards.md`'s logging discipline.
class HttpLessonApi implements LessonApi {
  HttpLessonApi({
    required SessionRepository sessionRepository,
    http.Client? client,
    String? baseUrl,
  }) : _sessionRepository = sessionRepository,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final SessionRepository _sessionRepository;
  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final session = await _sessionRepository.getSessionState();
    final token = session.token;
    if (token == null || token.isEmpty) {
      // Unreachable in practice -- the lesson feature is only ever reached
      // via the authenticated `home` route -- but a cheap, correct guard
      // beats sending a request guaranteed to 401 (Technical Design's
      // Decision 4).
      throw const LessonApiException(
        'No session token available',
        errorCode: 'missing_credentials',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<http.Response> _get(String path) async {
    final headers = await _authHeaders();
    try {
      return await _client
          .get(Uri.parse('$_baseUrl$path'), headers: headers)
          .timeout(AuthConfig.requestTimeout);
    } on Object {
      throw const LessonApiException('Network request failed');
    }
  }

  Future<http.Response> _post(String path, {Map<String, dynamic>? body}) async {
    final headers = await _authHeaders();
    try {
      return await _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ).timeout(AuthConfig.requestTimeout);
    } on Object {
      throw const LessonApiException('Network request failed');
    }
  }

  /// Decodes a 200 JSON body, or throws [LessonApiException] for any other
  /// status (parsing the backend's `{error_code, message}` shape when
  /// present).
  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    if (response.statusCode != 200) {
      throw _errorFrom(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const LessonApiException('Malformed response body');
    }
    return decoded;
  }

  LessonApiException _errorFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final errorCode = decoded['error_code'];
        final message = decoded['message'];
        return LessonApiException(
          message is String
              ? message
              : 'Request failed (${response.statusCode})',
          errorCode: errorCode is String ? errorCode : null,
        );
      }
    } on FormatException {
      // Fall through to the generic exception below.
    }
    return LessonApiException('Request failed (${response.statusCode})');
  }

  @override
  Future<SkillTreeResponse> getSkillTree() async {
    final json = _decodeOrThrow(await _get('/api/v1/skill-tree'));
    final skills = (json['skills'] as List).cast<Map<String, dynamic>>();
    final rawCategories = json['categories'] as List?;

    // Older backends (before 009-course-categories) send only the
    // deprecated `unit_title`/`unit_subtitle`: present them as one category
    // holding every skill rather than failing to render.
    final categories = rawCategories == null
        ? [
            SkillCategory(
              id: _legacyCategoryId,
              title: json['unit_title'] as String,
              subtitle: json['unit_subtitle'] as String,
            ),
          ]
        : rawCategories
              .cast<Map<String, dynamic>>()
              .map(
                (c) => SkillCategory(
                  id: c['id'] as String,
                  title: c['title'] as String,
                  subtitle: c['subtitle'] as String,
                ),
              )
              .toList();
    final knownIds = {for (final c in categories) c.id};

    final nodes = skills.map((skill) {
      final categoryId = rawCategories == null
          ? _legacyCategoryId
          : skill['category_id'] as String?;
      // A skill outside every category would silently vanish from the
      // dashboard, so fail clearly instead.
      if (categoryId == null || !knownIds.contains(categoryId)) {
        throw const LessonApiException('Malformed response body');
      }
      return _toSkillTreeNode(skill, categoryId);
    }).toList();

    final rawCourse = json['course'];
    return SkillTreeResponse(
      course: rawCourse is Map<String, dynamic> ? Course.fromJson(rawCourse) : null,
      categories: categories,
      nodes: nodes,
      streakCount: json['streak_count'] as int,
      beans: json['beans'] as int,
      beansMax: json['beans_max'] as int,
      totalXp: json['total_xp'] as int,
    );
  }

  static const _legacyCategoryId = 'legacy-unit';

  SkillTreeNode _toSkillTreeNode(Map<String, dynamic> json, String categoryId) {
    return SkillTreeNode(
      id: json['id'] as String,
      // Falls back to the node's own id only if the backend somehow has no
      // lesson for this skill (shouldn't happen with real content) -- an
      // empty lessonId would make the node untappable in a confusing way,
      // so this at least fails predictably (a 404 on tap) rather than
      // silently.
      lessonId: (json['lesson_id'] as String?) ?? json['id'] as String,
      title: json['title'] as String,
      // No backend equivalent exists for this cosmetic tagline (`Skill`
      // has no subtitle column) -- confirmed unused by every widget that
      // renders a `SkillTreeNode` (see implementation-plan.md's Decision
      // 1), so an empty string has zero visible effect.
      subtitle: '',
      state: _toSkillNodeState(json['state'] as String),
      categoryId: categoryId,
      crownLevel: json['crown_level'] as int,
      contentVersion: _parseContentVersion(json['content_version']),
    );
  }

  /// Bolt 008's `content_version` field, present on every skill/lesson
  /// entry since then -- `null` only defensively, for an older/mocked
  /// backend response that doesn't include it yet.
  DateTime? _parseContentVersion(Object? raw) {
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  SkillNodeState _toSkillNodeState(String state) => switch (state) {
    'locked' => SkillNodeState.locked,
    'active' => SkillNodeState.active,
    'completed' => SkillNodeState.completed,
    _ => throw LessonApiException('Unknown skill state: $state'),
  };

  @override
  Future<LessonContent> startLesson(String lessonId) async {
    // Two parallel requests, not one -- the lesson-content endpoint has no
    // beans field (bolt 004's contract never included it); merged into one
    // `LessonContent` here so no caller needs to know it took two calls.
    // Still satisfies the Performance NFR: both happen once, at lesson
    // start, never repeated per exercise (Technical Design's Decision 2).
    final results = await Future.wait([
      _get('/api/v1/lessons/$lessonId'),
      _get('/api/v1/beans'),
    ]);
    final lessonJson = _decodeOrThrow(results[0]);
    final beansJson = _decodeOrThrow(results[1]);

    final lesson = lessonJson['lesson'] as Map<String, dynamic>;
    final served = (lessonJson['exercises'] as List)
        .cast<Map<String, dynamic>>();
    // Skip, rather than throw, on a type this build does not know — see
    // `LessonContent.unrenderableCount`. One unknown exercise used to take
    // the entire lesson down.
    final exercises = <Exercise>[];
    for (final json in served) {
      final exercise = _toExerciseOrNull(json);
      if (exercise != null) exercises.add(exercise);
    }

    return LessonContent(
      lessonId: lesson['id'] as String,
      skillId: lesson['skill_id'] as String,
      title: lesson['title'] as String,
      exercises: exercises,
      beansAtStart: beansJson['beans'] as int,
      beansMax: beansJson['beans_max'] as int,
      contentVersion: _parseContentVersion(lessonJson['content_version']),
      unrenderableCount: served.length - exercises.length,
    );
  }

  /// `null` when this build has no case for the exercise's type.
  ///
  /// Deliberately not a thrown exception: an unknown type is expected
  /// during the window between a backend adding a type and the client
  /// catching up, and it is not a reason to make the lesson unplayable.
  /// A malformed exercise of a *known* type still throws, since that is a
  /// genuine contract violation rather than a version skew.
  Exercise? _toExerciseOrNull(Map<String, dynamic> json) {
    const known = {
      'multiple_choice',
      'listening',
      'sentence_construction',
      'match_pairs',
      'gap_fill',
    };
    if (!known.contains(json['type'] as String)) return null;
    return _toExercise(json);
  }

  Exercise _toExercise(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final id = json['id'] as String;
    switch (type) {
      case 'multiple_choice':
        final choices = (json['choices'] as List).cast<Map<String, dynamic>>();
        final correctChoiceId = json['correct_choice_id'] as String;
        return MultipleChoiceExercise(
          id: id,
          // The backend's seed content asks "How do you say 'X'?" (an
          // English instruction) with Amharic answer choices -- the
          // reverse direction from the original fake's Amharic-prompt/
          // English-gloss design. Mapped onto `prompt` (the main, large
          // text) rather than `promptTranslation` so it still reads as a
          // complete, sensible question; `promptTranslation` is left
          // empty since the backend has no second text field to supply
          // it from. Flagged here per the story's "explicit finding, not
          // silently patched" guidance -- a real content-authoring
          // decision, not a bug.
          prompt: json['prompt'] as String,
          promptTranslation: '',
          options: choices.map((c) => c['text'] as String).toList(),
          correctOptionIndex: choices.indexWhere(
            (c) => c['id'] == correctChoiceId,
          ),
        );
      case 'listening':
        final choices = (json['choices'] as List).cast<Map<String, dynamic>>();
        final correctChoiceId = json['correct_choice_id'] as String;
        return ListeningExercise(
          id: id,
          audioUrl: json['audio_url'] as String,
          instruction: json['prompt'] as String,
          options: choices.map((c) => c['text'] as String).toList(),
          correctOptionIndex: choices.indexWhere(
            (c) => c['id'] == correctChoiceId,
          ),
        );
      case 'sentence_construction':
        final wordBank = (json['word_bank'] as List)
            .cast<Map<String, dynamic>>();
        final textById = {
          for (final tile in wordBank)
            tile['id'] as String: tile['text'] as String,
        };
        final correctSequence = (json['correct_sequence'] as List)
            .cast<String>();
        return SentenceConstructionExercise(
          id: id,
          promptTranslation: json['prompt'] as String,
          wordBank: wordBank.map((tile) => tile['text'] as String).toList(),
          correctSentence: correctSequence
              .map((tileId) => textById[tileId]!)
              .toList(),
        );
      case 'match_pairs':
        final leftTiles = (json['left_tiles'] as List)
            .cast<Map<String, dynamic>>();
        final rightTiles = (json['right_tiles'] as List)
            .cast<Map<String, dynamic>>();
        final correctPairs = (json['correct_pairs'] as List)
            .cast<List<dynamic>>();
        return MatchPairsExercise(
          id: id,
          prompt: json['prompt'] as String,
          leftTiles: leftTiles
              .map(
                (t) => MatchPairsTile(
                  id: t['id'] as String,
                  text: t['text'] as String,
                ),
              )
              .toList(),
          rightTiles: rightTiles
              .map(
                (t) => MatchPairsTile(
                  id: t['id'] as String,
                  text: t['text'] as String,
                ),
              )
              .toList(),
          correctPairs: {
            for (final pair in correctPairs)
              pair[0] as String: pair[1] as String,
          },
        );
      case 'gap_fill':
        final choices = (json['choices'] as List).cast<Map<String, dynamic>>();
        final correctChoiceId = json['correct_choice_id'] as String;
        return GapFillExercise(
          id: id,
          prompt: json['prompt'] as String,
          sentenceBefore: json['sentence_before'] as String,
          sentenceAfter: json['sentence_after'] as String,
          options: choices.map((c) => c['text'] as String).toList(),
          // Same id-to-index conversion the choice-based types use.
          correctOptionIndex: choices.indexWhere(
            (c) => c['id'] == correctChoiceId,
          ),
        );
      default:
        throw LessonApiException('Unknown exercise type: $type');
    }
  }

  @override
  Future<LessonCompletionResult> completeLesson({
    required String lessonId,
    required String attemptId,
    required int correctCount,
    required int totalCount,
    required Duration timeSpent,
    required int beansRemainingAtEnd,
    required DateTime clientCompletedAt,
    List<String> missedExerciseIds = const [],
  }) async {
    final json = _decodeOrThrow(
      await _post(
        '/api/v1/lessons/$lessonId/complete',
        body: {
          'attempt_id': attemptId,
          'correct_count': correctCount,
          'total_count': totalCount,
          'time_spent_seconds': timeSpent.inMilliseconds / 1000,
          'client_completed_at': clientCompletedAt.toUtc().toIso8601String(),
          'missed_exercise_ids': missedExerciseIds,
        },
      ),
    );
    return LessonCompletionResult(
      xpEarned: json['xp_earned'] as int,
      dailyXpTotal: json['daily_xp_total'] as int,
      dailyXpTarget: json['daily_xp_target'] as int,
      streakCount: json['streak_count'] as int,
      streakIncreasedToday: json['streak_increased_today'] as bool,
      accuracyPercent: json['accuracy_percent'] as int,
      correctCount: json['correct_count'] as int,
      totalCount: json['total_count'] as int,
      timeSpent: timeSpent,
      skillUnlockedTitle: json['skill_unlocked_title'] as String?,
      crownLevel: json['crown_level'] as int?,
      crownLeveledUp: json['crown_leveled_up'] as bool,
      streakFreezeUnlocked: json['streak_freeze_unlocked'] as bool,
      // Absent from a backend older than reviews.
      isReview: json['is_review'] as bool? ?? false,
    );
  }

  @override
  Future<BeansStatus> getBeansStatus() async {
    final json = _decodeOrThrow(await _get('/api/v1/beans'));
    final nextBeanAtRaw = json['next_bean_at'];
    return BeansStatus(
      beans: json['beans'] as int,
      beansMax: json['beans_max'] as int,
      nextBeanAt: nextBeanAtRaw is String
          ? DateTime.tryParse(nextBeanAtRaw)
          : null,
      regenMinutesPerBean: json['regen_minutes_per_bean'] as int,
      amoleBalance: json['amole_balance'] as int,
      refillCostAmole: json['refill_cost_amole'] as int,
    );
  }

  @override
  Future<RefillResult> refillBeansWithAmole() async {
    final response = await _post('/api/v1/beans/refill');
    if (response.statusCode == 422) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          decoded['error_code'] == 'insufficient_amole') {
        return const RefillFailure(RefillFailureReason.insufficientAmole);
      }
    }
    final json = _decodeOrThrow(response);
    return RefillSuccess(
      newBeans: json['beans'] as int,
      newAmoleBalance: json['amole_balance'] as int,
    );
  }

  @override
  Future<int> getDueCount() async {
    final json = _decodeOrThrow(await _get('/api/v1/practice/due-count'));
    return json['due_count'] as int;
  }

  @override
  Future<List<DueItem>> getDueItems({int limit = 20}) async {
    final json = _decodeOrThrow(
      await _get('/api/v1/practice/due-items?limit=$limit'),
    );
    final items = (json['items'] as List).cast<Map<String, dynamic>>();
    return items.map(_toDueItem).toList();
  }

  DueItem _toDueItem(Map<String, dynamic> json) {
    return DueItem(
      vocabItemId: json['vocab_item_id'] as String,
      word: json['word'] as String,
      translation: json['translation'] as String,
      exercise: _toExercise(json['exercise'] as Map<String, dynamic>),
      boxLevel: json['box_level'] as int,
      nextReviewAt: DateTime.parse(json['next_review_at'] as String),
    );
  }

  @override
  Future<PracticeCompletionResult> completePracticeSession({
    required String sessionId,
    required List<PracticeResult> results,
    required Duration timeSpent,
  }) async {
    final json = _decodeOrThrow(
      await _post(
        '/api/v1/practice/complete',
        body: {
          'session_id': sessionId,
          'results': results
              .map(
                (r) => {'vocab_item_id': r.vocabItemId, 'correct': r.correct},
              )
              .toList(),
          'time_spent_seconds': timeSpent.inMilliseconds / 1000,
        },
      ),
    );
    return PracticeCompletionResult(
      xpEarned: json['xp_earned'] as int,
      amoleEarned: json['amole_earned'] as int,
      correctCount: json['correct_count'] as int,
      totalCount: json['total_count'] as int,
      accuracyPercent: json['accuracy_percent'] as int,
    );
  }
}
