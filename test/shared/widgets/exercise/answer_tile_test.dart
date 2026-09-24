// AnswerTile: every state and shape of the one answer tile
// (018-mobile-design-system, unit 002 story 002).

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_typography.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/tactile_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  double width = 320,
  double scale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [child],
            ),
          ),
        ),
      ),
    ),
  ),
);

BoxDecoration _face(WidgetTester tester, [Finder? of]) {
  final pressable = find.descendant(
    of: of ?? find.byType(AnswerTile),
    matching: find.byType(TactilePressable),
  );
  final container = tester.widget<Container>(
    find.descendant(of: pressable, matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

Color _borderColour(BoxDecoration d) => (d.border! as Border).top.color;

Color _textColour(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

double _shakeOffset(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find
        .descendant(
          of: find.byType(AnswerTile),
          matching: find.byType(Transform),
        )
        .first,
  );
  return transform.transform.getTranslation().x;
}

/// A tile that turns incorrect when tapped, as a graded lesson tile does.
class _GradesOnTap extends StatefulWidget {
  const _GradesOnTap({this.shape = AnswerTileShape.row});

  final AnswerTileShape shape;

  @override
  State<_GradesOnTap> createState() => _GradesOnTapState();
}

class _GradesOnTapState extends State<_GradesOnTap> {
  AnswerTileState _state = AnswerTileState.idle;

  @override
  Widget build(BuildContext context) => AnswerTile(
    label: 'ሻይ',
    shape: widget.shape,
    state: _state,
    onTap: _state == AnswerTileState.idle
        ? () => setState(() => _state = AnswerTileState.incorrect)
        : null,
  );
}

void main() {
  group('states (DESIGN.md component 4)', () {
    final expected = <AnswerTileState, (Color, Color, Color, Color)>{
      AnswerTileState.idle: (
        AppColors.surfaceContainerLowest,
        AppColors.tileBorder,
        AppColors.tileShelf,
        AppColors.onSurface,
      ),
      AnswerTileState.selected: (
        AppColors.answerSelected,
        AppColors.secondaryBrand,
        AppColors.activeNodeShelf,
        AppColors.onSurface,
      ),
      AnswerTileState.correct: (
        AppColors.answerCorrect,
        AppColors.primaryContainer,
        AppColors.primaryBevel,
        AppColors.primaryContainer,
      ),
      AnswerTileState.incorrect: (
        AppColors.answerIncorrect,
        AppColors.tertiaryBrand,
        AppColors.tertiaryBevel,
        AppColors.tertiaryBrand,
      ),
    };

    for (final MapEntry(key: state, value: look) in expected.entries) {
      testWidgets('${state.name}: face, border, rim and text', (tester) async {
        await tester.pumpWidget(
          _host(AnswerTile(label: 'Coffee', state: state, onTap: () {})),
        );
        await tester.pumpAndSettle();

        final (face, border, rim, text) = look;
        final d = _face(tester);
        expect(d.color, face);
        expect(_borderColour(d), border);
        expect((d.border! as Border).top.width, AnswerTile.borderWidth);
        expect(d.boxShadow, AppShadows.tileRaised(rim));
        expect(d.boxShadow!.first.offset.dy, AppShadows.tileShelfDepth);
        expect(_textColour(tester, 'Coffee'), text);
      });
    }

    testWidgets('idle is exactly the design system tile at rest', (
      tester,
    ) async {
      await tester.pumpWidget(_host(AnswerTile(label: 'a', onTap: () {})));
      expect(_face(tester).boxShadow, AppShadows.tile);
    });

    testWidgets('used dims the whole tile, as a placed word-bank word', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AnswerTile(
            label: 'ቡና',
            state: AnswerTileState.used,
            shape: AnswerTileShape.pill,
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AnswerTile),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.35);
      expect(_face(tester).color, AppColors.surfaceContainerLowest);
    });

    testWidgets('disabled fades the text and ignores taps even with onTap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AnswerTile(
            label: 'Tea',
            state: AnswerTileState.disabled,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(AnswerTile));
      expect(taps, 0);
      expect(
        _textColour(tester, 'Tea'),
        AppColors.onSurface.withValues(alpha: 0.6),
      );
    });

    testWidgets('a correct tile shows a check, an incorrect one a cross', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              AnswerTile(label: 'right', state: AnswerTileState.correct),
              AnswerTile(label: 'wrong', state: AnswerTileState.incorrect),
              AnswerTile(label: 'chosen', state: AnswerTileState.selected),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      final check = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(check.color, AppColors.primaryContainer);
      final cross = tester.widget<Icon>(find.byIcon(Icons.cancel));
      expect(cross.color, AppColors.tertiaryBrand);
    });

    testWidgets('colours ease between states over AppMotion.state', (
      tester,
    ) async {
      Widget tile(AnswerTileState s) =>
          _host(AnswerTile(label: 'a', state: s, onTap: () {}));
      await tester.pumpWidget(tile(AnswerTileState.idle));
      await tester.pumpWidget(tile(AnswerTileState.selected));
      await tester.pump(AppMotion.state ~/ 2);
      final mid = _face(tester).color!;
      expect(mid, isNot(AppColors.surfaceContainerLowest));
      expect(mid, isNot(AppColors.answerSelected));
      await tester.pump(AppMotion.state);
      expect(_face(tester).color, AppColors.answerSelected);
    });
  });

  group('shapes', () {
    testWidgets('row fills the width, label at the start, 56 px face', (
      tester,
    ) async {
      await tester.pumpWidget(_host(AnswerTile(label: 'Hi', onTap: () {})));
      final tile = tester.getRect(find.byType(AnswerTile));
      expect(tile.width, 320);
      expect(
        tester.getSize(find.byType(AnswerTile)).height,
        AnswerTile.minFaceHeight + AppShadows.tileShelfDepth,
      );
      expect(
        tester.getTopLeft(find.text('Hi')).dx - tile.left,
        AnswerTile.borderWidth + AppSpacing.spaceMd,
      );
      expect(_face(tester).borderRadius, BorderRadius.circular(AppRadii.tile));
    });

    testWidgets('row and cell fill the width even in a loose parent', (
      tester,
    ) async {
      for (final shape in [AnswerTileShape.row, AnswerTileShape.cell]) {
        await tester.pumpWidget(
          _host(
            Align(
              alignment: Alignment.centerLeft,
              child: AnswerTile(label: 'Hi', shape: shape, onTap: () {}),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(AnswerTile)).width,
          320,
          reason: shape.name,
        );
      }
    });

    testWidgets('cell fills its column with the label centred', (tester) async {
      await tester.pumpWidget(
        _host(
          AnswerTile(label: 'Tea', shape: AnswerTileShape.cell, onTap: () {}),
        ),
      );
      final tile = tester.getRect(find.byType(AnswerTile));
      expect(tile.width, 320);
      expect(tester.getCenter(find.text('Tea')).dx, closeTo(tile.center.dx, 1));
    });

    testWidgets('pill hugs its label, is fully rounded, and never shrinks '
        'below the 48 px tap target', (tester) async {
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.centerLeft,
            child: AnswerTile(
              label: 'ቡና',
              shape: AnswerTileShape.pill,
              onTap: () {},
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(AnswerTile));
      expect(size.width, lessThan(120));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(_face(tester).borderRadius, BorderRadius.circular(AppRadii.full));
    });

    testWidgets('every pill is the same height, Latin or Fidel, matching '
        'pillHeightOf at 1.0x, 1.3x and 2.0x', (tester) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        late double expected;
        await tester.pumpWidget(
          _host(
            scale: scale,
            Builder(
              builder: (context) {
                expected = AnswerTile.pillHeightOf(context);
                return Wrap(
                  children: [
                    AnswerTile(
                      key: const Key('latin'),
                      label: 'Buna',
                      shape: AnswerTileShape.pill,
                      onTap: () {},
                    ),
                    AnswerTile(
                      key: const Key('fidel'),
                      label: 'እፈልጋለሁ',
                      shape: AnswerTileShape.pill,
                      onTap: () {},
                    ),
                  ],
                );
              },
            ),
          ),
        );
        expect(
          tester.getSize(find.byKey(const Key('latin'))).height,
          expected,
          reason: '$scale',
        );
        expect(
          tester.getSize(find.byKey(const Key('fidel'))).height,
          expected,
          reason: '$scale',
        );
      }
    });

    testWidgets('with small text a pill still keeps the 48 px tap target', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          scale: 0.7,
          Align(
            alignment: Alignment.centerLeft,
            child: AnswerTile(
              label: 'ቡና',
              shape: AnswerTileShape.pill,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AnswerTile)).height, 48);
    });

    testWidgets('a graded pill shows its grade by colour alone, so a checked '
        'sentence keeps its width', (tester) async {
      Widget pill(AnswerTileState s) => _host(
        Align(
          alignment: Alignment.centerLeft,
          child: AnswerTile(label: 'ቡና', shape: AnswerTileShape.pill, state: s),
        ),
      );
      await tester.pumpWidget(pill(AnswerTileState.idle));
      final before = tester.getSize(find.byType(AnswerTile)).width;
      await tester.pumpWidget(pill(AnswerTileState.incorrect));
      await tester.pumpAndSettle();
      expect(find.byType(Icon), findsNothing);
      expect(tester.getSize(find.byType(AnswerTile)).width, before);
      expect(_face(tester).color, AppColors.answerIncorrect);
    });

    testWidgets('a word too long for its row shrinks into its pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          width: 120,
          Wrap(
            children: [
              AnswerTile(
                label: 'Galatoomaa baayyee',
                shape: AnswerTileShape.pill,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AnswerTile)).width,
        lessThanOrEqualTo(120),
      );
    });
  });

  group('interaction', () {
    testWidgets('a tap calls onTap once and presses like every tactile '
        'element', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AnswerTile(label: 'a', onTap: () => taps++)),
      );
      expect(find.byType(TactilePressable), findsOneWidget);
      final rest = tester.getRect(find.text('a'));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AnswerTile)),
      );
      await tester.pump();
      await tester.pump(AppMotion.pressIn);
      // Sunk onto its shelf: only the soft shadow is left.
      expect(_face(tester).boxShadow, hasLength(1));
      expect(
        tester.getRect(find.text('a')).top,
        greaterThan(rest.top + AppShadows.tileShelfDepth / 2),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    for (final state in [
      AnswerTileState.idle,
      AnswerTileState.selected,
      AnswerTileState.correct,
    ]) {
      testWidgets('${state.name} with onTap null: taps do nothing and it '
          'does not press', (tester) async {
        await tester.pumpWidget(_host(AnswerTile(label: 'a', state: state)));
        final pressable = tester.widget<TactilePressable>(
          find.byType(TactilePressable),
        );
        expect(pressable.onPressed, isNull);
        await tester.tap(find.byType(AnswerTile), warnIfMissed: false);
        await tester.pumpAndSettle();
      });
    }

    testWidgets('an idle choice that cannot be tapped fades its text, as '
        'ChoiceTile did', (tester) async {
      await tester.pumpWidget(_host(const AnswerTile(label: 'Water')));
      expect(
        _textColour(tester, 'Water'),
        AppColors.onSurface.withValues(alpha: 0.6),
      );
    });

    testWidgets('a graded tile keeps its full colour though it cannot be '
        'tapped', (tester) async {
      await tester.pumpWidget(
        _host(const AnswerTile(label: 'Tea', state: AnswerTileState.correct)),
      );
      await tester.pumpAndSettle();
      expect(_textColour(tester, 'Tea'), AppColors.primaryContainer);
    });

    testWidgets('a tapped tile at rest has not moved', (tester) async {
      await tester.pumpWidget(_host(AnswerTile(label: 'a', onTap: () {})));
      final before = tester.getRect(find.text('a'));
      await tester.tap(find.byType(AnswerTile));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('a')), before);
    });
  });

  group('shake', () {
    testWidgets('turning incorrect shakes once within AppMotion.shake, '
        'without moving the layout', (tester) async {
      await tester.pumpWidget(_host(const _GradesOnTap()));
      final layout = tester.getRect(find.byType(AnswerTile));
      await tester.tap(find.byType(AnswerTile));
      await tester.pump();

      var moved = 0.0;
      for (var t = 0; t < 8; t++) {
        await tester.pump(AppMotion.shake ~/ 10);
        moved = moved > _shakeOffset(tester).abs()
            ? moved
            : _shakeOffset(tester).abs();
        expect(tester.getRect(find.byType(AnswerTile)), layout);
      }
      expect(moved, greaterThan(2));
      // A soft shake: at most 8 px either side.
      expect(moved, lessThanOrEqualTo(8));

      await tester.pump(AppMotion.shake);
      expect(_shakeOffset(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('match-pair cells shake the same way', (tester) async {
      await tester.pumpWidget(
        _host(const _GradesOnTap(shape: AnswerTileShape.cell)),
      );
      await tester.tap(find.byType(AnswerTile));
      await tester.pump();
      await tester.pump(AppMotion.shake ~/ 12);
      expect(_shakeOffset(tester).abs(), greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('no shake with reduced motion; the colour still changes', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const _GradesOnTap(), reduceMotion: true));
      await tester.tap(find.byType(AnswerTile));
      for (var t = 0; t < 6; t++) {
        await tester.pump(AppMotion.shake ~/ 10);
        expect(_shakeOffset(tester), 0);
      }
      await tester.pumpAndSettle();
      expect(_face(tester).color, AppColors.answerIncorrect);
    });

    testWidgets('a tile first built wrong shakes once too', (tester) async {
      await tester.pumpWidget(
        _host(const AnswerTile(label: 'x', state: AnswerTileState.incorrect)),
      );
      await tester.pump();
      await tester.pump(AppMotion.shake ~/ 12);
      expect(_shakeOffset(tester).abs(), greaterThan(0));
      await tester.pumpAndSettle();
      expect(_shakeOffset(tester), 0);
    });

    testWidgets('selected and correct never shake', (tester) async {
      Widget tile(AnswerTileState s) =>
          _host(AnswerTile(label: 'x', state: s, onTap: () {}));
      await tester.pumpWidget(tile(AnswerTileState.idle));
      for (final s in [AnswerTileState.selected, AnswerTileState.correct]) {
        await tester.pumpWidget(tile(s));
        await tester.pump(AppMotion.shake ~/ 12);
        expect(_shakeOffset(tester), 0, reason: s.name);
      }
    });
  });

  group('screen readers', () {
    testWidgets('one button node with the label; selected, correct and '
        'incorrect are selected', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (state, selected) in [
        (AnswerTileState.idle, false),
        (AnswerTileState.selected, true),
        (AnswerTileState.correct, true),
        (AnswerTileState.incorrect, true),
      ]) {
        await tester.pumpWidget(
          _host(AnswerTile(label: 'ቡና', state: state, onTap: () {})),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byType(AnswerTile)),
          isSemantics(
            label: 'ቡና',
            isButton: true,
            hasSelectedState: true,
            isSelected: selected,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
          reason: state.name,
        );
      }
      handle.dispose();
    });

    testWidgets('a screen-reader tap calls onTap', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(AnswerTile(label: 'a', onTap: () => taps++)),
      );
      tester.semantics.tap(find.semantics.byLabel('a'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('the check and cross are not read out', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const AnswerTile(label: 'Tea', state: AnswerTileState.correct)),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Tea'), findsOneWidget);
      final node = tester.getSemantics(find.byType(AnswerTile));
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      handle.dispose();
    });
  });

  group('text scale', () {
    for (final shape in AnswerTileShape.values) {
      testWidgets('${shape.name}: a Fidel label at 1.3x grows and never '
          'overflows at 320 px', (tester) async {
        const long = 'እንደምን አደርክ? ዛሬ ጠዋት ቡና ጠጥተሃል ወይስ ሻይ?';
        await tester.pumpWidget(
          _host(
            scale: 1.3,
            shape == AnswerTileShape.pill
                ? Wrap(
                    children: [
                      AnswerTile(label: long, shape: shape, onTap: () {}),
                    ],
                  )
                : AnswerTile(label: long, shape: shape, onTap: () {}),
          ),
        );
        expect(tester.takeException(), isNull);
        final text = tester.renderObject<RenderParagraph>(find.text(long));
        expect(text.didExceedMaxLines, isFalse);
        if (shape != AnswerTileShape.pill) {
          expect(
            tester.getSize(find.byType(AnswerTile)).height,
            greaterThan(AnswerTile.minFaceHeight + AppShadows.tileShelfDepth),
          );
        }
        expect(
          tester.widget<Text>(find.text(long)).style!.height,
          closeTo(
            AppTypography.bodyLg.height! *
                AppTypography.ethiopicLineHeightFactor,
            0.001,
          ),
        );
      });
    }
  });
}
