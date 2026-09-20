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
// ever calling `completeLesson` (no partial XP); and
// (009-offline-caching-and-sync-ui, story 002) offline lesson-taking --
// a downloaded pack plays from the cache while offline, and an
// un-downloaded lesson shows a "download required" state instead of a
// generic error; and (010-offline-caching-and-sync-ui, story 003) an
// offline completion queues for sync instead of calling the network, and
// stays queued even if connectivity returns mid-lesson.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/features/lesson/widgets/choice_tile.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/practice_completion_result.dart';

import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

SyncEngine _syncEngineFor(ControllableLessonApi api) => SyncEngine(
  lessonApi: api,
  connectivityMonitor: FakeConnectivityMonitor(),
  queueStore: FakePendingSyncQueueStore(),
);

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

const _matchPairsLesson = LessonContent(
  lessonId: 'lesson-mp',
  skillId: 'skill-mp',
  title: 'Match Pairs Lesson',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    MatchPairsExercise(
      id: 'mp-1',
      prompt: 'Match each word to its meaning',
      leftTiles: [MatchPairsTile(id: 'l1', text: 'ቡና'), MatchPairsTile(id: 'l2', text: 'ሻይ')],
      rightTiles: [MatchPairsTile(id: 'r1', text: 'Coffee'), MatchPairsTile(id: 'r2', text: 'Tea')],
      correctPairs: {'l1': 'r1', 'l2': 'r2'},
    ),
  ],
);

/// The word tile labelled [label], as distinct from the same word sitting
/// in the sentence's gap. Once a word is chosen it is on screen twice, so a
/// bare `find.text` is ambiguous and `tap` refuses it.
Finder _gapTile(String label) => find.descendant(
  of: find.byType(ChoiceTile),
  matching: find.text(label),
);

const _gapFillLesson = LessonContent(
  lessonId: 'lesson-gf',
  skillId: 'skill-gf',
  title: 'Gap Fill Lesson',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    GapFillExercise(
      id: 'gf-1',
      prompt: "Complete the sentence: 'I want coffee'",
      sentenceBefore: 'እኔ',
      sentenceAfter: 'እፈልጋለሁ',
      options: ['ቡና', 'ሻይ', 'ውሃ'],
      correctOptionIndex: 0,
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
      connectivityMonitor: FakeConnectivityMonitor(),
      lessonPackStore: FakeLessonPackStore(),
      syncEngine: _syncEngineFor(api),
    ),
  );
}

/// Bolt 020-practice-ui: a practice session has no `beansAtStart`/
/// `lessonId`/`skillId` to speak of (see `LessonScreen.practice`'s doc
/// comment) -- these fixture values are never read, only
/// `practiceVocabItemIdByExerciseId`'s mapping back to each exercise's
/// vocab item matters for completion reporting.
Widget _wrappedPractice(
  ControllableLessonApi api, {
  required LessonContent content,
  required Map<String, String> vocabItemIdByExerciseId,
}) {
  return MaterialApp(
    home: LessonScreen.practice(
      practiceContent: content,
      practiceVocabItemIdByExerciseId: vocabItemIdByExerciseId,
      lessonApi: api,
      audioPlayer: FakeLessonAudioPlayer(),
      feedbackPlayer: FakeAnswerFeedbackPlayer(),
      syncEngine: _syncEngineFor(api),
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
      // Bolt 019, ADR-10: mc-1 was missed once before eventually being
      // answered correctly -- reported even though the lesson finished
      // with a perfect final answer on every exercise.
      expect(api.completeLessonCalls.single.missedExerciseIds, ['mc-1']);
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
          connectivityMonitor: FakeConnectivityMonitor(),
          lessonPackStore: FakeLessonPackStore(),
          syncEngine: _syncEngineFor(api),
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
    'a match-pairs exercise requires every tile linked before Check grades it correctly',
    (tester) async {
      final api = _apiFor(_matchPairsLesson);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mp'));
      await tester.pumpAndSettle();

      // Link only 1 of 2 pairs, then try to Check -- nothing happens yet
      // (the button is disabled while incomplete).
      await tester.tap(find.text('ቡና'));
      await tester.pump();
      await tester.tap(find.text('Coffee'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Continue'), findsNothing);

      // Link the second pair too -- now Check is enabled and grades the
      // whole exercise atomically.
      await tester.tap(find.text('ሻይ'));
      await tester.pump();
      await tester.tap(find.text('Tea'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.completeLessonCalls, hasLength(1));
      expect(api.completeLessonCalls.single.correctCount, 1);
    },
  );

  testWidgets(
    'an incorrect match-pairs submission requeues the exercise, same as the other types',
    (tester) async {
      final api = _apiFor(_matchPairsLesson);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mp'));
      await tester.pumpAndSettle();

      // Link both pairs, but swapped (wrong).
      await tester.tap(find.text('ቡና'));
      await tester.pump();
      await tester.tap(find.text('Tea'));
      await tester.pump();
      await tester.tap(find.text('ሻይ'));
      await tester.pump();
      await tester.tap(find.text('Coffee'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Only exercise in the lesson -- the retry interstitial shows
      // immediately (mirrors the multiple-choice "missed exercise loops
      // back" behavior).
      expect(find.text("Let's review your mistakes"), findsOneWidget);
      expect(api.completeLessonCalls, isEmpty);
      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Retry: link correctly this time.
      await tester.tap(find.text('ቡና'));
      await tester.pump();
      await tester.tap(find.text('Coffee'));
      await tester.pump();
      await tester.tap(find.text('ሻይ'));
      await tester.pump();
      await tester.tap(find.text('Tea'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.completeLessonCalls, hasLength(1));
      expect(api.completeLessonCalls.single.correctCount, 1);
    },
  );

  testWidgets(
    'tapping a linked left tile again unlinks it, and re-linking a used right tile moves it (stays one-to-one)',
    (tester) async {
      final api = _apiFor(_matchPairsLesson);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-mp'));
      await tester.pumpAndSettle();

      // Link l1 -> Coffee, then unlink it by tapping it again.
      await tester.tap(find.text('ቡና'));
      await tester.pump();
      await tester.tap(find.text('Coffee'));
      await tester.pump();
      await tester.tap(find.text('ቡና'));
      await tester.pump();

      // Only 1 tile (l2) can still be linked -- Check must stay disabled
      // since l1 is unlinked again.
      await tester.tap(find.text('ሻይ'));
      await tester.pump();
      await tester.tap(find.text('Tea'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Continue'), findsNothing);

      // Re-link l1 to the *other* right tile now that l2 has claimed
      // Tea -- proves the mapping stays 1:1 rather than allowing a right
      // tile to serve two left tiles.
      await tester.tap(find.text('ቡና'));
      await tester.pump();
      await tester.tap(find.text('Coffee'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.completeLessonCalls, hasLength(1));
      expect(api.completeLessonCalls.single.correctCount, 1);
    },
  );

  testWidgets(
    'a gap-fill exercise fills its gap on tap, and Check stays disabled until a word is chosen',
    (tester) async {
      final api = _apiFor(_gapFillLesson);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-gf'));
      await tester.pumpAndSettle();

      // Nothing chosen: the gap is empty and Check does nothing.
      expect(find.text('ቡና'), findsOneWidget); // the tile only
      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Continue'), findsNothing);

      // Choosing a word puts it in the gap -- the word is now on screen
      // twice, once in the sentence and once on its tile.
      await tester.tap(_gapTile('ቡና'));
      await tester.pump();
      expect(find.text('ቡና'), findsNWidgets(2));

      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(api.completeLessonCalls.single.correctCount, 1);
    },
  );

  testWidgets(
    'tapping another word moves the gap-fill selection, and tapping the chosen word again keeps it',
    (tester) async {
      final api = _apiFor(_gapFillLesson);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-gf'));
      await tester.pumpAndSettle();

      // Choose the wrong word first, then change to another.
      await tester.tap(_gapTile('ሻይ'));
      await tester.pump();
      expect(find.text('ሻይ'), findsNWidgets(2));

      await tester.tap(_gapTile('ቡና'));
      await tester.pump();
      // The old word left the gap; the new one took its place.
      expect(find.text('ሻይ'), findsOneWidget);
      expect(find.text('ቡና'), findsNWidgets(2));

      // Tapping the chosen word again KEEPS it (the decision recorded in
      // this bolt's plan) -- clearing it would disable Check with no
      // visible cause.
      await tester.tap(_gapTile('ቡና'));
      await tester.pump();
      expect(find.text('ቡና'), findsNWidgets(2));

      await tester.tap(find.text('Check'));
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
    },
  );

  testWidgets(
    'an incorrect gap-fill submission requeues the exercise, same as the other types',
    (tester) async {
      final api = _apiFor(_gapFillLesson);
      await tester.pumpWidget(_wrapped(api, lessonId: 'lesson-gf'));
      await tester.pumpAndSettle();

      await tester.tap(_gapTile('ውሃ'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text("Let's review your mistakes"), findsOneWidget);
      expect(api.completeLessonCalls, isEmpty);
      await tester.tap(find.text('Continue'));
      await tester.pump();

      await tester.tap(_gapTile('ቡና'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.completeLessonCalls, hasLength(1));
      expect(api.completeLessonCalls.single.correctCount, 1);
    },
  );

  testWidgets(
    'a gap-fill exercise downloads and then plays fully offline, queuing completion for sync',
    (tester) async {
      // Story 002. The pack path is exercise-type-agnostic by construction,
      // but `lesson_pack_store`'s JSON mapping is not compiler-checked in
      // the read direction, so this proves it end to end rather than
      // assuming it.
      final downloadApi = ControllableLessonApi()
        ..lessonContent = _gapFillLesson;
      final packStore = FakeLessonPackStore();
      final downloader = LessonPackDownloader(
        lessonApi: downloadApi,
        packStore: packStore,
      );
      await downloader.downloadLesson('lesson-gf');
      expect(downloader.statusFor('lesson-gf'), LessonDownloadStatus.downloaded);

      // A fresh api with no `lessonContent` set -- proves the offline
      // screen never falls through to the network (that would null-assert).
      final offlineApi = ControllableLessonApi()
        ..completionResult = const LessonCompletionResult(
          xpEarned: 10,
          dailyXpTotal: 10,
          dailyXpTarget: 30,
          streakCount: 1,
          streakIncreasedToday: true,
          accuracyPercent: 100,
          correctCount: 1,
          totalCount: 1,
          timeSpent: Duration(seconds: 5),
        );
      final connectivity = FakeConnectivityMonitor(online: false);
      final queueStore = FakePendingSyncQueueStore();
      final engine = SyncEngine(
        lessonApi: offlineApi,
        connectivityMonitor: connectivity,
        queueStore: queueStore,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            lessonId: 'lesson-gf',
            lessonApi: offlineApi,
            audioPlayer: FakeLessonAudioPlayer(),
            feedbackPlayer: FakeAnswerFeedbackPlayer(),
            connectivityMonitor: connectivity,
            lessonPackStore: packStore,
            syncEngine: engine,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // It came back out of the pack intact, and still plays.
      await tester.tap(_gapTile('ቡና'));
      await tester.pump();
      expect(find.text('ቡና'), findsNWidgets(2));
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Completion queued for sync, not sent -- the device is offline.
      expect(offlineApi.completeLessonCalls, isEmpty);
      expect(await queueStore.count(), 1);
      expect(find.text('Lesson Complete!'), findsOneWidget);
    },
  );

  testWidgets(
    'a match-pairs exercise downloads and then plays fully offline, queuing completion for sync',
    (tester) async {
      final downloadApi = ControllableLessonApi()..lessonContent = _matchPairsLesson;
      final packStore = FakeLessonPackStore();
      final downloader = LessonPackDownloader(lessonApi: downloadApi, packStore: packStore);
      await downloader.downloadLesson('lesson-mp');
      expect(downloader.statusFor('lesson-mp'), LessonDownloadStatus.downloaded);

      // A fresh api with no `lessonContent` set -- proves the offline
      // screen never falls through to the network (that would null-assert).
      final offlineApi = ControllableLessonApi()
        ..completionResult = const LessonCompletionResult(
          xpEarned: 10,
          dailyXpTotal: 10,
          dailyXpTarget: 30,
          streakCount: 1,
          streakIncreasedToday: true,
          accuracyPercent: 100,
          correctCount: 1,
          totalCount: 1,
          timeSpent: Duration(seconds: 5),
        );
      final connectivity = FakeConnectivityMonitor(online: false);
      final queueStore = FakePendingSyncQueueStore();
      final engine = SyncEngine(
        lessonApi: offlineApi,
        connectivityMonitor: connectivity,
        queueStore: queueStore,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            lessonId: 'lesson-mp',
            lessonApi: offlineApi,
            audioPlayer: FakeLessonAudioPlayer(),
            feedbackPlayer: FakeAnswerFeedbackPlayer(),
            connectivityMonitor: connectivity,
            lessonPackStore: packStore,
            syncEngine: engine,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ቡና'), findsOneWidget);

      await tester.tap(find.text('ቡና'));
      await tester.pump();
      await tester.tap(find.text('Coffee'));
      await tester.pump();
      await tester.tap(find.text('ሻይ'));
      await tester.pump();
      await tester.tap(find.text('Tea'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(offlineApi.completeLessonCalls, isEmpty);
      expect(find.text('Lesson Complete!'), findsOneWidget);
      expect(find.text('SYNCS WHEN ONLINE'), findsOneWidget);
      expect(await queueStore.count(), 1);
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
                        connectivityMonitor: FakeConnectivityMonitor(),
                        lessonPackStore: FakeLessonPackStore(),
                        syncEngine: _syncEngineFor(api),
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

  testWidgets(
    'offline with a downloaded pack plays from the cache instead of the network',
    (tester) async {
      // No `lessonContent` set on the api -- `startLesson` would throw on
      // the null-assert if the screen fell through to the network path,
      // proving the cache was actually used.
      final api = ControllableLessonApi();
      final packStore = FakeLessonPackStore()..save(_multipleChoice);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            lessonId: 'lesson-mc',
            lessonApi: api,
            audioPlayer: FakeLessonAudioPlayer(),
            feedbackPlayer: FakeAnswerFeedbackPlayer(),
            connectivityMonitor: FakeConnectivityMonitor(online: false),
            lessonPackStore: packStore,
            syncEngine: _syncEngineFor(api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ሀ'), findsOneWidget);
      expect(find.text('Check'), findsOneWidget);
    },
  );

  testWidgets(
    'offline with this lesson never downloaded shows a "download required" state, not a generic error',
    (tester) async {
      final api = ControllableLessonApi();
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
                        connectivityMonitor: FakeConnectivityMonitor(online: false),
                        lessonPackStore: FakeLessonPackStore(),
                        syncEngine: _syncEngineFor(api),
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

      expect(find.text("You're offline"), findsOneWidget);
      expect(
        find.text('Download this lesson while online to take it offline.'),
        findsOneWidget,
      );
      expect(find.text("Couldn't load this lesson."), findsNothing);

      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();

      // Back to the caller, not stuck on the download-required state.
      expect(find.text('open lesson'), findsOneWidget);
    },
  );

  testWidgets(
    'completing a lesson while offline queues it for sync instead of calling the network',
    (tester) async {
      final api = ControllableLessonApi();
      final connectivity = FakeConnectivityMonitor(online: false);
      final packStore = FakeLessonPackStore()..save(_multipleChoice);
      final queueStore = FakePendingSyncQueueStore();
      final engine = SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: queueStore,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            lessonId: 'lesson-mc',
            lessonApi: api,
            audioPlayer: FakeLessonAudioPlayer(),
            feedbackPlayer: FakeAnswerFeedbackPlayer(),
            connectivityMonitor: connectivity,
            lessonPackStore: packStore,
            syncEngine: engine,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Answer both exercises correctly and finish.
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
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Never called the network endpoint at all.
      expect(api.completeLessonCalls, isEmpty);
      // Shows the pending-sync summary, not a completion error.
      expect(find.text('Lesson Complete!'), findsOneWidget);
      expect(find.text('SYNCS WHEN ONLINE'), findsOneWidget);
      // ...and it actually landed in the queue.
      expect(await queueStore.count(), 1);
      expect(engine.pendingCount, 1);
    },
  );

  testWidgets(
    "a lesson started offline still queues at completion, even if connectivity returns mid-lesson (doesn't switch modes)",
    (tester) async {
      final api = ControllableLessonApi()
        ..completeLessonError = Exception('still down when the queued sync ran');
      final connectivity = FakeConnectivityMonitor(online: false);
      final packStore = FakeLessonPackStore()..save(_multipleChoice);
      final queueStore = FakePendingSyncQueueStore();
      final engine = SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: queueStore,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen(
            lessonId: 'lesson-mc',
            lessonApi: api,
            audioPlayer: FakeLessonAudioPlayer(),
            feedbackPlayer: FakeAnswerFeedbackPlayer(),
            connectivityMonitor: connectivity,
            lessonPackStore: packStore,
            syncEngine: engine,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Connectivity returns mid-lesson, *before* it's completed.
      connectivity.setOnline(true);
      await tester.pump();

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
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Still shows the pending-sync summary (the offline mode from load
      // time), not the "couldn't save your progress" error a direct
      // online `completeLesson` call would have produced against this
      // failing api.
      expect(find.text('Lesson Complete!'), findsOneWidget);
      expect(find.text('SYNCS WHEN ONLINE'), findsOneWidget);
      expect(
        find.text("Couldn't save your progress. Tap Continue to try again."),
        findsNothing,
      );
      // The queued sync attempt (triggered by reconnecting) did run and
      // fail, proving completion went through the queue/engine, not a
      // bypassing direct call.
      expect(api.completeLessonCalls, hasLength(1));
      expect(engine.pendingCount, 1);

      // The failed attempt scheduled a backoff retry timer -- dispose the
      // engine so it doesn't outlive the test.
      engine.dispose();
    },
  );

  group('practice mode (008-srs-and-practice, bolt 020)', () {
    testWidgets(
      'hides the beans indicator entirely, and a wrong answer neither decrements beans nor interrupts',
      (tester) async {
        final api = ControllableLessonApi()
          ..practiceCompletionResult = const PracticeCompletionResult(
            xpEarned: 10,
            amoleEarned: 10,
            correctCount: 1,
            totalCount: 2,
            accuracyPercent: 50,
          );
        await tester.pumpWidget(
          _wrappedPractice(
            api,
            content: _multipleChoice,
            vocabItemIdByExerciseId: const {'mc-1': 'vocab-1', 'mc-2': 'vocab-2'},
          ),
        );
        await tester.pumpAndSettle();

        // No beans heart icon anywhere on the practice screen.
        expect(find.byIcon(Icons.favorite), findsNothing);

        // Answer the first exercise incorrectly -- in a regular lesson
        // this decrements beans and, at 0, shows the out-of-beans modal;
        // in practice mode it should just show feedback and let the user
        // continue.
        await tester.tap(find.text('le'));
        await tester.pump();
        await tester.tap(find.text('Check'));
        await tester.pump();

        expect(find.byIcon(Icons.cancel), findsOneWidget);
        expect(find.text('Refill Beans'), findsNothing);

        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(find.text('ለ'), findsOneWidget);
      },
    );

    testWidgets(
      'finishing calls completePracticeSession (not completeLesson) with correctness per vocab item',
      (tester) async {
        final api = ControllableLessonApi()
          ..practiceCompletionResult = const PracticeCompletionResult(
            xpEarned: 10,
            amoleEarned: 10,
            correctCount: 1,
            totalCount: 2,
            accuracyPercent: 50,
          );
        await tester.pumpWidget(
          _wrappedPractice(
            api,
            content: _multipleChoice,
            vocabItemIdByExerciseId: const {'mc-1': 'vocab-1', 'mc-2': 'vocab-2'},
          ),
        );
        await tester.pumpAndSettle();

        // mc-1 (prompt 'ሀ') answered wrong ('le' instead of correct 'ha') --
        // requeued to the end, same retry mechanics as a regular lesson.
        await tester.tap(find.text('le'));
        await tester.pump();
        await tester.tap(find.text('Check'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pump();

        // mc-2 (prompt 'ለ') answered correctly.
        await tester.tap(find.text('le'));
        await tester.pump();
        await tester.tap(find.text('Check'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pump();

        // "Let's review your mistakes" interstitial, then the requeued
        // mc-1 reappears -- answer it correctly this time.
        expect(find.text("Let's review your mistakes"), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.tap(find.text('ha'));
        await tester.pump();
        await tester.tap(find.text('Check'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.text('Lesson Complete!'), findsOneWidget);
        expect(api.completeLessonCalls, isEmpty);
        expect(api.completePracticeSessionCalls, hasLength(1));
        final call = api.completePracticeSessionCalls.single;
        expect(
          call.results.map((r) => (r.vocabItemId, r.correct)),
          containsAll(const [('vocab-1', false), ('vocab-2', true)]),
        );
      },
    );
  });
}
