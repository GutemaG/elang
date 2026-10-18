// Which finished lessons tell the daily reminder the day is done
// (021-daily-reminder, bolt 063): a lesson that counts for the streak,
// online or queued offline; never a review or Practice.

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/state/lesson_controller.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/practice_completion_result.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../helpers/controllable_lesson_api.dart';
import '../../helpers/fake_answer_feedback_player.dart';
import '../../helpers/fake_connectivity_monitor.dart';
import '../../helpers/fake_pending_sync_queue_store.dart';

const _lesson = LessonContent(
  lessonId: 'lesson',
  skillId: 'skill',
  title: 'Greetings',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    MultipleChoiceExercise(
      id: 'mc-1',
      prompt: 'ሀ',
      promptTranslation: 'Which sound?',
      options: ['ha', 'le'],
      correctOptionIndex: 0,
    ),
  ],
);

LessonCompletionResult _result({required bool isReview}) =>
    LessonCompletionResult(
      xpEarned: isReview ? 0 : 5,
      dailyXpTotal: 5,
      dailyXpTarget: 30,
      streakCount: 8,
      streakIncreasedToday: !isReview,
      accuracyPercent: 100,
      correctCount: 1,
      totalCount: 1,
      timeSpent: const Duration(seconds: 5),
      isReview: isReview,
    );

typedef _Counted = ({DateTime at, int? streak});

Future<List<_Counted>> _finish({
  required ControllableLessonApi api,
  bool startedOffline = false,
  bool isReview = false,
  bool isPractice = false,
}) async {
  final counted = <_Counted>[];
  final controller = LessonController(
    lessonApi: api,
    feedbackPlayer: FakeAnswerFeedbackPlayer(),
    syncEngine: SyncEngine(
      lessonApi: api,
      connectivityMonitor: FakeConnectivityMonitor(online: !startedOffline),
      queueStore: FakePendingSyncQueueStore(),
    ),
    content: _lesson,
    startedOffline: startedOffline,
    isReview: isReview,
    isPractice: isPractice,
    vocabItemIdByExerciseId: isPractice ? const {'mc-1': 'vocab-1'} : null,
    onLessonCounted: (at, streak) => counted.add((at: at, streak: streak)),
  );
  controller.chooseOption(0);
  controller.check();
  await controller.continueToNext();
  expect(controller.lessonFinished, isTrue);
  controller.dispose();
  return counted;
}

void main() {
  test('an online lesson counts, with the new streak', () async {
    final before = DateTime.now();
    final counted = await _finish(
      api: ControllableLessonApi()..completionResult = _result(isReview: false),
    );

    expect(counted, hasLength(1));
    expect(counted.single.streak, 8);
    expect(counted.single.at.isBefore(before), isFalse);
  });

  test('the server calling it a review does not count', () async {
    final counted = await _finish(
      api: ControllableLessonApi()..completionResult = _result(isReview: true),
    );

    expect(counted, isEmpty);
  });

  test('a lesson queued offline counts, with no streak yet', () async {
    final counted = await _finish(
      api: ControllableLessonApi(),
      startedOffline: true,
    );

    expect(counted, hasLength(1));
    expect(counted.single.streak, isNull);
  });

  test('a review queued offline does not count', () async {
    final counted = await _finish(
      api: ControllableLessonApi(),
      startedOffline: true,
      isReview: true,
    );

    expect(counted, isEmpty);
  });

  test('Practice never counts', () async {
    final counted = await _finish(
      api: ControllableLessonApi()
        ..practiceCompletionResult = const PracticeCompletionResult(
          xpEarned: 5,
          amoleEarned: 0,
          correctCount: 1,
          totalCount: 1,
          accuracyPercent: 100,
        ),
      isPractice: true,
    );

    expect(counted, isEmpty);
  });
}
