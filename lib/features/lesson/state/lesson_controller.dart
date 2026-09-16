import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../shared/models/exercise.dart';
import '../../../shared/models/lesson_completion_result.dart';
import '../../../shared/models/lesson_content.dart';
import '../../../shared/services/answer_feedback_player.dart';
import '../../../shared/services/lesson_api.dart';

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
    required LessonContent content,
  }) : _content = content,
       _beansRemaining = content.beansAtStart,
       _queue = List<int>.generate(content.exercises.length, (i) => i),
       _attemptId = _generateAttemptId();

  final LessonApi _lessonApi;
  final AnswerFeedbackPlayer _feedbackPlayer;
  final LessonContent _content;
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

  TileFeedback _feedback = TileFeedback.none;
  Object? _selectedAnswer;
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

  /// Records the learner's in-progress selection (an `int` option index
  /// for multiple-choice/listening) before [check] grades it.
  void selectOption(int index) {
    if (isChecked || _lessonInterrupted) return;
    _selectedAnswer = index;
    notifyListeners();
  }

  /// Toggles a sentence-construction word-bank token in or out of the
  /// built answer, in tap order.
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
      _beansRemaining = (_beansRemaining - 1).clamp(0, _content.beansMax);
      _feedback = TileFeedback.incorrect;
      _queue.add(exerciseIndex);
      if (_beansRemaining <= 0) {
        _lessonInterrupted = true;
      }
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
    try {
      final result = await _lessonApi.completeLesson(
        lessonId: _content.lessonId,
        attemptId: _attemptId,
        correctCount: _correctCount,
        totalCount: exercises.length,
        timeSpent: _stopwatch.elapsed,
        beansRemainingAtEnd: _beansRemaining,
      );
      _completionResult = result;
      _lessonFinished = true;
      _completionError = null;
    } catch (e) {
      // Idempotent on `_attemptId` server-side (ADR-5, Decision 2) -- a
      // retry (tapping "Continue" again) is always safe, never a double
      // award, even if this specific attempt actually succeeded server-
      // side but the response was lost.
      _completionError = e;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }
}
