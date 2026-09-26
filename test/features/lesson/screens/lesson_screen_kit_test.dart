// The lesson on the question kit (018-mobile-design-system, bolt 045):
// every question type in the one frame, the first play of a question's
// audio, one Continue per tap, and the loading, error, offline and
// mistake-review pages on the design library.

import 'dart:async';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/lesson_audio_player.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_page.dart';
import 'package:elang/shared/widgets/app_sheet.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:elang/shared/widgets/exercise/answer_action_bar.dart';
import 'package:elang/shared/widgets/exercise/answer_slot_line.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/exercise/audio_play_button.dart';
import 'package:elang/shared/widgets/exercise/exercise_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

const _clip = 'https://cdn.buna.app/audio/selam.mp3';

const _mc = MultipleChoiceExercise(
  id: 'mc',
  prompt: 'ቡና',
  promptTranslation: 'What does this word mean?',
  options: ['Coffee', 'Tea', 'Water'],
  correctOptionIndex: 0,
);
const _listen = ListeningExercise(
  id: 'li',
  audioUrl: _clip,
  instruction: 'Tap what you hear',
  options: ['ሰላም', 'ደህና ሁን', 'አመሰግናለሁ'],
  correctOptionIndex: 0,
);
const _sentence = SentenceConstructionExercise(
  id: 'sc',
  promptTranslation: "Translate: 'I want coffee'",
  wordBank: ['ቡና', 'እፈልጋለሁ', 'ሻይ', 'እኔ'],
  correctSentence: ['እኔ', 'ቡና', 'እፈልጋለሁ'],
);
const _pairs = MatchPairsExercise(
  id: 'mp',
  prompt: 'Match each word to its meaning',
  leftTiles: [
    MatchPairsTile(id: 'l1', text: 'ቡና'),
    MatchPairsTile(id: 'l2', text: 'ሻይ'),
  ],
  rightTiles: [
    MatchPairsTile(id: 'r2', text: 'Tea'),
    MatchPairsTile(id: 'r1', text: 'Coffee'),
  ],
  correctPairs: {'l1': 'r1', 'l2': 'r2'},
);
const _gap = GapFillExercise(
  id: 'gf',
  prompt: "Complete the sentence: 'I want water'",
  sentenceBefore: 'እኔ',
  sentenceAfter: 'እፈልጋለሁ',
  options: ['ውሃ', 'ዳቦ'],
  correctOptionIndex: 0,
);
// Pictures from the network: in a test they never arrive, so the tiles
// show their descriptions, the most text a picture tile holds.
const _image = ImageChoiceExercise(
  id: 'ic',
  prompt: "Choose the picture: 'ውሻ'",
  choices: [
    PictureChoice(
      imageUrl: 'https://cdn.buna.app/p/dog.webp',
      altText: 'A dog',
    ),
    PictureChoice(
      imageUrl: 'https://cdn.buna.app/p/cat.webp',
      altText: 'A cat',
    ),
    PictureChoice(
      imageUrl: 'https://cdn.buna.app/p/house.webp',
      altText: 'A house',
    ),
  ],
  correctOptionIndex: 0,
);
const _audioImage = AudioImageChoiceExercise(
  id: 'aic',
  audioUrl: _clip,
  instruction: 'Tap the picture you hear',
  choices: [
    PictureChoice(imageUrl: 'assets/pictures/water.webp', altText: 'Water'),
    PictureChoice(imageUrl: 'assets/pictures/dog.webp', altText: 'A dog'),
    PictureChoice(imageUrl: 'assets/pictures/house.webp', altText: 'A house'),
    PictureChoice(imageUrl: 'assets/pictures/cat.webp', altText: 'A cat'),
  ],
  correctOptionIndex: 3,
);

// ፍራፍሬ: two ፍ tiles (bolt 033).
const _spell = SpellTilesExercise(
  id: 'sp',
  prompt: "Spell 'Fruit'",
  tiles: [
    SpellTile(id: 'f2', text: 'ፍ'),
    SpellTile(id: 'r2', text: 'ሬ'),
    SpellTile(id: 'd1', text: 'ቡ'),
    SpellTile(id: 'f1', text: 'ፍ'),
    SpellTile(id: 'r1', text: 'ራ'),
  ],
  correctSequence: ['f1', 'r1', 'f2', 'r2'],
);

LessonContent _lesson(List<Exercise> exercises, {int beans = 5}) =>
    LessonContent(
      lessonId: 'lesson-kit',
      skillId: 'skill-kit',
      title: 'Kit',
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
  )
  ..refillResult = const RefillSuccess(newBeans: 5, newAmoleBalance: 70);

Widget _app(
  ControllableLessonApi api, {
  LessonAudioPlayer? audio,
  bool online = true,
  double scale = 1,
}) {
  final connectivity = FakeConnectivityMonitor(online: online);
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: LessonScreen(
      lessonId: 'lesson-kit',
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
    ),
  );
}

void _phone(WidgetTester tester, {double width = 400, double height = 800}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The answer tile labelled [label] (a word can also sit in a gap or on
/// the answer line).
Finder _tile(String label) =>
    find.descendant(of: find.byType(AnswerTile), matching: find.text(label));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Answers the question on screen correctly.
Future<void> _answerRight(WidgetTester tester, Exercise exercise) async {
  switch (exercise) {
    case MultipleChoiceExercise e:
      await _tap(tester, _tile(e.options[e.correctOptionIndex]));
    case ListeningExercise e:
      await _tap(tester, _tile(e.options[e.correctOptionIndex]));
    case GapFillExercise e:
      await _tap(tester, _tile(e.options[e.correctOptionIndex]));
    case SentenceConstructionExercise e:
      for (final word in e.correctSentence) {
        await _tap(tester, _tile(word).last);
      }
      await _tap(tester, find.text('Check'));
    case MatchPairsExercise e:
      final text = {
        for (final t in [...e.leftTiles, ...e.rightTiles]) t.id: t.text,
      };
      for (final MapEntry(key: left, value: right) in e.correctPairs.entries) {
        await _tap(tester, _tile(text[left]!));
        await _tap(tester, _tile(text[right]!));
      }
    case ImageChoiceExercise e:
      await _tap(tester, _picture(e.choices[e.correctOptionIndex].altText));
    case AudioImageChoiceExercise e:
      await _tap(tester, _picture(e.choices[e.correctOptionIndex].altText));
    case SpellTilesExercise e:
      for (final id in e.correctSequence) {
        await _tap(tester, find.byKey(ValueKey('bank-$id')));
      }
      await _tap(tester, find.text('Check'));
  }
}

/// The picture tile described as [altText]: its picture shows no text.
Finder _picture(String altText) =>
    find.byWidgetPredicate((w) => w is AnswerTile && w.label == altText);

/// Where the frame puts things, for comparing question types.
({Rect topBar, Offset prompt, Rect actionBar, double firstTileLeft}) _frame(
  WidgetTester tester,
) => (
  topBar: tester.getRect(find.byType(ExerciseTopBar)),
  prompt: tester.getTopLeft(find.byType(QuestionPrompt)),
  actionBar: tester.getRect(find.byType(AnswerActionBar)),
  firstTileLeft: tester.getTopLeft(find.byType(AnswerTile).first).dx,
);

class _GatedAudioPlayer implements LessonAudioPlayer {
  final List<String> playedUrls = [];
  Completer<void> gate = Completer<void>();

  @override
  Future<void> play(String url) {
    playedUrls.add(url);
    return gate.future;
  }

  @override
  Future<void> dispose() async {}
}

class _FailingAudioPlayer implements LessonAudioPlayer {
  int attempts = 0;

  @override
  Future<void> play(String url) async {
    attempts++;
    throw Exception('no network');
  }

  @override
  Future<void> dispose() async {}
}

class _SlowStartApi extends ControllableLessonApi {
  final gate = Completer<void>();

  @override
  Future<LessonContent> startLesson(String lessonId) async {
    await gate.future;
    return super.startLesson(lessonId);
  }
}

void main() {
  group('one frame for every question type', () {
    testWidgets('the top bar, prompt, answers and action bar sit in the same '
        'place for all eight types', (tester) async {
      _phone(tester);
      const exercises = [
        _mc,
        _listen,
        _sentence,
        _pairs,
        _gap,
        _image,
        _audioImage,
        _spell,
      ];
      await tester.pumpWidget(_app(_api(_lesson(exercises))));
      await tester.pumpAndSettle();

      final frames = <String, dynamic>{};
      for (final exercise in exercises) {
        expect(find.byType(ExerciseLayout), findsOneWidget);
        expect(find.byType(QuestionPrompt), findsOneWidget);
        expect(find.byType(AnswerActionBar), findsOneWidget);
        expect(find.byType(AnswerTile), findsWidgets);
        frames[exercise.id] = _frame(tester);

        await _answerRight(tester, exercise);
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Continue'));
        await tester.pumpAndSettle();
      }

      final first = frames[_mc.id];
      for (final MapEntry(:key, :value) in frames.entries) {
        expect(value, first, reason: key);
      }
    });

    testWidgets('the top bar shows how far through the lesson and the beans '
        'left', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_mc, _gap, _pairs]))));
      await tester.pumpAndSettle();
      ExerciseTopBar bar() =>
          tester.widget<ExerciseTopBar>(find.byType(ExerciseTopBar));

      expect(bar().progress, closeTo(1 / 3, 1e-9));
      expect((bar().beans, bar().beansMax), (5, 5));

      await _tap(tester, _tile('Tea')); // wrong: one bean
      expect(bar().beans, 4);
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(bar().progress, closeTo(2 / 3, 1e-9));
    });

    testWidgets('choice rows are 12 px apart, as in the gallery', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_api(_lesson([_mc]))));
      await tester.pumpAndSettle();

      final tiles = find.byType(AnswerTile);
      final gap =
          tester.getTopLeft(tiles.at(1)).dy -
          tester.getBottomLeft(tiles.at(0)).dy;
      expect(gap, 12);
    });

    testWidgets('a bare word with a gloss asks the gloss and shows the word '
        'as the question', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_mc]))));
      await tester.pumpAndSettle();

      final prompt = tester.widget<QuestionPrompt>(find.byType(QuestionPrompt));
      expect(prompt.instruction, 'What does this word mean?');
      expect(prompt.question, 'ቡና');
    });

    testWidgets('an "Instruction: \'content\'" prompt is split, and a plain '
        'one is the headline', (tester) async {
      await tester.pumpWidget(
        _app(
          _api(
            _lesson([
              _gap,
              const MultipleChoiceExercise(
                id: 'mc-en',
                prompt: "How do you say 'Hello' in Amharic?",
                promptTranslation: '',
                options: ['ሰላም', 'አዎ'],
                correctOptionIndex: 0,
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var prompt = tester.widget<QuestionPrompt>(find.byType(QuestionPrompt));
      expect(prompt.instruction, 'Complete the sentence');
      expect(prompt.question, 'I want water');

      await _answerRight(tester, _gap);
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();

      prompt = tester.widget<QuestionPrompt>(find.byType(QuestionPrompt));
      expect(prompt.instruction, "How do you say 'Hello' in Amharic?");
      expect(prompt.question, isNull);
      expect(prompt.translation, isNull);
    });

    testWidgets('gap fill puts the chosen word in the gap, in the grade '
        'colour', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_gap]))));
      await tester.pumpAndSettle();

      await _tap(tester, _tile('ዳቦ'));
      final line = tester.widget<AnswerSlotLine>(find.byType(AnswerSlotLine));
      expect(line.filled, 'ዳቦ');
      expect(line.grade, AnswerGrade.incorrect);
      expect(
        tester.widget<AnswerTile>(find.byType(AnswerTile).at(1)).state,
        AnswerTileState.incorrect,
      );
      expect(
        tester.widget<AnswerTile>(find.byType(AnswerTile).at(0)).state,
        AnswerTileState.idle,
      );
      // Graded: no choice takes a tap, so the others show as finished.
      expect(
        tester
            .widgetList<AnswerTile>(find.byType(AnswerTile))
            .every((t) => t.onTap == null),
        isTrue,
      );
    });

    testWidgets('the sentence builder: placed words on the line, used words '
        'dimmed in the bank, and the grade on the placed words', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_api(_lesson([_sentence]))));
      await tester.pumpAndSettle();

      final check = find.widgetWithText(AppButton, 'Check');
      expect(tester.widget<AppButton>(check).onPressed, isNull);

      await _tap(tester, _tile('እኔ'));
      expect(tester.widget<AppButton>(check).onPressed, isNotNull);
      final line = find.byType(AnswerSlotLine);
      expect(
        find.descendant(of: line, matching: find.text('እኔ')),
        findsOneWidget,
      );
      final bankTile = tester
          .widgetList<AnswerTile>(find.byType(AnswerTile))
          .where((t) => t.label == 'እኔ' && t.state == AnswerTileState.used);
      expect(bankTile, hasLength(1));

      await _tap(tester, _tile('ቡና').last);
      await _tap(tester, _tile('እፈልጋለሁ').last);
      await _tap(tester, find.text('Check'));

      final placed = tester.widgetList<AnswerTile>(
        find.descendant(of: line, matching: find.byType(AnswerTile)),
      );
      expect(placed.map((t) => t.state).toSet(), {AnswerTileState.correct});
      expect(placed.every((t) => t.onTap == null), isTrue);
      expect(tester.widget<AnswerSlotLine>(line).grade, AnswerGrade.correct);
    });

    testWidgets('match pairs: side-by-side tiles are the same height, Fidel '
        'beside Latin', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_pairs])), scale: 1.3));
      await tester.pumpAndSettle();

      final left = tester.getRect(find.widgetWithText(AnswerTile, 'ቡና'));
      final right = tester.getRect(find.widgetWithText(AnswerTile, 'Tea'));
      expect(right.top, left.top);
      expect(right.height, left.height);
      expect(left.left, lessThan(right.left));
    });

    testWidgets('match pairs: armed is selected, a wrong pair turns '
        'incorrect, a right pair is locked correct', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_pairs]))));
      await tester.pumpAndSettle();
      AnswerTile tile(String label) =>
          tester.widget<AnswerTile>(find.widgetWithText(AnswerTile, label));

      await _tap(tester, _tile('ቡና'));
      expect(tile('ቡና').state, AnswerTileState.selected);

      await _tap(tester, _tile('Tea'));
      expect(tile('ቡና').state, AnswerTileState.incorrect);
      expect(tile('Tea').state, AnswerTileState.incorrect);
      await tester.pump(const Duration(seconds: 1));
      expect(tile('ቡና').state, AnswerTileState.idle);

      await _tap(tester, _tile('ቡና'));
      await _tap(tester, _tile('Coffee'));
      expect(tile('ቡና').state, AnswerTileState.correct);
      expect(tile('ቡና').onTap, isNull);
      expect(tile('Coffee').state, AnswerTileState.correct);
    });

    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('no overflow in any type at ${width}px and ${scale}x, '
            'before and after answering', (tester) async {
          _phone(tester, width: width, height: 640);
          const exercises = [
            _mc,
            _listen,
            _sentence,
            _pairs,
            _gap,
            _image,
            _audioImage,
            _spell,
          ];
          await tester.pumpWidget(_app(_api(_lesson(exercises)), scale: scale));
          await tester.pumpAndSettle();
          for (final exercise in exercises) {
            expect(tester.takeException(), isNull, reason: exercise.id);
            await _answerRight(tester, exercise);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: exercise.id);
            await _tap(tester, find.text('Continue'));
            await tester.pumpAndSettle();
          }
        });
      }
    }
  });

  group('a question with audio plays it once by itself', () {
    testWidgets('it plays when the question appears, and not again on an '
        'answer or a rebuild', (tester) async {
      final audio = FakeLessonAudioPlayer();
      await tester.pumpWidget(
        _app(_api(_lesson([_listen, _mc])), audio: audio),
      );
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip]);

      await _tap(tester, _tile('ሰላም'));
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip]);

      await _tap(tester, find.byType(AudioPlayButton));
      expect(audio.playedUrls, [_clip, _clip]);
    });

    testWidgets('a question without audio plays nothing', (tester) async {
      final audio = FakeLessonAudioPlayer();
      await tester.pumpWidget(
        _app(_api(_lesson([_mc, _gap, _sentence])), audio: audio),
      );
      await tester.pumpAndSettle();
      for (final exercise in [_mc, _gap, _sentence]) {
        await _answerRight(tester, exercise);
        await _tap(tester, find.text('Continue'));
        await tester.pumpAndSettle();
      }
      expect(audio.playedUrls, isEmpty);
    });

    testWidgets('it plays when the next question is a listening one', (
      tester,
    ) async {
      final audio = FakeLessonAudioPlayer();
      await tester.pumpWidget(
        _app(_api(_lesson([_mc, _listen])), audio: audio),
      );
      await tester.pumpAndSettle();
      expect(audio.playedUrls, isEmpty);

      await _answerRight(tester, _mc);
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip]);
    });

    testWidgets('a missed listening question plays again when it comes back', (
      tester,
    ) async {
      final audio = FakeLessonAudioPlayer();
      await tester.pumpWidget(
        _app(_api(_lesson([_listen, _mc])), audio: audio),
      );
      await tester.pumpAndSettle();

      await _tap(tester, _tile('ደህና ሁን')); // wrong
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      await _answerRight(tester, _mc);
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text("Let's review your mistakes"), findsOneWidget);
      expect(audio.playedUrls, [_clip]); // not on the review page

      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Tap what you hear'), findsOneWidget);
      expect(audio.playedUrls, [_clip, _clip]);
    });

    testWidgets('after an out-of-beans refill the answered question does not '
        'play again', (tester) async {
      final audio = FakeLessonAudioPlayer();
      await tester.pumpWidget(
        _app(_api(_lesson([_listen, _mc], beans: 1)), audio: audio),
      );
      await tester.pumpAndSettle();
      expect(audio.playedUrls, [_clip]);

      await _tap(tester, _tile('ደህና ሁን')); // wrong, last bean
      await tester.pumpAndSettle();
      expect(find.text('Out of Beans!'), findsOneWidget);
      await tester.tap(find.textContaining('Refill with'));
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
      expect(audio.playedUrls, [_clip]);
    });

    testWidgets('the button shows "playing" until the clip has started', (
      tester,
    ) async {
      final audio = _GatedAudioPlayer();
      await tester.pumpWidget(_app(_api(_lesson([_listen])), audio: audio));
      await tester.pump();
      await tester.pump();
      AudioPlayButton button() =>
          tester.widget<AudioPlayButton>(find.byType(AudioPlayButton));

      expect(audio.playedUrls, [_clip]);
      expect(button().playing, isTrue);

      audio.gate.complete();
      await tester.pumpAndSettle();
      expect(button().playing, isFalse);

      // A tap while the first play is still starting keeps "playing" on
      // until the last one has started.
      final first = audio.gate = Completer<void>();
      await _tap(tester, find.byType(AudioPlayButton));
      final second = audio.gate = Completer<void>();
      await _tap(tester, find.byType(AudioPlayButton));
      expect(button().playing, isTrue);
      first.complete();
      await tester.pumpAndSettle();
      expect(button().playing, isTrue);
      second.complete();
      await tester.pumpAndSettle();
      expect(button().playing, isFalse);
    });

    testWidgets('a clip that fails to play is ignored, and play can be '
        'tapped again', (tester) async {
      final audio = _FailingAudioPlayer();
      await tester.pumpWidget(_app(_api(_lesson([_listen])), audio: audio));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(audio.attempts, 1);
      expect(
        tester.widget<AudioPlayButton>(find.byType(AudioPlayButton)).playing,
        isFalse,
      );

      await _tap(tester, find.byType(AudioPlayButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(audio.attempts, 2);
    });
  });

  group('Continue', () {
    testWidgets('a double tap on the last question saves the lesson once', (
      tester,
    ) async {
      final api = _api(_lesson([_mc]));
      final gate = Completer<void>();
      api.completeLessonGate = gate.future;
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await _answerRight(tester, _mc);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(api.completeLessonCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();
      expect(api.completeLessonCalls, hasLength(1));
    });

    testWidgets('a double tap mid-lesson moves on one question', (
      tester,
    ) async {
      final api = _api(_lesson([_mc, _gap, _pairs]));
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await _answerRight(tester, _mc);
      await tester.pumpAndSettle();
      final continueButton = find.text('Continue');
      await tester.tap(continueButton);
      await tester.tap(continueButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AnswerSlotLine), findsOneWidget); // the gap question
    });
  });

  group('pages that are not a question', () {
    testWidgets('loading shows LoadingState with a way out', (tester) async {
      final api = _SlowStartApi()..lessonContent = _lesson([_mc]);
      await tester.pumpWidget(_app(api));
      await tester.pump();

      expect(find.byType(AppPage), findsOneWidget);
      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.byTooltip('Exit lesson'), findsOneWidget);

      api.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LoadingState), findsNothing);
      expect(find.byType(ExerciseLayout), findsOneWidget);
    });

    testWidgets('a failed load shows ErrorState, and Try again loads the '
        'lesson', (tester) async {
      final api = _api(_lesson([_mc]))..startLessonError = Exception('boom');
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text("Couldn't load this lesson."), findsOneWidget);

      api.startLessonError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('offline without a download shows EmptyState', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_mc])), online: false));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Go back'), findsOneWidget);
    });

    testWidgets('the mistake review is a SheetHero with the count badge, the '
        'same top bar, and Continue where the questions have it', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_api(_lesson([_mc, _gap]))));
      await tester.pumpAndSettle();

      await _tap(tester, _tile('Tea')); // wrong
      await tester.pumpAndSettle();
      final questionBar = tester.getRect(find.byType(ExerciseTopBar));
      final questionButton = tester.getRect(
        find.widgetWithText(AppButton, 'Continue'),
      );
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      await _answerRight(tester, _gap);
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(SheetHero), findsOneWidget);
      expect(find.text('1 mistake'), findsOneWidget);
      expect(tester.getRect(find.byType(ExerciseTopBar)), questionBar);
      expect(
        tester.getRect(find.widgetWithText(AppButton, 'Continue')),
        questionButton,
      );
    });
  });
}
