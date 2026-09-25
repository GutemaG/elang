// Both picture question types in a lesson and in practice
// (019-image-choice-exercise-types, bolt 053, story 002): the prompt, the
// grid, grading, the audio type's clip, and the offline rule for a cached
// copy.

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/practice_completion_result.dart';
import 'package:elang/shared/services/course_cache_store.dart';
import 'package:elang/shared/services/lesson_audio_player.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/widgets/exercise/answer_action_bar.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/exercise/audio_play_button.dart';
import 'package:elang/shared/widgets/exercise/exercise_layout.dart';
import 'package:elang/shared/widgets/exercise/picture_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

const _clip = 'https://cdn.buna.app/audio/wusha.mp3';

const _image = ImageChoiceExercise(
  id: 'ic',
  prompt: "Choose the picture: 'ውሻ'",
  choices: [
    PictureChoice(imageUrl: 'assets/pictures/cat.webp', altText: 'A cat'),
    PictureChoice(
      imageUrl: 'https://example.com/media/images/dog.webp',
      altText: 'A dog',
    ),
    PictureChoice(imageUrl: 'assets/pictures/house.webp', altText: 'A house'),
  ],
  correctOptionIndex: 1,
);

const _audioImage = AudioImageChoiceExercise(
  id: 'aic',
  audioUrl: _clip,
  // Written the way seeded prompts are; the word must still never show.
  instruction: "Tap the picture you hear: 'ውሻ'",
  choices: [
    PictureChoice(imageUrl: 'assets/pictures/dog.webp', altText: 'A dog'),
    PictureChoice(imageUrl: 'assets/pictures/water.webp', altText: 'Water'),
  ],
  correctOptionIndex: 0,
);

const _mc = MultipleChoiceExercise(
  id: 'mc',
  prompt: 'ቡና',
  promptTranslation: 'What does this word mean?',
  options: ['Coffee', 'Tea'],
  correctOptionIndex: 0,
);

LessonContent _lesson(List<Exercise> exercises, {int beans = 5}) =>
    LessonContent(
      lessonId: 'lesson-pictures',
      skillId: 'skill-pictures',
      title: 'Pictures',
      beansAtStart: beans,
      beansMax: 5,
      exercises: exercises,
    );

ControllableLessonApi _api(LessonContent content) => ControllableLessonApi()
  ..lessonContent = content
  ..completionResult = const LessonCompletionResult(
    xpEarned: 10,
    dailyXpTotal: 10,
    dailyXpTarget: 30,
    streakCount: 1,
    streakIncreasedToday: true,
    accuracyPercent: 100,
    correctCount: 1,
    totalCount: 1,
    timeSpent: Duration(seconds: 10),
  )
  ..beansStatus = BeansStatus(
    beans: 0,
    beansMax: 5,
    nextBeanAt: DateTime.now().add(const Duration(minutes: 30)),
    regenMinutesPerBean: 30,
    amoleBalance: 420,
    refillCostAmole: 350,
  );

Widget _app(
  ControllableLessonApi api, {
  LessonAudioPlayer? audio,
  bool online = true,
  CourseCacheStore? cache,
}) {
  final connectivity = FakeConnectivityMonitor(online: online);
  return MaterialApp(
    home: LessonScreen(
      lessonId: 'lesson-pictures',
      lessonApi: api,
      audioPlayer: audio ?? FakeLessonAudioPlayer(),
      feedbackPlayer: FakeAnswerFeedbackPlayer(),
      connectivityMonitor: connectivity,
      lessonPackStore: FakeLessonPackStore(),
      syncEngine: SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: FakePendingSyncQueueStore(),
      ),
      lessonCache: cache,
    ),
  );
}

Finder _picture(String altText) =>
    find.byWidgetPredicate((w) => w is PictureTile && w.altText == altText);

PictureTile _tileOf(WidgetTester tester, String altText) =>
    tester.widget<PictureTile>(_picture(altText));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

int _beans(WidgetTester tester) =>
    tester.widget<ExerciseTopBar>(find.byType(ExerciseTopBar)).beans!;

AnswerGrade? _grade(WidgetTester tester) =>
    tester.widget<AnswerActionBar>(find.byType(AnswerActionBar)).grade;

void main() {
  group('image choice', () {
    testWidgets('the split prompt sits above a grid of the pictures, in the '
        'server\'s order', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_image]))));
      await tester.pumpAndSettle();

      final prompt = tester.widget<QuestionPrompt>(find.byType(QuestionPrompt));
      expect(prompt.instruction, 'Choose the picture');
      expect(prompt.question, 'ውሻ');

      expect(find.byType(PictureGrid), findsOneWidget);
      final tiles = tester.widgetList<PictureTile>(find.byType(PictureTile));
      expect(tiles.map((t) => t.altText), ['A cat', 'A dog', 'A house']);
      expect(
        tester.getTopLeft(find.byType(PictureGrid)).dy,
        greaterThan(tester.getBottomLeft(find.byType(QuestionPrompt)).dy),
      );
      // No play button: nothing is heard.
      expect(find.byType(AudioPlayButton), findsNothing);
    });

    testWidgets('bundled pictures load from the app, the rest from the '
        'network', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_image]))));
      await tester.pumpAndSettle();

      expect(
        _tileOf(tester, 'A cat').image,
        const AssetImage('assets/pictures/cat.webp'),
      );
      expect(
        _tileOf(tester, 'A dog').image,
        const NetworkImage('https://example.com/media/images/dog.webp'),
      );
    });

    testWidgets('a right tap grades only that picture, costs nothing, and no '
        'picture takes another tap', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_image, _mc]))));
      await tester.pumpAndSettle();

      await _tap(tester, _picture('A dog'));
      await tester.pumpAndSettle();

      expect(_tileOf(tester, 'A dog').state, AnswerTileState.correct);
      expect(_tileOf(tester, 'A cat').state, AnswerTileState.idle);
      expect(_tileOf(tester, 'A house').state, AnswerTileState.idle);
      expect(
        tester
            .widgetList<PictureTile>(find.byType(PictureTile))
            .every((t) => t.onTap == null),
        isTrue,
      );
      expect(_grade(tester), AnswerGrade.correct);
      expect(_beans(tester), 5);
    });

    testWidgets('a wrong tap shakes that picture, costs a bean, and a second '
        'tap changes nothing', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_image, _mc]))));
      await tester.pumpAndSettle();

      await _tap(tester, _picture('A cat'));
      await tester.pump(AppMotion.shake ~/ 12);
      final shaking = tester.widget<Transform>(
        find
            .descendant(of: _picture('A cat'), matching: find.byType(Transform))
            .first,
      );
      expect(shaking.transform.getTranslation().x.abs(), greaterThan(0));
      await tester.pumpAndSettle();

      expect(_tileOf(tester, 'A cat').state, AnswerTileState.incorrect);
      expect(_tileOf(tester, 'A dog').state, AnswerTileState.idle);
      expect(_grade(tester), AnswerGrade.incorrect);
      expect(_beans(tester), 4);

      await tester.tap(_picture('A dog'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_tileOf(tester, 'A dog').state, AnswerTileState.idle);
      expect(_beans(tester), 4);
    });

    testWidgets('a missed picture question comes back after the others, and '
        'is reported as missed', (tester) async {
      final api = _api(_lesson([_image, _mc]));
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await _tap(tester, _picture('A house')); // wrong
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Coffee'));
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text("Let's review your mistakes"), findsOneWidget);
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();

      // Back, ungraded.
      expect(find.byType(PictureGrid), findsOneWidget);
      expect(
        tester
            .widgetList<PictureTile>(find.byType(PictureTile))
            .map((t) => t.state)
            .toSet(),
        {AnswerTileState.idle},
      );
      await _tap(tester, _picture('A dog'));
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();

      final call = api.completeLessonCalls.single;
      expect(call.missedExerciseIds, ['ic']);
      expect(call.totalCount, 2);
      expect(call.beansRemainingAtEnd, 4);
    });
  });

  group('audio image choice', () {
    testWidgets('only the instruction and the play button: the word is never '
        'written', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_audioImage]))));
      await tester.pumpAndSettle();

      final prompt = tester.widget<QuestionPrompt>(find.byType(QuestionPrompt));
      expect(prompt.instruction, 'Tap the picture you hear');
      expect(prompt.question, isNull);
      expect(prompt.translation, isNull);
      expect(find.textContaining('ውሻ'), findsNothing);

      expect(find.byType(AudioPlayButton), findsOneWidget);
      expect(find.text('Tap to play/replay'), findsOneWidget);
      expect(find.byType(PictureTile), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.byType(PictureGrid)).dy,
        greaterThan(tester.getBottomLeft(find.byType(AudioPlayButton)).dy),
      );
    });

    testWidgets('the clip plays once by itself, not again on an answer or a '
        'rebuild, and the button replays it', (tester) async {
      final audio = FakeLessonAudioPlayer();
      final api = _api(_lesson([_audioImage, _mc]));
      await tester.pumpWidget(_app(api, audio: audio));
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip]);

      // A rebuild of the same screen.
      await tester.pumpWidget(_app(api, audio: audio));
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip]);

      await _tap(tester, _picture('A dog'));
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip]);

      await _tap(tester, find.byType(AudioPlayButton));
      expect(audio.playedUrls, [_clip, _clip]);
    });

    testWidgets('it plays when it is the next question, and again when it '
        'comes back after a miss', (tester) async {
      final audio = FakeLessonAudioPlayer();
      await tester.pumpWidget(
        _app(_api(_lesson([_mc, _audioImage])), audio: audio),
      );
      await tester.pumpAndSettle();
      expect(audio.playedUrls, isEmpty);

      await _tap(tester, find.text('Coffee'));
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip]);

      await _tap(tester, _picture('Water')); // wrong
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip]); // not on the review page
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip, _clip]);
    });

    testWidgets('graded by index like the others', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_audioImage]))));
      await tester.pumpAndSettle();

      await _tap(tester, _picture('Water'));
      await tester.pumpAndSettle();
      expect(_tileOf(tester, 'Water').state, AnswerTileState.incorrect);
      expect(_tileOf(tester, 'A dog').state, AnswerTileState.idle);
      expect(_beans(tester), 4);
    });
  });

  group('practice', () {
    testWidgets('a due word asked as a picture question is graded there, and '
        'its review is reported', (tester) async {
      final api = ControllableLessonApi()
        ..practiceCompletionResult = const PracticeCompletionResult(
          xpEarned: 5,
          amoleEarned: 5,
          correctCount: 2,
          totalCount: 2,
          accuracyPercent: 100,
        );
      final connectivity = FakeConnectivityMonitor();
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen.practice(
            practiceContent: _lesson([_image, _audioImage]),
            practiceVocabItemIdByExerciseId: const {
              'ic': 'vocab-dog',
              'aic': 'vocab-dog-heard',
            },
            lessonApi: api,
            audioPlayer: FakeLessonAudioPlayer(),
            feedbackPlayer: FakeAnswerFeedbackPlayer(),
            syncEngine: SyncEngine(
              lessonApi: api,
              connectivityMonitor: connectivity,
              queueStore: FakePendingSyncQueueStore(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PictureGrid), findsOneWidget);
      await _tap(tester, _picture('A dog'));
      expect(_tileOf(tester, 'A dog').state, AnswerTileState.correct);
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      await _tap(tester, _picture('A dog'));
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.completeLessonCalls, isEmpty);
      final results = api.completePracticeSessionCalls.single.results;
      expect(results.map((r) => (r.vocabItemId, r.correct)), [
        ('vocab-dog', true),
        ('vocab-dog-heard', true),
      ]);
    });
  });

  group('offline, a cached copy', () {
    testWidgets('with only image choice plays like a pack', (tester) async {
      final cache = InMemoryCourseCacheStore();
      await cache.saveLesson(_lesson([_image]));

      await tester.pumpWidget(
        _app(_api(_lesson([_mc])), online: false, cache: cache),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PictureGrid), findsOneWidget);
      expect(find.text('Choose the picture'), findsOneWidget);
    });

    testWidgets('with an audio image choice still asks for a download: its '
        'clip needs the network', (tester) async {
      final cache = InMemoryCourseCacheStore();
      await cache.saveLesson(_lesson([_image, _audioImage]));

      await tester.pumpWidget(
        _app(_api(_lesson([_mc])), online: false, cache: cache),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PictureGrid), findsNothing);
      expect(
        find.text('Download this lesson while online to take it offline.'),
        findsOneWidget,
      );
    });
  });
}
