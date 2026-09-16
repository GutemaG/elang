// Lesson exercise screen tests (story 002) plus the out-of-beans
// interruption/refill/dismiss flow (story 003), since story 003 is
// triggered from inside this screen.
//
// Covers: all 3 exercise types render and are answerable with
// default/selected/correct/incorrect tile feedback; a correct answer
// advances, an incorrect one decrements local beans; listening exercises
// support tap-to-play/replay; local beans hitting 0 immediately shows the
// out-of-beans modal instead of accepting further answers; refill resumes
// the lesson; dismissing without refilling returns to the caller without
// ever calling `completeLesson` (no partial XP).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_lesson_audio_player.dart';

const _multipleChoice = LessonContent(
  lessonId: 'lesson-mc',
  skillId: 'skill-mc',
  title: 'MC Lesson',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    MultipleChoiceExercise(
      id: 'mc-1',
      prompt: 'ሀ',
      promptTranslation: 'Which sound?',
      options: ['ha', 'le', 'me'],
      correctOptionIndex: 0,
    ),
    MultipleChoiceExercise(
      id: 'mc-2',
      prompt: 'ለ',
      promptTranslation: 'Which sound?',
      options: ['ha', 'le', 'me'],
      correctOptionIndex: 1,
    ),
  ],
);

const _threeMultipleChoice = LessonContent(
  lessonId: 'lesson-mc3',
  skillId: 'skill-mc3',
  title: 'MC Lesson (3)',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    MultipleChoiceExercise(
      id: 'mc-1',
      prompt: 'ሀ',
      promptTranslation: 'Which sound?',
      options: ['ha', 'le', 'me'],
      correctOptionIndex: 0,
    ),
    MultipleChoiceExercise(
      id: 'mc-2',
      prompt: 'ለ',
      promptTranslation: 'Which sound?',
      options: ['ha', 'le', 'me'],
      correctOptionIndex: 1,
    ),
    MultipleChoiceExercise(
      id: 'mc-3',
      prompt: 'መ',
      promptTranslation: 'Which sound?',
      options: ['ha', 'le', 'me'],
      correctOptionIndex: 2,
    ),
  ],
);

const _mixedLesson = LessonContent(
  lessonId: 'lesson-mixed',
  skillId: 'skill-mixed',
  title: 'Mixed Lesson',
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
    ListeningExercise(
      id: 'listen-1',
      audioUrl: 'https://cdn.buna.app/audio/test.mp3',
      instruction: 'Tap what you hear',
      options: ['ሰላም', 'ደህና'],
      correctOptionIndex: 0,
    ),
    SentenceConstructionExercise(
      id: 'sentence-1',
      promptTranslation: 'Please drink coffee',
      wordBank: ['ቡና', 'እባክዎ', 'ጠጡ', 'ውሃ'],
      correctSentence: ['እባክዎ', 'ቡና', 'ጠጡ'],
    ),
  ],
);

ControllableLessonApi _apiFor(
  LessonContent content, {
  int? beansOverride,
}) {
  return ControllableLessonApi()
    ..lessonContent = beansOverride == null
        ? content
        : LessonContent(
            lessonId: content.lessonId,
            skillId: content.skillId,
            title: content.title,
            beansAtStart: beansOverride,
            beansMax: content.beansMax,
            exercises: content.exercises,
          )
    ..completionResult = const LessonCompletionResult(
      xpEarned: 10,
      dailyXpTotal: 10,
      dailyXpTarget: 30,
      streakCount: 6,
      streakIncreasedToday: true,
      accuracyPercent: 100,
      correctCount: 2,
      totalCount: 2,
      timeSpent: Duration(seconds: 10),
    )
    ..beansStatus = BeansStatus(
      beans: 0,
      beansMax: content.beansMax,
      nextBeanAt: DateTime.now().add(const Duration(minutes: 30)),
      regenMinutesPerBean: 30,
      amoleBalance: 420,
      refillCostAmole: 350,
    )
    ..refillResult = const RefillSuccess(newBeans: 5, newAmoleBalance: 70);
}

Widget _wrapped(
  ControllableLessonApi api, {
  required String lessonId,
  FakeAnswerFeedbackPlayer? feedbackPlayer,
}) {
  return MaterialApp(
    home: LessonScreen(
      lessonId: lessonId,
      lessonApi: api,
      audioPlayer: FakeLessonAudioPlayer(),
      feedbackPlayer: feedbackPlayer ?? FakeAnswerFeedbackPlayer(),
    ),
  );
}

void main() {
  testWidgets(
    'a correct multiple-choice answer shows correct feedback and advances',
    (tester) async {
      final api = _apiFor(_multipleChoice);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mc'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ha'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Second exercise now showing.
      expect(find.text('ለ'), findsOneWidget);
    },
  );

  testWidgets(
    'an incorrect multiple-choice answer shows incorrect feedback and decrements beans',
    (tester) async {
      final api = _apiFor(_multipleChoice);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mc'));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget); // starting beans

      await tester.tap(find.text('le')); // wrong for exercise 1
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // beans decremented
    },
  );

  testWidgets(
    'grading plays a distinct sound/haptic cue for a correct vs. an incorrect answer',
    (tester) async {
      final api = _apiFor(_multipleChoice);
      final feedbackPlayer = FakeAnswerFeedbackPlayer();
      await tester.pumpWidget(
        _wrapped(api, lessonId: 'lesson-mc', feedbackPlayer: feedbackPlayer),
      );
      await tester.pumpAndSettle();

      expect(feedbackPlayer.cues, isEmpty);

      // Exercise 1 (mc-1): wrong answer.
      await tester.tap(find.text('le'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(feedbackPlayer.cues, [FeedbackCue.incorrect]);

      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Exercise 2 (mc-2): correct answer.
      await tester.tap(find.text('le'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(feedbackPlayer.cues, [FeedbackCue.incorrect, FeedbackCue.correct]);
    },
  );

  testWidgets(
    'a missed exercise loops back and must be answered correctly before the lesson finishes',
    (tester) async {
      final api = _apiFor(_multipleChoice);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mc'));
      await tester.pumpAndSettle();

      // Exercise 1 (mc-1, prompt 'ሀ'): answer wrong.
      await tester.tap(find.text('le'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Exercise 2 (mc-2, prompt 'ለ') now showing, not a finish yet.
      expect(find.text('ለ'), findsOneWidget);
      expect(api.completeLessonCalls, isEmpty);

      // Answer exercise 2 correctly.
      await tester.tap(find.text('le'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // A "let's fix this" interstitial appears before the missed mc-1
      // reappears, rather than the lesson finishing.
      expect(find.text("Let's review your mistakes"), findsOneWidget);
      expect(find.text('ሀ'), findsNothing);
      expect(api.completeLessonCalls, isEmpty);

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('ሀ'), findsOneWidget);
      expect(api.completeLessonCalls, isEmpty);

      // Answer it correctly this time; the lesson now finishes.
      await tester.tap(find.text('ha'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.completeLessonCalls, hasLength(1));
      expect(api.completeLessonCalls.single.correctCount, 2);
    },
  );

  testWidgets(
    'with multiple mistakes, the "let\'s fix this" interstitial shows only once, not before every retry',
    (tester) async {
      final api = _apiFor(_threeMultipleChoice);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mc3'));
      await tester.pumpAndSettle();

      // Exercise 1 (mc-1, prompt 'ሀ'): answer wrong.
      await tester.tap(find.text('le'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text("Let's review your mistakes"), findsNothing);
      expect(find.text('ለ'), findsOneWidget);

      // Exercise 2 (mc-2, prompt 'ለ'): answer wrong too.
      await tester.tap(find.text('ha'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text("Let's review your mistakes"), findsNothing);
      expect(find.text('መ'), findsOneWidget);

      // Exercise 3 (mc-3, prompt 'መ'): answer correctly. This is the last
      // fresh exercise -- the retry section starts next, so the
      // interstitial should show exactly here.
      await tester.tap(find.text('me'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text("Let's review your mistakes"), findsOneWidget);
      // Both mistakes are counted, not just the most recent one.
      expect(
        find.text('You missed 2 questions earlier. '
            "Let's get them right this time!"),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget); // the badge's count

      await tester.tap(find.text('Continue'));
      await tester.pump();

      // First retry: the missed mc-1 reappears. Answer it correctly.
      expect(find.text('ሀ'), findsOneWidget);
      await tester.tap(find.text('ha'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Second retry: the missed mc-2 reappears -- no interstitial this
      // time, even though this is also a requeued miss.
      expect(find.text("Let's review your mistakes"), findsNothing);
      expect(find.text('ለ'), findsOneWidget);

      await tester.tap(find.text('le'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.completeLessonCalls, hasLength(1));
      expect(api.completeLessonCalls.single.correctCount, 3);
    },
  );

  testWidgets(
    'a completion failure shows an inline error and retrying (tapping Continue again) succeeds',
    (tester) async {
      final api = _apiFor(_multipleChoice)
        ..completeLessonError = Exception('network down');
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mc'));
      await tester.pumpAndSettle();

      // Answer both exercises correctly.
      await tester.tap(find.text('ha'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      await tester.tap(find.text('le'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue')); // fails
      await tester.pump();

      expect(
        find.text("Couldn't save your progress. Tap Continue to try again."),
        findsOneWidget,
      );
      expect(api.completeLessonCalls, hasLength(1));
      // Still on the lesson screen -- did not navigate to the summary.
      expect(find.text('Continue'), findsOneWidget);

      api.completeLessonError = null;
      await tester.tap(find.text('Continue')); // retries
      await tester.pumpAndSettle();

      expect(api.completeLessonCalls, hasLength(2));
      expect(
        find.text("Couldn't save your progress. Tap Continue to try again."),
        findsNothing,
      );
    },
  );

  testWidgets('a listening exercise supports tap-to-play/replay before answering', (
    tester,
  ) async {
    final api = _apiFor(_mixedLesson);
    final audioPlayer = FakeLessonAudioPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: LessonScreen(
          lessonId: 'lesson-mixed',
          lessonApi: api,
          audioPlayer: audioPlayer,
          feedbackPlayer: FakeAnswerFeedbackPlayer(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Advance past the first (multiple-choice) exercise.
    await tester.tap(find.text('ha'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Tap what you hear'), findsOneWidget);
    expect(audioPlayer.playedUrls, isEmpty);

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();
    expect(audioPlayer.playedUrls, ['https://cdn.buna.app/audio/test.mp3']);

    // Replay.
    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();
    expect(audioPlayer.playedUrls.length, 2);
  });

  testWidgets(
    'a sentence-construction exercise is built by tapping the word bank and graded on Check',
    (tester) async {
      final api = _apiFor(_mixedLesson);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mixed'));
      await tester.pumpAndSettle();

      // Skip exercise 1 (multiple-choice).
      await tester.tap(find.text('ha'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Skip exercise 2 (listening).
      await tester.tap(find.text('ሰላም'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Exercise 3: sentence construction.
      expect(find.textContaining('Please drink coffee'), findsOneWidget);

      await tester.tap(find.text('እባክዎ'));
      await tester.pump();
      await tester.tap(find.text('ቡና'));
      await tester.pump();
      await tester.tap(find.text('ጠጡ'));
      await tester.pump();

      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
      expect(api.completeLessonCalls, isEmpty);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.completeLessonCalls, hasLength(1));
      expect(api.completeLessonCalls.single.correctCount, 3);
    },
  );

  testWidgets(
    'local beans hitting 0 immediately shows the out-of-beans modal instead of a Continue button',
    (tester) async {
      final api = _apiFor(_multipleChoice, beansOverride: 1);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mc'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('le')); // wrong answer, drops beans to 0
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.text('Out of Beans!'), findsOneWidget);
      // No Continue button underneath while the modal owns the flow.
      expect(find.text('Continue'), findsNothing);
    },
  );

  testWidgets(
    'refilling with Amole resumes the lesson without awarding partial XP for the interruption itself',
    (tester) async {
      final api = _apiFor(_multipleChoice, beansOverride: 1);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mc'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('le'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.text('Out of Beans!'), findsOneWidget);

      await tester.tap(find.textContaining('Refill with'));
      await tester.pumpAndSettle();

      expect(api.refillCallCount, 1);
      expect(find.text('Out of Beans!'), findsNothing);
      // Resumed on the exercise it was interrupted on, with a Continue
      // button now available (beans no longer 0).
      expect(find.text('Continue'), findsOneWidget);
      expect(api.completeLessonCalls, isEmpty);
    },
  );

  testWidgets(
    'dismissing the out-of-beans modal without refilling returns to the dashboard with no XP call',
    (tester) async {
      final api = _apiFor(_multipleChoice, beansOverride: 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LessonScreen(
                        lessonId: 'lesson-mc',
                        lessonApi: api,
                        audioPlayer: FakeLessonAudioPlayer(),
                        feedbackPlayer: FakeAnswerFeedbackPlayer(),
                      ),
                    ),
                  ),
                  child: const Text('open lesson'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open lesson'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('le'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.text('Out of Beans!'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // Back to the screen beneath (the "open lesson" button), not the
      // lesson-complete summary.
      expect(find.text('open lesson'), findsOneWidget);
      expect(find.text('Lesson Complete!'), findsNothing);
      expect(api.completeLessonCalls, isEmpty);
    },
  );

  testWidgets('the out-of-beans refill action is disabled when Amole is insufficient', (
    tester,
  ) async {
    final api = _apiFor(_multipleChoice, beansOverride: 1)
      ..beansStatus = BeansStatus(
        beans: 0,
        beansMax: 5,
        nextBeanAt: DateTime.now().add(const Duration(minutes: 20)),
        regenMinutesPerBean: 30,
        amoleBalance: 10,
        refillCostAmole: 350,
      );
    await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mc'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('le'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(find.text('Not enough Amole'), findsOneWidget);
    await tester.tap(find.text('Not enough Amole'), warnIfMissed: false);
    await tester.pump();
    expect(api.refillCallCount, 0);
  });
}
