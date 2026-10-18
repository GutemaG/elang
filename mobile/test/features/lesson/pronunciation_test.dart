// Romanization: a question's word or sentence, and any text tile, may carry
// its pronunciation in Latin letters (`ቡና` -> `bunna`). The API reads it, a
// downloaded pack keeps it, and the lesson shows it as a muted line under
// the Fidel. Content without any looks exactly as before.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/http_lesson_api.dart';
import 'package:elang/shared/services/lesson_pack_store.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/exercise/exercise_layout.dart';

import '../../helpers/controllable_lesson_api.dart';
import '../../helpers/fake_answer_feedback_player.dart';
import '../../helpers/fake_connectivity_monitor.dart';
import '../../helpers/fake_lesson_audio_player.dart';
import '../../helpers/fake_lesson_pack_store.dart';
import '../../helpers/fake_pending_sync_queue_store.dart';
import '../../helpers/in_memory_secure_storage_service.dart';

const _meaning = MultipleChoiceExercise(
  id: 'mc-meaning',
  prompt: "What does 'ቡና' mean?",
  promptTranslation: '',
  options: ['coffee', 'tea'],
  correctOptionIndex: 0,
  pronunciation: 'bunna',
);

const _sayIt = MultipleChoiceExercise(
  id: 'mc-say',
  prompt: "How do you say 'coffee'?",
  promptTranslation: '',
  options: ['ቡና', 'ሻይ', 'ውሃ'],
  correctOptionIndex: 0,
  optionPronunciations: ['bunna', 'shay', null],
);

const _sentence = SentenceConstructionExercise(
  id: 'sc',
  promptTranslation: "Translate: 'I want bread'",
  wordBank: ['ዳቦ', 'እፈልጋለሁ', 'ውሃ'],
  correctSentence: ['ዳቦ', 'እፈልጋለሁ'],
  wordPronunciations: {'ዳቦ': 'dabo', 'እፈልጋለሁ': 'ifeligalehu'},
);

const _gap = GapFillExercise(
  id: 'gap',
  prompt: "Complete the sentence: 'I want bread'",
  sentenceBefore: '',
  sentenceAfter: 'እፈልጋለሁ',
  options: ['ዳቦ', 'ውሃ'],
  correctOptionIndex: 0,
  optionPronunciations: ['dabo', 'wuha'],
  pronunciation: '___ ifeligalehu',
);

const _spell = SpellTilesExercise(
  id: 'spell',
  prompt: "Spell 'coffee'",
  tiles: [
    SpellTile(id: 't1', text: 'ቡ', pronunciation: 'bu'),
    SpellTile(id: 't2', text: 'ና', pronunciation: 'na'),
    SpellTile(id: 't3', text: 'ሻ'),
  ],
  correctSequence: ['t1', 't2'],
);

const _pairs = MatchPairsExercise(
  id: 'pairs',
  prompt: 'Match each word to its meaning',
  leftTiles: [
    MatchPairsTile(id: 'l1', text: 'ቡና', pronunciation: 'bunna'),
    MatchPairsTile(id: 'l2', text: 'ሻይ', pronunciation: 'shay'),
  ],
  rightTiles: [
    MatchPairsTile(id: 'r1', text: 'coffee'),
    MatchPairsTile(id: 'r2', text: 'tea'),
  ],
  correctPairs: {'l1': 'r1', 'l2': 'r2'},
);

const _plain = SentenceConstructionExercise(
  id: 'plain',
  promptTranslation: "Translate: 'I want bread'",
  wordBank: ['ዳቦ', 'እፈልጋለሁ'],
  correctSentence: ['ዳቦ', 'እፈልጋለሁ'],
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

Widget _screen(Exercise exercise) {
  final api = ControllableLessonApi()
    ..lessonContent = LessonContent(
      lessonId: 'lesson-p',
      skillId: 'skill-p',
      title: 'Coffee',
      beansAtStart: 5,
      beansMax: 5,
      exercises: [exercise],
    )
    ..completionResult = _completion;
  final connectivity = FakeConnectivityMonitor(online: true);
  return MaterialApp(
    theme: AppTheme.light,
    home: LessonScreen(
      lessonId: 'lesson-p',
      lessonApi: api,
      audioPlayer: FakeLessonAudioPlayer(),
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

/// The answer tile labelled [label].
AnswerTile _tile(WidgetTester tester, String label) => tester.widget(
  find.byWidgetPredicate((w) => w is AnswerTile && w.label == label).first,
);

Future<HttpLessonApi> _apiServing(Map<String, dynamic> exercise) async {
  final sessions = SessionRepository(storage: InMemorySecureStorageService());
  await sessions.saveSession(
    SessionState(
      token: 'token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    ),
  );
  final client = MockClient((request) async {
    final body = switch (request.url.path) {
      '/api/v1/lessons/lesson-a1' => {
        'lesson': {'id': 'lesson-a1', 'skill_id': 'skill-a', 'title': 'Coffee'},
        'exercises': [exercise],
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

Future<Exercise> _served(Map<String, dynamic> exercise) async {
  final api = await _apiServing(exercise);
  final content = await api.startLesson('lesson-a1');
  return content.exercises.single;
}

Exercise _roundTrip(Exercise exercise) =>
    packExerciseFromJson(jsonDecode(jsonEncode(packExerciseToJson(exercise))));

void main() {
  group('the API reads pronunciations', () {
    test('of the question and of each choice', () async {
      final exercise = await _served({
        'id': 'ex-1',
        'order_index': 0,
        'type': 'multiple_choice',
        'prompt': "What does 'ቡና' mean?",
        'pronunciation': 'bunna',
        'choices': [
          {'id': 'a', 'text': 'ቡና', 'pronunciation': 'bunna'},
          {'id': 'b', 'text': 'ሻይ'},
        ],
        'correct_choice_id': 'a',
      }) as MultipleChoiceExercise;

      expect(exercise.pronunciation, 'bunna');
      expect(exercise.optionPronunciations, ['bunna', null]);
    });

    test('of word-bank words, by their text', () async {
      final exercise = await _served({
        'id': 'ex-2',
        'order_index': 0,
        'type': 'sentence_construction',
        'prompt': "Translate: 'I want bread'",
        'word_bank': [
          {'id': 'w1', 'text': 'ዳቦ', 'pronunciation': 'dabo'},
          {'id': 'w2', 'text': 'እፈልጋለሁ'},
        ],
        'correct_sequence': ['w1', 'w2'],
      }) as SentenceConstructionExercise;

      expect(exercise.wordPronunciations, {'ዳቦ': 'dabo'});
    });

    test('of spell tiles and match-pair tiles', () async {
      final spell = await _served({
        'id': 'ex-3',
        'order_index': 0,
        'type': 'spell_tiles',
        'prompt': "Spell 'coffee'",
        'tiles': [
          {'id': 't1', 'text': 'ቡ', 'pronunciation': 'bu'},
          {'id': 't2', 'text': 'ና'},
        ],
        'correct_sequence': ['t1', 't2'],
      }) as SpellTilesExercise;
      final pairs = await _served({
        'id': 'ex-4',
        'order_index': 0,
        'type': 'match_pairs',
        'prompt': 'Match',
        'left_tiles': [
          {'id': 'l1', 'text': 'ቡና', 'pronunciation': 'bunna'},
          {'id': 'l2', 'text': 'ሻይ'},
        ],
        'right_tiles': [
          {'id': 'r1', 'text': 'coffee'},
          {'id': 'r2', 'text': 'tea'},
        ],
        'correct_pairs': [
          ['l1', 'r1'],
          ['l2', 'r2'],
        ],
      }) as MatchPairsExercise;

      expect(spell.tiles.map((t) => t.pronunciation), ['bu', null]);
      expect(pairs.leftTiles.map((t) => t.pronunciation), ['bunna', null]);
    });

    test('an exercise served without any has none', () async {
      final exercise = await _served({
        'id': 'ex-5',
        'order_index': 0,
        'type': 'gap_fill',
        'prompt': 'Complete the sentence',
        'sentence_before': '',
        'sentence_after': 'እፈልጋለሁ',
        'choices': [
          {'id': 'a', 'text': 'ዳቦ'},
          {'id': 'b', 'text': 'ውሃ'},
        ],
        'correct_choice_id': 'a',
      }) as GapFillExercise;

      expect(exercise.pronunciation, isNull);
      expect(exercise.optionPronunciations.every((p) => p == null), isTrue);
    });
  });

  group('a downloaded pack keeps them', () {
    test('for every kind of exercise that has them', () {
      final meaning = _roundTrip(_meaning) as MultipleChoiceExercise;
      final sayIt = _roundTrip(_sayIt) as MultipleChoiceExercise;
      final sentence = _roundTrip(_sentence) as SentenceConstructionExercise;
      final gap = _roundTrip(_gap) as GapFillExercise;
      final spell = _roundTrip(_spell) as SpellTilesExercise;
      final pairs = _roundTrip(_pairs) as MatchPairsExercise;

      expect(meaning.pronunciation, 'bunna');
      expect(sayIt.optionPronunciations, ['bunna', 'shay', null]);
      expect(sentence.wordPronunciations, _sentence.wordPronunciations);
      expect(gap.pronunciation, '___ ifeligalehu');
      expect(gap.optionPronunciations, ['dabo', 'wuha']);
      expect(spell.tiles.map((t) => t.pronunciation), ['bu', 'na', null]);
      expect(pairs.leftTiles.map((t) => t.pronunciation), ['bunna', 'shay']);
      expect(pairs.rightTiles.map((t) => t.pronunciation), [null, null]);
    });

    test('and writes nothing extra for content without any', () {
      final json = packExerciseToJson(_plain);

      expect(json.containsKey('pronunciation'), isFalse);
      expect(json.containsKey('wordPronunciations'), isFalse);
      const plainChoice = MultipleChoiceExercise(
        id: 'mc-plain',
        prompt: "How do you say 'tea'?",
        promptTranslation: '',
        options: ['ሻይ', 'ቡና'],
        correctOptionIndex: 0,
      );
      expect(
        jsonEncode(packExerciseToJson(plainChoice)),
        isNot(contains('ronunciation')),
      );
    });
  });

  group('the lesson shows them', () {
    testWidgets('under the question word', (tester) async {
      await tester.pumpWidget(_screen(_meaning));
      await tester.pumpAndSettle();

      final prompt = tester.widget<QuestionPrompt>(find.byType(QuestionPrompt));
      expect(prompt.pronunciation, 'bunna');
      expect(find.text('bunna'), findsOneWidget);
    });

    testWidgets('under each choice that has one', (tester) async {
      await tester.pumpWidget(_screen(_sayIt));
      await tester.pumpAndSettle();

      expect(_tile(tester, 'ቡና').pronunciation, 'bunna');
      expect(_tile(tester, 'ሻይ').pronunciation, 'shay');
      expect(_tile(tester, 'ውሃ').pronunciation, isNull);
      expect(find.text('bunna'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('under word-bank pills, all made tall so they line up', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(_sentence));
      await tester.pumpAndSettle();

      expect(_tile(tester, 'ዳቦ').pronunciation, 'dabo');
      expect(_tile(tester, 'ውሃ').pronunciation, isNull);
      final heights = {
        for (final label in ['ዳቦ', 'እፈልጋለሁ', 'ውሃ'])
          tester
              .getSize(
                find
                    .byWidgetPredicate(
                      (w) => w is AnswerTile && w.label == label,
                    )
                    .first,
              )
              .height,
      };
      expect(heights, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('under the gap-fill sentence and its choices', (tester) async {
      await tester.pumpWidget(_screen(_gap));
      await tester.pumpAndSettle();

      expect(find.text('___ ifeligalehu'), findsOneWidget);
      expect(_tile(tester, 'ዳቦ').pronunciation, 'dabo');
    });

    testWidgets('on spell tiles, all made tall', (tester) async {
      await tester.pumpWidget(_screen(_spell));
      await tester.pumpAndSettle();

      expect(_tile(tester, 'ቡ').pronunciation, 'bu');
      expect(_tile(tester, 'ሻ').tallPill, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on match-pair tiles', (tester) async {
      await tester.pumpWidget(_screen(_pairs));
      await tester.pumpAndSettle();

      expect(_tile(tester, 'ቡና').pronunciation, 'bunna');
      expect(_tile(tester, 'coffee').pronunciation, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and content without any is unchanged: plain pills, no line', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(_plain));
      await tester.pumpAndSettle();

      final tile = _tile(tester, 'ዳቦ');
      expect(tile.pronunciation, isNull);
      expect(tile.tallPill, isFalse);
      final context = tester.element(find.byType(AnswerTile).first);
      expect(
        tester.getSize(find.byType(AnswerTile).first).height,
        AnswerTile.pillHeightOf(context),
      );
    });
  });

  testWidgets('a tall pill is taller than a plain one, at any text size', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      AnswerTile.pillHeightOf(context, withPronunciation: true),
      greaterThan(AnswerTile.pillHeightOf(context)),
    );
  });
}
