import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../shared/models/exercise.dart';
import '../../../shared/models/lesson_completion_result.dart';
import '../../../shared/models/lesson_content.dart';
import '../../../shared/models/pending_sync_entry.dart';
import '../../../shared/models/practice_completion_result.dart';
import '../../../shared/services/answer_feedback_player.dart';
import '../../../shared/services/lesson_api.dart';
import '../../../shared/services/lesson_api_exception.dart';
import '../../../shared/services/sync_engine.dart';

/// How the current exercise's tile(s) should render.
enum TileFeedback { none, correct, incorrect }

/// The unit brief's `InLessonState`: everything about the lesson currently
/// being taken, held client-side for the whole attempt after a single
/// `startLesson` fetch — never re-fetched per exercise.
///
/// A `ChangeNotifier` (matching `SignInController`'s pattern from
/// `002-auth-onboarding-ui`) so the concurrency/phase logic lives in one
/// testable unit, separate from widget-tree code.
class LessonController extends ChangeNotifier {
  LessonController({
    required this._lessonApi,
    required this._feedbackPlayer,
    required this._syncEngine,
    required LessonContent content,
    this.startedOffline = false,
    this.isPractice = false,
    this.isReview = false,
    Map<String, String>? vocabItemIdByExerciseId,
  }) : _content = content,
       _beansRemaining = content.beansAtStart,
       _queue = List<int>.generate(content.exercises.length, (i) => i),
       _attemptId = _generateAttemptId(),
       _vocabItemIdByExerciseId = vocabItemIdByExerciseId ?? const {};

  final LessonApi _lessonApi;
  final AnswerFeedbackPlayer _feedbackPlayer;
  final SyncEngine _syncEngine;
  final LessonContent _content;

  /// The exercise count the *server* believes this lesson has, which is
  /// not `exercises.length` when this build could not render one of them
  /// (see `LessonContent.unrenderableCount`). `complete_lesson` rejects a
  /// `total_count` that disagrees with its own count, so reporting the
  /// played-through count would 422 at the very end of a lesson.
  int get _servedCount => exercises.length + _content.unrenderableCount;

  /// Skipped exercises count as correct. They were never put in front of
  /// the learner, so charging them for one would be wrong, and it would
  /// also make a perfect lesson unreachable in any lesson containing a
  /// type this build does not know.
  int get _reportedCorrect => _correctCount + _content.unrenderableCount;

  /// Bolt 020 (008-srs-and-practice): true for a Practice session, built
  /// via `LessonScreen.practice`. Skips Beans consumption/interruption
  /// entirely (Practice isn't gated by mistake tolerance) and completes
  /// through `LessonApi.completePracticeSession` instead of
  /// `completeLesson` -- a Practice due-set spans arbitrary lessons/skills
  /// and must work even for a locked skill's item, which `completeLesson`
  /// structurally cannot support.
  final bool isPractice;

  /// True when replaying a skill already completed. A review awards nothing
  /// and costs nothing: the server records it with no XP, Amole, crown or
  /// streak change, and a wrong answer here spends no beans, so it can never
  /// end in the out-of-beans prompt. Completion still goes through
  /// `completeLesson` -- the server decides it is a review from the skill's
  /// progress, and still updates vocab review progress.
  final bool isReview;

  /// Whether a wrong answer spends a bean. Neither Practice nor a review is
  /// gated by mistakes.
  bool get usesBeans => !isPractice && !isReview;

  /// Practice-only: resolves each of [content.exercises]' ids to the vocab
  /// item it tests, so `_finishLesson` can report per-item correctness by
  /// vocab item (what the practice-completion endpoint needs) rather than
  /// by exercise id (what `missedExerciseIds` uses). Empty/unused for a
  /// regular lesson.
  final Map<String, String> _vocabItemIdByExerciseId;

  /// Whether this attempt was started with the device offline -- fixed
  /// once at construction (mirrors whichever choice `LessonScreen` made
  /// loading the content) and never re-checked at completion time, per
  /// FR-2's "doesn't switch modes mid-attempt" edge case
  /// (010-offline-caching-and-sync-ui, story 003).
  final bool startedOffline;
  final Stopwatch _stopwatch = Stopwatch()..start();

  /// Generated once per attempt and reused across any completion retry --
  /// the idempotency key `completeLesson` sends (see [LessonApi]'s
  /// `attemptId` doc). A 128-bit random hex string is sufficiently
  /// collision-free without pulling in a `uuid` package dependency for
  /// this single use.
  final String _attemptId;

  static String _generateAttemptId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Indices into [content.exercises] still to be asked this attempt. A
  /// missed exercise's index is appended to the end on a wrong answer, so
  /// it comes back around later in the same lesson rather than the lesson
  /// ending with it unmastered.
  final List<int> _queue;
  int _queuePosition = 0;

  int _beansRemaining;
  int _correctCount = 0;
  int _wrongCount = 0;

  /// Ids of exercises answered wrong at least once before eventually being
  /// answered correctly this attempt (bolt 019, ADR-10) -- the
  /// retry-until-correct queue below means every exercise is eventually
  /// right by the time the lesson finishes, so "was ever missed" (not a
  /// final pass/fail) is the only per-exercise signal there is to report.
  final Set<String> _missedExerciseIds = {};

  TileFeedback _feedback = TileFeedback.none;
  Object? _selectedAnswer;

  /// Match-pairs only: the tile tapped first, awaiting a tap in the other
  /// column to complete a pair -- transient selection state, not part of
  /// the graded answer, so it lives here rather than in [selectedAnswer].
  String? _armedTileId;
  bool _armedIsLeft = true;

  /// Match-pairs only: pairs already graded right (`left -> right`). They
  /// stay locked in; [selectedAnswer] is set once every pair is here.
  final Map<String, String> _matchedPairs = {};

  /// Match-pairs only: the pair just graded wrong, shown red until
  /// [_wrongPairTimer] clears it or the next tap does.
  (String, String)? _wrongPair;
  Timer? _wrongPairTimer;
  bool _lessonInterrupted = false;
  bool _lessonFinished = false;
  bool _awaitingRetryIntro = false;
  bool _retryIntroShown = false;
  LessonCompletionResult? _completionResult;
  Object? _completionError;

  LessonContent get content => _content;
  List<Exercise> get exercises => _content.exercises;
  int get currentIndex => _queuePosition;
  Exercise get currentExercise => exercises[_queue[_queuePosition]];
  bool get isLastExercise => _queuePosition == _queue.length - 1;

  int get beansRemaining => _beansRemaining;
  int get correctCount => _correctCount;
  int get wrongCount => _wrongCount;

  TileFeedback get feedback => _feedback;
  Object? get selectedAnswer => _selectedAnswer;
  String? get armedTileId => _armedTileId;
  bool get armedIsLeft => _armedIsLeft;
  Map<String, String> get matchedPairs => Map.unmodifiable(_matchedPairs);
  (String left, String right)? get wrongPair => _wrongPair;

  /// True once a wrong answer has dropped beans to 0 — the lesson stops
  /// accepting further answers and the out-of-beans modal takes over.
  bool get lessonInterrupted => _lessonInterrupted;

  bool get lessonFinished => _lessonFinished;
  LessonCompletionResult? get completionResult => _completionResult;

  /// True right after advancing onto the first requeued (previously
  /// missed) exercise of the attempt, before the learner has dismissed
  /// the "let's fix this" interstitial. Fires once per attempt even if
  /// several exercises were missed -- it announces "the retry section
  /// starts now", not each individual retry. [currentExercise] already
  /// points at the requeued exercise while this is true -- the screen
  /// just holds off rendering it until [startRetryExercise] is called.
  bool get awaitingRetryIntro => _awaitingRetryIntro;

  /// Set when the most recent [continueToNext] call on the last exercise
  /// failed to reach the backend (network error, backend error). Cleared
  /// on the next attempt. The existing "Continue" button (already visible
  /// post-grading) is the retry affordance -- tapping it again simply
  /// calls [continueToNext] again, which retries [_finishLesson] since
  /// [lessonFinished] never became true.
  Object? get completionError => _completionError;

  bool get isChecked => _feedback != TileFeedback.none;

  /// Answers a choice-based exercise (multiple choice, listening, gap fill)
  /// and grades it on the spot. One tap is the whole answer for these, so a
  /// separate Check tap only added a step.
  void chooseOption(int index) {
    if (isChecked || _lessonInterrupted) return;
    _selectedAnswer = index;
    check();
  }

  /// Toggles a sentence-construction word-bank token, or a spell-tiles tile
  /// id, in or out of the built answer, in tap order. Tile ids are unique,
  /// so a spelled word's twin tiles toggle independently (bolt 033).
  void toggleWordBankToken(String token) {
    if (isChecked || _lessonInterrupted) return;
    final built = List<String>.of(
      (_selectedAnswer as List<String>?) ?? const [],
    );
    if (built.contains(token)) {
      built.remove(token);
    } else {
      built.add(token);
    }
    _selectedAnswer = built;
    notifyListeners();
  }

  /// Handles a tap on a match-pairs tile. Each pair is graded the moment
  /// its second tile is tapped, instead of the whole board on one Check.
  ///
  /// The first tap (either column) arms a tile; tapping it again disarms
  /// it, and tapping another tile in the same column moves the arm. A tap
  /// in the other column completes the pair: a right one locks in, a wrong
  /// one flashes briefly and both tiles go back to being tappable. Once
  /// every pair is locked the exercise is finished and Continue shows.
  ///
  /// A wrong pair costs one bean, but only the first in an exercise: the
  /// learner fixes it on the spot, so the exercise is not requeued, and one
  /// bean per exercise is what a wrong Check costs everywhere else. It is
  /// still reported as missed, so its vocab gets reviewed.
  void selectMatchPairsTile(String tileId, {required bool isLeft}) {
    if (isChecked || _lessonInterrupted) return;
    final exercise = currentExercise;
    if (exercise is! MatchPairsExercise) return;
    final alreadyMatched = isLeft
        ? _matchedPairs.containsKey(tileId)
        : _matchedPairs.containsValue(tileId);
    if (alreadyMatched) return;
    _clearWrongPair();

    final armed = _armedTileId;
    if (armed == null || _armedIsLeft == isLeft) {
      _armedTileId = armed == tileId ? null : tileId;
      _armedIsLeft = isLeft;
      notifyListeners();
      return;
    }

    final leftId = isLeft ? tileId : armed;
    final rightId = isLeft ? armed : tileId;
    _armedTileId = null;
    if (exercise.correctPairs[leftId] == rightId) {
      _matchedPairs[leftId] = rightId;
      unawaited(_feedbackPlayer.playCorrect());
      if (_matchedPairs.length == exercise.correctPairs.length) {
        _selectedAnswer = Map<String, String>.of(_matchedPairs);
        _correctCount++;
        _feedback = TileFeedback.correct;
      }
    } else {
      _wrongPair = (leftId, rightId);
      _wrongPairTimer = Timer(_wrongPairFlash, () {
        _wrongPair = null;
        notifyListeners();
      });
      unawaited(_feedbackPlayer.playIncorrect());
      _chargeMatchPairsMistake(exercise);
    }
    notifyListeners();
  }

  static const _wrongPairFlash = Duration(milliseconds: 700);

  void _chargeMatchPairsMistake(MatchPairsExercise exercise) {
    if (_missedExerciseIds.contains(exercise.id)) return;
    _missedExerciseIds.add(exercise.id);
    if (!usesBeans) return;
    _beansRemaining = (_beansRemaining - 1).clamp(0, _content.beansMax);
    if (_beansRemaining <= 0) _lessonInterrupted = true;
  }

  void _clearWrongPair() {
    _wrongPairTimer?.cancel();
    _wrongPairTimer = null;
    _wrongPair = null;
  }

  /// Grades [selectedAnswer]/[toggleWordBankToken]'s current answer. A wrong
  /// answer requeues this exercise to the end of the lesson so the learner
  /// must answer it correctly before the lesson can finish.
  void check() {
    if (isChecked || _lessonInterrupted || _selectedAnswer == null) return;

    final exerciseIndex = _queue[_queuePosition];
    final correct = isAnswerCorrect(currentExercise, _selectedAnswer!);
    if (correct) {
      _correctCount++;
      _feedback = TileFeedback.correct;
      unawaited(_feedbackPlayer.playCorrect());
    } else {
      _wrongCount++;
      _missedExerciseIds.add(currentExercise.id);
      if (usesBeans) {
        _beansRemaining = (_beansRemaining - 1).clamp(0, _content.beansMax);
        if (_beansRemaining <= 0) {
          _lessonInterrupted = true;
        }
      }
      _feedback = TileFeedback.incorrect;
      _queue.add(exerciseIndex);
      unawaited(_feedbackPlayer.playIncorrect());
    }
    notifyListeners();
  }

  /// Advances to the next exercise in the queue — which may be a fresh
  /// exercise or a requeued miss — or finishes the lesson if the queue is
  /// exhausted. No-op while [lessonInterrupted] — the out-of-beans modal
  /// owns navigation at that point.
  Future<void> continueToNext() async {
    if (_lessonInterrupted || !isChecked) return;

    if (isLastExercise) {
      await _finishLesson();
      return;
    }
    _queuePosition++;
    _selectedAnswer = null;
    _armedTileId = null;
    _matchedPairs.clear();
    _clearWrongPair();
    _feedback = TileFeedback.none;
    // Positions 0..exercises.length-1 always hold the original exercises
    // in their original order (the queue only ever appends); reaching a
    // position past that means the retry section of the lesson has
    // started. Once shown, [_retryIntroShown] keeps this from firing
    // again on every subsequent requeued exercise -- it's a one-time
    // "heads up, here come your misses" beat, not a per-exercise one.
    if (!_retryIntroShown && _queuePosition >= exercises.length) {
      _awaitingRetryIntro = true;
    }
    notifyListeners();
  }

  /// Dismisses the "let's fix this" interstitial and reveals the requeued
  /// exercise itself. No-op if there's nothing to dismiss.
  void startRetryExercise() {
    if (!_awaitingRetryIntro) return;
    _awaitingRetryIntro = false;
    _retryIntroShown = true;
    notifyListeners();
  }

  /// Called after a successful out-of-beans refill (story 003): resumes
  /// the lesson at the exercise it was interrupted on, rather than
  /// restarting from the beginning.
  void resumeAfterRefill(int newBeans) {
    _beansRemaining = newBeans;
    _lessonInterrupted = false;
    notifyListeners();
  }

  Future<void> _finishLesson() async {
    _stopwatch.stop();
    final clientCompletedAt = DateTime.now().toUtc();

    if (isPractice) {
      try {
        final results = exercises
            .map(
              (exercise) => PracticeResult(
                vocabItemId: _vocabItemIdByExerciseId[exercise.id]!,
                correct: !_missedExerciseIds.contains(exercise.id),
              ),
            )
            .toList();
        final result = await _lessonApi.completePracticeSession(
          sessionId: _attemptId,
          results: results,
          timeSpent: _stopwatch.elapsed,
        );
        // No streak/crown/skill-unlock fields -- Practice doesn't touch
        // any of those (this bolt's Plan-stage decision), same "safe
        // defaults when not applicable" convention this model's
        // `pendingSync` branch already uses.
        _completionResult = LessonCompletionResult(
          xpEarned: result.xpEarned,
          dailyXpTotal: 0,
          dailyXpTarget: 0,
          streakCount: 0,
          streakIncreasedToday: false,
          accuracyPercent: result.accuracyPercent,
          correctCount: result.correctCount,
          totalCount: result.totalCount,
          timeSpent: _stopwatch.elapsed,
        );
        _lessonFinished = true;
        _completionError = null;
      } catch (e) {
        // Idempotent on `_attemptId` server-side, same guarantee as a
        // regular lesson's retry -- tapping "Continue" again is safe.
        _completionError = e;
      }
      notifyListeners();
      return;
    }

    if (startedOffline) {
      // Never calls the network endpoint at all -- queued for `SyncEngine`
      // to replay once connectivity returns (010-offline-caching-and-
      // sync-ui, story 003). The mode was fixed at lesson start and stays
      // fixed even if connectivity has since returned (FR-2's "doesn't
      // switch modes mid-attempt").
      await _queueForSync(clientCompletedAt);
      return;
    }

    try {
      final result = await _lessonApi.completeLesson(
        lessonId: _content.lessonId,
        attemptId: _attemptId,
        correctCount: _reportedCorrect,
        totalCount: _servedCount,
        timeSpent: _stopwatch.elapsed,
        beansRemainingAtEnd: _beansRemaining,
        // Captured right now, whether this call succeeds immediately or is
        // itself a retry -- identical to "now" for a normal online
        // completion.
        clientCompletedAt: clientCompletedAt,
        missedExerciseIds: _missedExerciseIds.toList(),
      );
      _completionResult = result;
      _lessonFinished = true;
      _completionError = null;
    } on LessonApiException catch (e) {
      if (e.errorCode == null) {
        // Never reached the server -- the connection dropped during the
        // lesson. Queued exactly as if the lesson had started offline, so
        // the learner finishes normally and it syncs on reconnect. Safe
        // even if the request did land and only the answer was lost:
        // completion is idempotent on `_attemptId`.
        await _queueForSync(clientCompletedAt);
        return;
      }
      // The server answered and refused. Tapping "Continue" retries.
      _completionError = e;
    } catch (e) {
      // Idempotent on `_attemptId` server-side (ADR-5, Decision 2) -- a
      // retry (tapping "Continue" again) is always safe, never a double
      // award, even if this specific attempt actually succeeded server-
      // side but the response was lost.
      _completionError = e;
    }
    notifyListeners();
  }

  /// Queues this attempt for `SyncEngine` and finishes the lesson with a
  /// local result marked `pendingSync`.
  Future<void> _queueForSync(DateTime clientCompletedAt) async {
    await _syncEngine.enqueueOfflineCompletion(
      PendingSyncEntry(
        attemptId: _attemptId,
        lessonId: _content.lessonId,
        correctCount: _reportedCorrect,
        totalCount: _servedCount,
        timeSpent: _stopwatch.elapsed,
        beansRemainingAtEnd: _beansRemaining,
        clientCompletedAt: clientCompletedAt,
        missedExerciseIds: _missedExerciseIds.toList(),
      ),
    );
    final accuracyPercent = _servedCount == 0
        ? 0
        : ((_reportedCorrect / _servedCount) * 100).round();
    _completionResult = LessonCompletionResult(
      xpEarned: isReview ? 0 : _reportedCorrect * kXpPerCorrectAnswer,
      dailyXpTotal: 0,
      dailyXpTarget: 0,
      streakCount: 0,
      streakIncreasedToday: false,
      accuracyPercent: accuracyPercent,
      correctCount: _reportedCorrect,
      totalCount: _servedCount,
      timeSpent: _stopwatch.elapsed,
      pendingSync: true,
      isReview: isReview,
    );
    _lessonFinished = true;
    _completionError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _wrongPairTimer?.cancel();
    super.dispose();
  }
}
