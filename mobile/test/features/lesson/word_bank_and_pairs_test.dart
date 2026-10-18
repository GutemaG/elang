// Building a sentence and matching pairs, as a learner saw them go wrong:
// a word the sentence needs twice (`ደህና ይሁኑ፣ ደህና ይደሩ`) could only be
// placed once; `Nagaatti,` and `Nagaatti` were two tiles that looked alike
// and only one was right; and the pairs came in rows already matched.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/state/lesson_controller.dart';
import 'package:elang/features/lesson/widgets/match_pairs_builder.dart';
import 'package:elang/features/lesson/widgets/word_bank_builder.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';

const _goodNight = SentenceConstructionExercise(
  id: 'build-good-night',
  promptTranslation: 'Goodbye, good night',
  wordBank: ['ይደሩ', 'ሰላም', 'ደህና', 'ይሁኑ፣', 'ደህና'],
  correctSentence: ['ደህና', 'ይሁኑ፣', 'ደህና', 'ይደሩ'],
  wordPronunciations: {'ይደሩ': 'yideru', 'ደህና': 'dehna', 'ይሁኑ፣': 'yihunu,'},
);

/// The word bank, with its built answer kept here as the screen keeps it in
/// `LessonController`.
Future<List<String>> _pumpBank(
  WidgetTester tester,
  SentenceConstructionExercise e,
) async {
  final built = <String>[];
  final positions = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => WordBankBuilder(
            wordBank: e.wordBank,
            pronunciations: e.wordPronunciations,
            built: List.of(built),
            placedPositions: List.of(positions),
            feedback: TileFeedback.none,
            onPlace: (at, w) => setState(() {
              positions.add(at);
              built.add(w);
            }),
            onRemoveAt: (i) => setState(() {
              positions.removeAt(i);
              built.removeAt(i);
            }),
          ),
        ),
      ),
    ),
  );
  return built;
}

List<AnswerTile> _tiles(WidgetTester tester, String label) => tester
    .widgetList<AnswerTile>(
      find.byWidgetPredicate((w) => w is AnswerTile && w.label == label),
    )
    .toList();

void main() {
  group('a word bank', () {
    testWidgets('places each copy of a repeated word on its own', (
      tester,
    ) async {
      final built = await _pumpBank(tester, _goodNight);

      await tester.tap(find.text('ደህና').first);
      await tester.pump();
      // One copy is used; the other is still there to tap.
      final bank = _tiles(tester, 'ደህና').skip(1).toList();
      expect(bank.map((t) => t.state), [
        AnswerTileState.used,
        AnswerTileState.idle,
      ]);
      expect(bank.last.onTap, isNotNull);

      await tester.tap(find.text('ይሁኑ'));
      await tester.pump();
      bank.last.onTap!();
      await tester.pump();
      await tester.tap(find.text('ይደሩ'));
      await tester.pump();

      expect(built, ['ደህና', 'ይሁኑ፣', 'ደህና', 'ይደሩ']);
      expect(isAnswerCorrect(_goodNight, built), isTrue);
    });

    testWidgets('dims the copy tapped and puts back the one tapped', (
      tester,
    ) async {
      final built = await _pumpBank(tester, _goodNight);
      List<AnswerTileState> bankStates() => _tiles(
        tester,
        'ደህና',
      ).reversed.take(2).toList().reversed.map((t) => t.state).toList();

      // The second copy in the bank: that one dims, not the first.
      await tester.tap(find.text('ደህና').last);
      await tester.pump();
      expect(bankStates(), [AnswerTileState.idle, AnswerTileState.used]);

      await tester.tap(find.text('ሰላም'));
      await tester.pump();
      await tester.tap(find.text('ደህና').at(1));
      await tester.pump();
      expect(built, ['ደህና', 'ሰላም', 'ደህና']);

      // The built line comes first: its first ደህና came from the second
      // copy, so taking it out lights that copy again.
      await tester.tap(find.text('ደህና').first);
      await tester.pump();
      expect(built, ['ሰላም', 'ደህና']);
      expect(bankStates(), [AnswerTileState.used, AnswerTileState.idle]);
    });

    testWidgets('shows words and pronunciations without their punctuation', (
      tester,
    ) async {
      await _pumpBank(tester, _goodNight);

      expect(find.text('ይሁኑ'), findsOneWidget);
      expect(find.text('ይሁኑ፣'), findsNothing);
      expect(find.text('yihunu'), findsOneWidget);
    });
  });

  group('grading a built sentence', () {
    const oromo = SentenceConstructionExercise(
      id: 'build-nagaatti',
      promptTranslation: 'Goodbye, good night',
      wordBank: ['Nagaatti,', 'Akkam', 'gaarii', 'halkan', 'Nagaatti'],
      correctSentence: ['Nagaatti,', 'halkan', 'gaarii'],
    );

    test('takes either of two words that look the same', () {
      expect(isAnswerCorrect(oromo, ['Nagaatti,', 'halkan', 'gaarii']), isTrue);
      expect(isAnswerCorrect(oromo, ['Nagaatti', 'halkan', 'gaarii']), isTrue);
    });

    test('still wants the right words in the right order', () {
      expect(isAnswerCorrect(oromo, ['halkan', 'Nagaatti', 'gaarii']), isFalse);
      expect(isAnswerCorrect(oromo, ['Akkam', 'halkan', 'gaarii']), isFalse);
    });

    test('bare words keep an Oromo apostrophe and a word of punctuation', () {
      expect(bareWord('“Nagaatti,”'), 'Nagaatti');
      expect(bareWord('ደህና።'), 'ደህና');
      expect(bareWord("ba'ii?"), "ba'ii");
      expect(bareWord('?'), '?');
    });
  });

  group('match the pairs', () {
    const words = [
      ('Akkam', 'hello'),
      ('Nagaatti', 'goodbye'),
      ('Akkam bulte', 'good morning'),
      ('Halkan gaarii', 'good night'),
    ];

    Future<void> pump(WidgetTester tester, String seed) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MatchPairsBuilder(
            shuffleSeed: seed,
            leftTiles: [
              for (var i = 0; i < words.length; i++)
                MatchPairsTile(id: 'l$i', text: words[i].$1),
            ],
            rightTiles: [
              for (var i = 0; i < words.length; i++)
                MatchPairsTile(id: 'r$i', text: words[i].$2),
            ],
            correctPairs: {for (var i = 0; i < words.length; i++) 'l$i': 'r$i'},
            matchedPairs: const {},
            armedTileId: null,
            armedIsLeft: true,
            wrongPair: null,
            onTileTap: (_, {required isLeft}) {},
          ),
        ),
      ),
    );

    testWidgets('never puts a word beside its own meaning', (tester) async {
      for (final seed in ['pairs-1', 'pairs-2', 'pairs-3', 'ex-42']) {
        await pump(tester, seed);
        final labels = tester
            .widgetList<AnswerTile>(find.byType(AnswerTile))
            .map((t) => t.label)
            .toList();
        for (var row = 0; row < words.length; row++) {
          final left = labels[row * 2];
          final right = labels[row * 2 + 1];
          expect(words.contains((left, right)), isFalse, reason: seed);
        }
      }
    });

    testWidgets('keeps the same order for the same exercise', (tester) async {
      List<String> labels() => tester
          .widgetList<AnswerTile>(find.byType(AnswerTile))
          .map((t) => t.label)
          .toList();
      await pump(tester, 'pairs-1');
      final first = labels();
      await pump(tester, 'pairs-1');
      expect(labels(), first);
    });
  });
}
