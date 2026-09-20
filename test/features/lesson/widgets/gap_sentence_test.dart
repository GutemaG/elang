// The sentence-with-a-gap renders correctly at every text scale, in Fidel
// and in Latin (015-gap-fill-exercise-type, bolt 031).
//
// The gap is a `WidgetSpan` inside a `Text.rich`, which is the part most
// likely to look wrong on a device while a test passes: the test font's
// metrics are not a phone's. So these tests check what the test font can
// actually prove — that nothing overflows, that the gap does not resize
// under the learner, and that a screen reader can tell there is a gap —
// and leave the look of the baseline to the device pass.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/widgets/gap_sentence.dart';

const _options = ['ቡና', 'ሻይ', 'ውሃ'];

Future<void> _pump(
  WidgetTester tester, {
  String before = 'እኔ',
  String after = 'እፈልጋለሁ',
  List<String> options = _options,
  String? filled,
  double scale = 1.0,
  double width = 360,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(scale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: GapSentence(
              before: before,
              after: after,
              options: options,
              filled: filled,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('rendering', () {
    testWidgets('shows the words either side of the gap', (tester) async {
      await _pump(tester);

      expect(find.textContaining('እኔ'), findsWidgets);
      expect(find.textContaining('እፈልጋለሁ'), findsWidgets);
    });

    testWidgets('an empty gap shows no word', (tester) async {
      await _pump(tester, filled: null);

      expect(find.text('ቡና'), findsNothing);
    });

    testWidgets('a filled gap shows the chosen word', (tester) async {
      await _pump(tester, filled: 'ቡና');

      expect(find.text('ቡና'), findsOneWidget);
    });

    testWidgets('a gap at the start of the sentence renders', (tester) async {
      await _pump(tester, before: '', filled: 'ቡና');

      expect(tester.takeException(), isNull);
      expect(find.text('ቡና'), findsOneWidget);
    });

    testWidgets('a gap at the end of the sentence renders', (tester) async {
      await _pump(tester, after: '', filled: 'ቡና');

      expect(tester.takeException(), isNull);
      expect(find.text('ቡና'), findsOneWidget);
    });
  });

  group('the gap does not resize under the learner', () {
    testWidgets('filling the gap does not change its width', (tester) async {
      await _pump(tester, filled: null);
      final empty = tester.getSize(
        find.descendant(
          of: find.byType(GapSentence),
          matching: find.byType(Container),
        ),
      );

      await _pump(tester, filled: 'ቡና');
      final full = tester.getSize(
        find.descendant(
          of: find.byType(GapSentence),
          matching: find.byType(Container),
        ),
      );

      expect(full.width, empty.width);
    });

    testWidgets('choosing a longer word does not change its width', (
      tester,
    ) async {
      await _pump(tester, filled: 'ቡና');
      final short = tester.getSize(
        find.descendant(
          of: find.byType(GapSentence),
          matching: find.byType(Container),
        ),
      );

      await _pump(tester, filled: 'ውሃ');
      final other = tester.getSize(
        find.descendant(
          of: find.byType(GapSentence),
          matching: find.byType(Container),
        ),
      );

      // Sized to the widest option, so any choice fits without reflow.
      expect(other.width, short.width);
    });
  });

  group('does not overflow', () {
    for (final scale in [1.0, 1.15, 1.3, 1.5, 2.0]) {
      for (final width in [320.0, 360.0, 412.0]) {
        testWidgets('Fidel at ${scale}x on ${width}dp', (tester) async {
          await _pump(tester, scale: scale, width: width, filled: 'ቡና');

          expect(tester.takeException(), isNull);
        });

        testWidgets('Latin at ${scale}x on ${width}dp', (tester) async {
          await _pump(
            tester,
            before: 'Daabboo',
            after: 'barbaada guddaa',
            options: const ['nan', 'Nyaata', 'Hanqaaquu'],
            filled: 'Hanqaaquu',
            scale: scale,
            width: width,
          );

          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a very long sentence wraps rather than overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        before: 'ቡና እና ሻይ እና ውሃ እና ወተት እና ዳቦ እና ምግብ',
        after: 'በጣም እፈልጋለሁ ዛሬ ጠዋት እዚህ ቤት ውስጥ',
        filled: 'ቡና',
        width: 320,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('an empty gap is announced as a blank', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, filled: null);

      expect(find.bySemanticsLabel('blank'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a filled gap announces the word in it', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, filled: 'ቡና');

      expect(find.bySemanticsLabel('blank, filled with ቡና'), findsOneWidget);
      handle.dispose();
    });
  });
}
