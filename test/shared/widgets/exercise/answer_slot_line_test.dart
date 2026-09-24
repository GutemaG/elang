// AnswerSlotLine: the ruled lines a built sentence sits on, and the gap in
// a gap-fill sentence (018-mobile-design-system, unit 002 story 003).

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_typography.dart';
import 'package:elang/shared/widgets/exercise/answer_action_bar.dart';
import 'package:elang/shared/widgets/exercise/answer_slot_line.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 320, double scale = 1}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );

List<Widget> _pills(List<String> words) => [
  for (final w in words)
    AnswerTile(label: w, shape: AnswerTileShape.pill, onTap: () {}),
];

/// The rules the sentence form paints, as (y, colour).
List<(double, Color)> _rules(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(AnswerSlotLine),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  final size = tester.getSize(
    find
        .descendant(
          of: find.byType(AnswerSlotLine),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  final recorder = _RecordingCanvas();
  paint.painter!.paint(recorder, size);
  return recorder.lines;
}

class _RecordingCanvas implements Canvas {
  final lines = <(double, Color)>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    expect(p1.dy, p2.dy);
    // Paint keeps its colour as floats; compare as 32-bit ARGB.
    lines.add((p1.dy, Color(paint.color.toARGB32())));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A gap sentence whose chosen word can change, to watch the gap's width.
class _Gap extends StatefulWidget {
  const _Gap();

  @override
  State<_Gap> createState() => _GapState();
}

class _GapState extends State<_Gap> {
  String? filled;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnswerSlotLine.gap(
        before: 'እኔ',
        after: 'እፈልጋለሁ',
        options: const ['ቡና', 'ሻይ', 'ውሃ ቀዝቃዛ'],
        filled: filled,
      ),
      for (final w in ['ቡና', 'ውሃ ቀዝቃዛ'])
        TextButton(
          onPressed: () => setState(() => filled = w),
          child: Text('pick $w'),
        ),
    ],
  );
}

Rect _gapRect(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(AnswerSlotLine),
    matching: find.byType(Container),
  ),
);

void main() {
  group('sentence', () {
    testWidgets('holds two lines when empty, with the hint on the first', (
      tester,
    ) async {
      late double pill;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              pill = AnswerTile.pillHeightOf(context);
              return const AnswerSlotLine.sentence(children: []);
            },
          ),
        ),
      );
      final pitch = pill + AnswerSlotLine.runGap;
      expect(tester.getSize(find.byType(AnswerSlotLine)).height, pitch * 2);
      expect(find.text('Tap words below to build your answer'), findsOneWidget);

      final rules = _rules(tester);
      expect(rules.map((r) => r.$1), [
        pill + AnswerSlotLine.runGap / 2,
        pill + AnswerSlotLine.runGap / 2 + pitch,
      ]);
      // The hint sits above the first rule, not across it.
      final hint = tester.getRect(
        find.text('Tap words below to build your answer'),
      );
      final top = tester.getTopLeft(find.byType(AnswerSlotLine)).dy;
      expect(hint.bottom, lessThanOrEqualTo(top + rules.first.$1));
      expect(
        tester
            .widget<Text>(find.text('Tap words below to build your answer'))
            .style!
            .color,
        AppColors.textMuted,
      );
    });

    testWidgets('pills sit on the rules: each rule runs just under a row of '
        'pills', (tester) async {
      await tester.pumpWidget(
        _host(AnswerSlotLine.sentence(children: _pills(['እኔ', 'ቡና']))),
      );
      final top = tester.getTopLeft(find.byType(AnswerSlotLine)).dy;
      final pillBottom = tester.getRect(find.byType(AnswerTile).first).bottom;
      final firstRule = top + _rules(tester).first.$1;
      expect(firstRule - pillBottom, AnswerSlotLine.runGap / 2);
      expect(find.text('Tap words below to build your answer'), findsNothing);
    });

    testWidgets('adding words on one line does not change its height; '
        'wrapping adds exactly one line', (tester) async {
      late double pitch;
      Widget line(List<String> words) => _host(
        Builder(
          builder: (context) {
            pitch = AnswerTile.pillHeightOf(context) + AnswerSlotLine.runGap;
            return AnswerSlotLine.sentence(children: _pills(words));
          },
        ),
      );
      await tester.pumpWidget(line([]));
      final empty = tester.getSize(find.byType(AnswerSlotLine)).height;
      await tester.pumpWidget(line(['እኔ', 'ቡና', 'እፈልጋለሁ']));
      expect(tester.getSize(find.byType(AnswerSlotLine)).height, empty);

      await tester.pumpWidget(
        line([for (var i = 0; i < 5; i++) i.isEven ? 'እፈልጋለሁ' : 'Galatoomaa']),
      );
      final tall = tester.getSize(find.byType(AnswerSlotLine)).height;
      expect(tall, greaterThan(empty));
      expect((tall / pitch) % 1, closeTo(0, 0.001));
      expect(_rules(tester).length, (tall / pitch).round());
    });

    testWidgets('the rules are warm grey until graded, then green or '
        'terracotta', (tester) async {
      for (final (grade, colour) in [
        (null, AppColors.tileShelf),
        (AnswerGrade.correct, AppColors.primaryContainer),
        (AnswerGrade.incorrect, AppColors.tertiaryBrand),
      ]) {
        await tester.pumpWidget(
          _host(AnswerSlotLine.sentence(grade: grade, children: _pills(['a']))),
        );
        expect(
          _rules(tester).every((r) => r.$2 == colour),
          isTrue,
          reason: '$grade',
        );
      }
    });

    testWidgets('a placed word can be tapped back out', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _host(
          AnswerSlotLine.sentence(
            children: [
              for (final w in ['እኔ', 'ቡና'])
                AnswerTile(
                  label: w,
                  shape: AnswerTileShape.pill,
                  onTap: () => taps.add(w),
                ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('ቡና'));
      expect(taps, ['ቡና']);
    });

    testWidgets('fits a 320 px phone at 1.3x text with Fidel', (tester) async {
      await tester.pumpWidget(
        _host(
          scale: 1.3,
          AnswerSlotLine.sentence(
            children: _pills(['እኔ', 'ቡና', 'እፈልጋለሁ', 'ሻይ', 'ውሃ']),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        _host(scale: 1.3, const AnswerSlotLine.sentence(children: [])),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('gap (GapSentence\'s behaviour)', () {
    testWidgets('shows the words either side and the chosen word', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AnswerSlotLine.gap(
            before: 'እኔ',
            after: 'እፈልጋለሁ',
            options: ['ቡና', 'ሻይ'],
            filled: 'ቡና',
          ),
        ),
      );
      expect(find.textContaining('እኔ'), findsOneWidget);
      expect(find.textContaining('እፈልጋለሁ'), findsOneWidget);
      expect(find.text('ቡና'), findsOneWidget);
    });

    testWidgets('an empty gap shows no word', (tester) async {
      await tester.pumpWidget(
        _host(
          const AnswerSlotLine.gap(
            before: 'እኔ',
            after: 'እፈልጋለሁ',
            options: ['ቡና', 'ሻይ'],
          ),
        ),
      );
      expect(find.text('ቡና'), findsNothing);
    });

    testWidgets('the gap can sit at either end', (tester) async {
      for (final (before, after) in [('', 'እፈልጋለሁ'), ('እኔ', '')]) {
        await tester.pumpWidget(
          _host(
            AnswerSlotLine.gap(
              before: before,
              after: after,
              options: const ['ቡና'],
              filled: 'ቡና',
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('ቡና'), findsOneWidget);
      }
    });

    testWidgets('filling the gap, or changing to a longer word, never '
        'changes its width', (tester) async {
      await tester.pumpWidget(_host(const _Gap()));
      final empty = _gapRect(tester);
      await tester.tap(find.text('pick ቡና'));
      await tester.pump();
      expect(_gapRect(tester).width, empty.width);
      await tester.tap(find.text('pick ውሃ ቀዝቃዛ'));
      await tester.pump();
      expect(_gapRect(tester).width, empty.width);
      expect(_gapRect(tester).left, empty.left);
      expect(_gapRect(tester).top, closeTo(empty.top, 0.5));
    });

    testWidgets('the line is warm grey until graded, then green or '
        'terracotta, and the word takes the grade', (tester) async {
      for (final (grade, colour, word) in [
        (null, AppColors.tileShelf, AppColors.onSurface),
        (
          AnswerGrade.correct,
          AppColors.primaryContainer,
          AppColors.primaryContainer,
        ),
        (
          AnswerGrade.incorrect,
          AppColors.tertiaryBrand,
          AppColors.tertiaryBrand,
        ),
      ]) {
        await tester.pumpWidget(
          _host(
            AnswerSlotLine.gap(
              before: 'Ani',
              after: 'barbada',
              options: const ['buna', 'shaayii'],
              filled: 'buna',
              grade: grade,
            ),
          ),
        );
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(AnswerSlotLine),
            matching: find.byType(Container),
          ),
        );
        final border = (container.decoration! as BoxDecoration).border!;
        expect(border.bottom.color, colour, reason: '$grade');
        expect(border.bottom.width, AnswerSlotLine.lineWidth);
        expect(
          tester.widget<Text>(find.text('buna')).style!.color,
          word,
          reason: '$grade',
        );
      }
    });

    testWidgets('a Fidel sentence gets the Ethiopic line height', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AnswerSlotLine.gap(
            before: 'እኔ',
            after: 'እፈልጋለሁ',
            options: ['ቡና'],
            filled: 'ቡና',
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('ቡና')).style!.height,
        closeTo(
          AppTypography.displayLgMobile.height! *
              AppTypography.ethiopicLineHeightFactor,
          0.0001,
        ),
      );
    });

    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('does not overflow at ${width}px and ${scale}x, and a '
            'long sentence wraps', (tester) async {
          await tester.pumpWidget(
            _host(
              width: width,
              scale: scale,
              const AnswerSlotLine.gap(
                before: 'ዛሬ ጠዋት ከጓደኛዬ ጋር በካፌ ውስጥ',
                after: 'እና ዳቦ በላሁ ከዚያም ወደ ቤት ሄድኩ',
                options: ['ቡና ጠጣሁ', 'ሻይ'],
                filled: 'ቡና ጠጣሁ',
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final outer = tester.renderObject<RenderParagraph>(
            find
                .descendant(
                  of: find.byType(AnswerSlotLine),
                  matching: find.byType(RichText),
                )
                .first,
          );
          expect(outer.didExceedMaxLines, isFalse);
        });
      }
    }

    testWidgets('an empty gap reads as "blank"; a filled one names its '
        'word', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const AnswerSlotLine.gap(
            before: 'እኔ',
            after: 'እፈልጋለሁ',
            options: ['ቡና'],
          ),
        ),
      );
      expect(find.bySemanticsLabel('blank'), findsOneWidget);
      await tester.pumpWidget(
        _host(
          const AnswerSlotLine.gap(
            before: 'እኔ',
            after: 'እፈልጋለሁ',
            options: ['ቡና'],
            filled: 'ቡና',
          ),
        ),
      );
      expect(find.bySemanticsLabel('blank, filled with ቡና'), findsOneWidget);
      handle.dispose();
    });
  });
}
