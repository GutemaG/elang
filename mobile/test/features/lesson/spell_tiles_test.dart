// Spell from tiles (016-spell-from-tiles-exercise-type, bolt 033): the
// model grades by spelled text, the API keeps every tile's id, the screen
// places and removes tiles by id, and a downloaded pack plays offline.
//
// The repeated-character tests come first and carry the weight: a word
// like `ቡና` passes against a text-keyed implementation, so every test
// that matters here spells a word with twins (`ፍራፍሬ`, `Maaloo`).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/features/lesson/state/lesson_controller.dart';
import 'package:elang/features/lesson/widgets/spell_tiles_builder.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_lesson_api.dart';
import 'package:elang/shared/services/http_lesson_api.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/exercise/answer_action_bar.dart';
import 'package:elang/shared/widgets/exercise/answer_slot_line.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/exercise/exercise_layout.dart';

import '../../helpers/controllable_lesson_api.dart';
import '../../helpers/fake_answer_feedback_player.dart';
import '../../helpers/fake_connectivity_monitor.dart';
import '../../helpers/fake_lesson_audio_player.dart';
import '../../helpers/fake_lesson_pack_store.dart';
import '../../helpers/fake_pending_sync_queue_store.dart';
import '../../helpers/in_memory_secure_storage_service.dart';
import '../../helpers/json_round_trip_pack_store.dart';

// ፍራፍሬ ("fruit"): f1 and f2 are both ፍ. The served order uses f1 first.
const _fruit = SpellTilesExercise(
  id: 'spell-fruit',
  prompt: "Spell 'Fruit'",
  tiles: [
    SpellTile(id: 'f2', text: 'ፍ'),
    SpellTile(id: 'r2', text: 'ሬ'),
    SpellTile(id: 'd1', text: 'ቡ'),
    SpellTile(id: 'f1', text: 'ፍ'),
    SpellTile(id: 'd2', text: 'ና'),
    SpellTile(id: 'r1', text: 'ራ'),
  ],
  correctSequence: ['f1', 'r1', 'f2', 'r2'],
);

const _mc = MultipleChoiceExercise(
  id: 'mc',
  prompt: 'ቡና',
  promptTranslation: 'What does this word mean?',
  options: ['Coffee', 'Tea'],
  correctOptionIndex: 0,
);

const _completion = LessonCompletionResult(
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

LessonContent _lesson(List<Exercise> exercises, {String id = 'lesson-sp'}) =>
    LessonContent(
      lessonId: id,
      skillId: 'skill-sp',
      title: 'Fruit',
      beansAtStart: 5,
      beansMax: 5,
      exercises: exercises,
    );

Widget _screen(
  ControllableLessonApi api, {
  String lessonId = 'lesson-sp',
  bool online = true,
  FakeLessonPackStore? packStore,
  SyncEngine? syncEngine,
  double scale = 1,
}) {
  final connectivity = FakeConnectivityMonitor(online: online);
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: LessonScreen(
      lessonId: lessonId,
      lessonApi: api,
      audioPlayer: FakeLessonAudioPlayer(),
      feedbackPlayer: FakeAnswerFeedbackPlayer(),
      connectivityMonitor: connectivity,
      lessonPackStore: packStore ?? FakeLessonPackStore(),
      syncEngine:
          syncEngine ??
          SyncEngine(
            lessonApi: api,
            connectivityMonitor: connectivity,
            queueStore: FakePendingSyncQueueStore(),
          ),
    ),
  );
}

ControllableLessonApi _api(List<Exercise> exercises) => ControllableLessonApi()
  ..lessonContent = _lesson(exercises)
  ..completionResult = _completion;

/// The bank tile with [id] -- found by id, since twins share their text.
Finder _bank(String id) => find.byKey(ValueKey('bank-$id'));

/// The placed tile that came from bank tile [id].
Finder _placed(String id) => find.byKey(ValueKey('placed-$id'));

AnswerTile _tile(WidgetTester tester, Finder finder) =>
    tester.widget<AnswerTile>(finder);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

bool _canCheck(WidgetTester tester) =>
    tester.widget<AnswerActionBar>(find.byType(AnswerActionBar)).canCheck;

void main() {
  group('grading, by spelled text (bolt 032, decision D3)', () {
    test('the served order is right', () {
      expect(isAnswerCorrect(_fruit, ['f1', 'r1', 'f2', 'r2']), isTrue);
    });

    test('the twins the other way round spell the same word, so it is '
        'right too', () {
      expect(isAnswerCorrect(_fruit, ['f2', 'r1', 'f1', 'r2']), isTrue);
    });

    test('the right characters in the wrong order are wrong', () {
      expect(isAnswerCorrect(_fruit, ['r1', 'f1', 'f2', 'r2']), isFalse);
    });

    test('a distractor added, or a character missing, is wrong', () {
      expect(isAnswerCorrect(_fruit, ['f1', 'r1', 'f2', 'r2', 'd1']), isFalse);
      expect(isAnswerCorrect(_fruit, ['f1', 'r1', 'f2']), isFalse);
      expect(isAnswerCorrect(_fruit, <String>[]), isFalse);
    });

    test('an id that is not one of its tiles is wrong, not a crash', () {
      expect(isAnswerCorrect(_fruit, ['f1', 'r1', 'f2', 'zz']), isFalse);
    });

    test('an answer of another shape is wrong', () {
      expect(isAnswerCorrect(_fruit, 0), isFalse);
      expect(isAnswerCorrect(_fruit, 'ፍራፍሬ'), isFalse);
    });

    test('spelled() maps ids to characters in order', () {
      expect(_fruit.spelled(['f2', 'r1']), ['ፍ', 'ራ']);
      expect(_fruit.spelled(['nope']), isNull);
    });
  });

  group('the API keeps every tile id', () {
    Future<HttpLessonApi> apiServing(Map<String, dynamic> exercise) async {
      final sessions = SessionRepository(
        storage: InMemorySecureStorageService(),
      );
      await sessions.saveSession(
        SessionState(
          token: 'token',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      final client = MockClient((request) async {
        final body = switch (request.url.path) {
          '/api/v1/lessons/lesson-a1' => {
            'lesson': {
              'id': 'lesson-a1',
              'skill_id': 'skill-a',
              'title': 'Please',
            },
            'exercises': [exercise],
          },
          '/api/v1/practice/due-items' => {
            'items': [
              {
                'vocab_item_id': 'v1',
                'word': 'Maaloo',
                'translation': 'Please',
                'exercise': exercise,
                'box_level': 1,
                'next_review_at': '2026-09-26T00:00:00Z',
              },
            ],
          },
          _ => {
            'beans': 5,
            'beans_max': 5,
            'next_bean_at': null,
            'regen_minutes_per_bean': 30,
            'amole_balance': 0,
            'refill_cost_amole': 350,
          },
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      return HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: sessions,
      );
    }

    // As served by the backend (bolt 032): Maaloo, with two `a` and two
    // `o` tiles, and a correct sequence of ids.
    const maaloo = {
      'id': 'ex-7',
      'order_index': 6,
      'type': 'spell_tiles',
      'prompt': "Spell 'Please'",
      'tiles': [
        {'id': 't1', 'text': 'a'},
        {'id': 't2', 'text': 'l'},
        {'id': 't3', 'text': 'M'},
        {'id': 't4', 'text': 'o'},
        {'id': 't5', 'text': 'a'},
        {'id': 't6', 'text': 'o'},
        {'id': 't7', 'text': 'e'},
      ],
      'correct_sequence': ['t3', 't1', 't5', 't2', 't4', 't6'],
    };

    test('a lesson spell exercise parses with every tile, twins included, '
        'and is no longer skipped', () async {
      final api = await apiServing(maaloo);
      final content = await api.startLesson('lesson-a1');

      expect(content.unrenderableCount, 0);
      final spell = content.exercises.single as SpellTilesExercise;
      expect(spell.id, 'ex-7');
      expect(spell.prompt, "Spell 'Please'");
      expect(spell.tiles.map((t) => '${t.id}=${t.text}'), [
        't1=a',
        't2=l',
        't3=M',
        't4=o',
        't5=a',
        't6=o',
        't7=e',
      ]);
      expect(spell.correctSequence, ['t3', 't1', 't5', 't2', 't4', 't6']);
      // Twins swapped both ways still grade right.
      expect(
        isAnswerCorrect(spell, ['t3', 't5', 't1', 't2', 't6', 't4']),
        isTrue,
      );
    });

    test('a practice item that is a spell exercise loads, rather than '
        'failing the whole practice session', () async {
      final api = await apiServing(maaloo);
      final items = await api.getDueItems();
      expect(items.single.exercise, isA<SpellTilesExercise>());
      expect((items.single.exercise as SpellTilesExercise).tiles, hasLength(7));
    });
  });

  group('the fake content meets the real risk', () {
    test("the fake coffee lesson has a spell exercise whose word repeats a "
        'character', () async {
      final content = await FakeLessonApi().startLesson('lesson-coffee');
      final spell = content.exercises.whereType<SpellTilesExercise>().single;
      final texts = spell.tiles.map((t) => t.text).toList();
      expect(texts.toSet().length, lessThan(texts.length));
    });
  });

  group('the screen', () {
    testWidgets('the prompt shows the word, above an empty tray and the '
        'shuffled tiles, all from the question kit', (tester) async {
      await tester.pumpWidget(_screen(_api([_fruit])));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseLayout), findsOneWidget);
      expect(find.textContaining('Fruit'), findsOneWidget);
      expect(find.byType(SpellTilesBuilder), findsOneWidget);
      expect(find.text('Tap the characters below to spell it'), findsOneWidget);
      final bank = tester
          .widgetList<AnswerTile>(
            find.descendant(
              of: find.byType(Wrap),
              matching: find.byType(AnswerTile),
            ),
          )
          .toList();
      expect(bank.map((t) => t.label), ['ፍ', 'ሬ', 'ቡ', 'ፍ', 'ና', 'ራ']);
      expect(bank.every((t) => t.shape == AnswerTileShape.pill), isTrue);
      expect(bank.every((t) => t.state == AnswerTileState.idle), isTrue);
      // The tray is below the prompt and above the bank.
      final tray = tester.getRect(find.byType(AnswerSlotLine));
      expect(
        tray.top,
        greaterThan(tester.getRect(find.textContaining('Fruit')).bottom),
      );
      expect(tray.bottom, lessThanOrEqualTo(tester.getRect(_bank('f2')).top));
    });

    testWidgets('tapping one twin places it and dims only that one; the other '
        'stays tappable', (tester) async {
      await tester.pumpWidget(_screen(_api([_fruit])));
      await tester.pumpAndSettle();

      await _tap(tester, _bank('f2'));

      expect(_tile(tester, _bank('f2')).state, AnswerTileState.used);
      expect(_tile(tester, _bank('f2')).onTap, isNull);
      expect(_tile(tester, _bank('f1')).state, AnswerTileState.idle);
      expect(_tile(tester, _bank('f1')).onTap, isNotNull);
      expect(_placed('f2'), findsOneWidget);
      expect(_tile(tester, _placed('f2')).label, 'ፍ');

      // And the second twin can be placed too, beside the first.
      await _tap(tester, _bank('f1'));
      expect(_tile(tester, _bank('f1')).state, AnswerTileState.used);
      expect(_placed('f1'), findsOneWidget);
    });

    testWidgets('removing one of two placed twins frees the tile that was '
        'tapped for it, not its twin', (tester) async {
      await tester.pumpWidget(_screen(_api([_fruit])));
      await tester.pumpAndSettle();
      await _tap(tester, _bank('f1'));
      await _tap(tester, _bank('r1'));
      await _tap(tester, _bank('f2'));

      // Remove the second ፍ on the line: the one that came from f2.
      await _tap(tester, _placed('f2'));

      expect(_placed('f2'), findsNothing);
      expect(_placed('f1'), findsOneWidget);
      expect(_tile(tester, _bank('f2')).state, AnswerTileState.idle);
      expect(_tile(tester, _bank('f1')).state, AnswerTileState.used);
      // What is left on the line keeps its order.
      final line = tester
          .widgetList<AnswerTile>(
            find.descendant(
              of: find.byType(AnswerSlotLine),
              matching: find.byType(AnswerTile),
            ),
          )
          .map((t) => t.label)
          .toList();
      expect(line, ['ፍ', 'ራ']);
    });

    testWidgets('Check is disabled with an empty tray, enables with one tile, '
        'and disables again when it is removed', (tester) async {
      await tester.pumpWidget(_screen(_api([_fruit])));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Check'), findsOneWidget);
      expect(_canCheck(tester), isFalse);
      await _tap(tester, _bank('d1'));
      expect(_canCheck(tester), isTrue);
      await _tap(tester, _placed('d1'));
      expect(_canCheck(tester), isFalse);
    });

    testWidgets('spelled with the twins the other way round, Check grades it '
        'right on the device, calls nothing, and the lesson finishes as '
        'usual', (tester) async {
      final api = _api([_fruit, _mc]);
      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      for (final id in ['f2', 'r1', 'f1', 'r2']) {
        await _tap(tester, _bank(id));
      }
      await _tap(tester, find.text('Check'));

      // Graded locally: nothing reached the API.
      expect(api.completeLessonCalls, isEmpty);
      expect(api.refillCallCount, 0);
      final placed = tester
          .widgetList<AnswerTile>(
            find.descendant(
              of: find.byType(AnswerSlotLine),
              matching: find.byType(AnswerTile),
            ),
          )
          .toList();
      expect(placed.map((t) => t.state).toSet(), {AnswerTileState.correct});
      expect(
        tester.widget<AnswerSlotLine>(find.byType(AnswerSlotLine)).grade,
        AnswerGrade.correct,
      );
      expect(placed.every((t) => t.onTap == null), isTrue);
      expect(_tile(tester, _bank('d1')).onTap, isNull);
      expect(
        tester.widget<AnswerActionBar>(find.byType(AnswerActionBar)).grade,
        AnswerGrade.correct,
      );

      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Coffee'));
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(api.completeLessonCalls.single.correctCount, 2);
      expect(api.completeLessonCalls.single.totalCount, 2);
    });

    testWidgets('a wrong spelling takes the incorrect colours, costs a bean '
        'and comes back for review, like any other question', (tester) async {
      final api = _api([_fruit]);
      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      for (final id in ['r1', 'f1', 'f2', 'r2']) {
        await _tap(tester, _bank(id));
      }
      await _tap(tester, find.text('Check'));

      final placed = tester.widgetList<AnswerTile>(
        find.descendant(
          of: find.byType(AnswerSlotLine),
          matching: find.byType(AnswerTile),
        ),
      );
      expect(placed.map((t) => t.state).toSet(), {AnswerTileState.incorrect});
      expect(
        tester.widget<AnswerSlotLine>(find.byType(AnswerSlotLine)).grade,
        AnswerGrade.incorrect,
      );
      expect(find.text('4'), findsOneWidget); // beans: 5 -> 4
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text("Let's review your mistakes"), findsOneWidget);
      expect(api.completeLessonCalls, isEmpty);

      // The retry starts with an empty tray.
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(_canCheck(tester), isFalse);
      for (final id in _fruit.correctSequence) {
        await _tap(tester, _bank(id));
      }
      await _tap(tester, find.text('Check'));
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();
      expect(api.completeLessonCalls.single.correctCount, 1);
    });

    testWidgets('every tile, distractors included, may be placed; Check then '
        'grades it wrong, with no hint', (tester) async {
      await tester.pumpWidget(_screen(_api([_fruit])));
      await tester.pumpAndSettle();
      for (final tile in _fruit.tiles) {
        await _tap(tester, _bank(tile.id));
      }
      expect(_canCheck(tester), isTrue);
      await _tap(tester, find.text('Check'));
      expect(
        tester.widget<AnswerActionBar>(find.byType(AnswerActionBar)).grade,
        AnswerGrade.incorrect,
      );
    });
  });

  group('large text', () {
    // An eleven-character Afaan Oromo word plus a distractor, and a long
    // Fidel word, at 2.0x on a small phone.
    const oromo = SpellTilesExercise(
      id: 'spell-oromo',
      prompt: "Spell 'Good morning'",
      tiles: [
        SpellTile(id: 'a1', text: 'A'),
        SpellTile(id: 'a2', text: 'a'),
        SpellTile(id: 'a3', text: 'k'),
        SpellTile(id: 'a4', text: 'k'),
        SpellTile(id: 'a5', text: 'a'),
        SpellTile(id: 'a6', text: 'm'),
        SpellTile(id: 'a7', text: 'b'),
        SpellTile(id: 'a8', text: 'u'),
        SpellTile(id: 'a9', text: 'l'),
        SpellTile(id: 'a10', text: 'e'),
        SpellTile(id: 'a11', text: 'e'),
        SpellTile(id: 'a12', text: 'x'),
      ],
      correctSequence: [
        'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'a10', 'a11', //
      ],
    );
    const fidel = SpellTilesExercise(
      id: 'spell-fidel',
      prompt: "Spell 'Thank you'",
      tiles: [
        SpellTile(id: 'b1', text: 'ግ'),
        SpellTile(id: 'b2', text: 'አ'),
        SpellTile(id: 'b3', text: 'ለ'),
        SpellTile(id: 'b4', text: 'ሰ'),
        SpellTile(id: 'b5', text: 'እ'),
        SpellTile(id: 'b6', text: 'መ'),
        SpellTile(id: 'b7', text: 'ሁ'),
        SpellTile(id: 'b8', text: 'ክ'),
        SpellTile(id: 'b9', text: 'ና'),
        SpellTile(id: 'b10', text: 'ጪ'),
        SpellTile(id: 'b11', text: 'ቧ'),
        SpellTile(id: 'b12', text: 'ፏ'),
      ],
      correctSequence: ['b2', 'b6', 'b4', 'b1', 'b9', 'b3', 'b7'],
    );

    for (final (name, exercise) in [('Afaan Oromo', oromo), ('Fidel', fidel)]) {
      for (final width in const [320.0, 360.0]) {
        testWidgets(
          'twelve $name tiles fit a ${width.toInt()} px phone at 2.0x '
          'text, empty and with every tile placed',
          (tester) async {
            tester.view.physicalSize = Size(width, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(_screen(_api([exercise]), scale: 2));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            for (final tile in exercise.tiles) {
              await _tap(tester, _bank(tile.id));
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            // Every tile is on the line, and Check is still reachable.
            expect(
              find.descendant(
                of: find.byType(AnswerSlotLine),
                matching: find.byType(AnswerTile),
              ),
              findsNWidgets(12),
            );
            await _tap(tester, find.text('Check'));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('a pill hugs its character: a wide Fidel tile is wider than '
        'a narrow Latin one, and neither is clipped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SpellTilesBuilder(
              tiles: const [
                SpellTile(id: 'w', text: 'ጪ'),
                SpellTile(id: 'i', text: 'i'),
              ],
              placed: const [],
              feedback: TileFeedback.none,
              onToggle: (_) {},
            ),
          ),
        ),
      );
      final wide = tester.getSize(_bank('w')).width;
      final narrow = tester.getSize(_bank('i')).width;
      expect(wide, greaterThanOrEqualTo(narrow));
      expect(tester.takeException(), isNull);
    });
  });

  group('offline', () {
    testWidgets('a lesson with a spell exercise downloads, plays offline from '
        'the stored JSON with no network call, and queues its completion', (
      tester,
    ) async {
      final downloadApi = ControllableLessonApi()
        ..lessonContent = _lesson([_fruit], id: 'lesson-sp');
      final packStore = JsonRoundTripPackStore();
      final downloader = LessonPackDownloader(
        lessonApi: downloadApi,
        packStore: packStore,
      );
      await downloader.downloadLesson('lesson-sp');
      expect(
        downloader.statusFor('lesson-sp'),
        LessonDownloadStatus.downloaded,
      );
      final stored = await packStore.load('lesson-sp');
      final spell = stored!.exercises.single as SpellTilesExercise;
      expect(spell.tiles.where((t) => t.text == 'ፍ').map((t) => t.id), [
        'f2',
        'f1',
      ]);

      // No `lessonContent` here: falling through to the network would
      // null-assert.
      final offlineApi = ControllableLessonApi()
        ..completionResult = _completion;
      final connectivity = FakeConnectivityMonitor(online: false);
      final queueStore = FakePendingSyncQueueStore();
      final engine = SyncEngine(
        lessonApi: offlineApi,
        connectivityMonitor: connectivity,
        queueStore: queueStore,
      );
      await tester.pumpWidget(
        _screen(
          offlineApi,
          online: false,
          packStore: packStore,
          syncEngine: engine,
        ),
      );
      await tester.pumpAndSettle();

      // The twins came back as themselves: one is placed, the other stays
      // tappable.
      await _tap(tester, _bank('f2'));
      expect(_tile(tester, _bank('f1')).state, AnswerTileState.idle);
      for (final id in ['r1', 'f1', 'r2']) {
        await _tap(tester, _bank(id));
      }
      await _tap(tester, find.text('Check'));
      expect(
        tester.widget<AnswerActionBar>(find.byType(AnswerActionBar)).grade,
        AnswerGrade.correct,
      );
      await _tap(tester, find.text('Continue'));
      await tester.pumpAndSettle();

      expect(offlineApi.completeLessonCalls, isEmpty);
      expect(await queueStore.count(), 1);
      expect(find.text('Lesson Complete!'), findsOneWidget);

      // Back online, the queued completion syncs through the usual path.
      connectivity.setOnline(true);
      await tester.pumpAndSettle();
      expect(offlineApi.completeLessonCalls, hasLength(1));
      expect(await queueStore.count(), 0);
    });
  });
}
