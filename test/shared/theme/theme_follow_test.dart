// Widgets draw from the current theme's palette, including the places with
// no BuildContext of their own (022-light-and-dark-themes, bolt 067): the
// path node's ring painter and colour helpers, a button's style table, an
// answer tile's look, and the page background's painter.

import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_page.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/path_node.dart';
import 'package:elang/shared/widgets/tactile_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/distinct_palette.dart';

final _palette = distinctPalette();

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.fromPalette(_palette, brightness: Brightness.dark),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets("a path node's ring and circle use the theme's palette", (
    tester,
  ) async {
    await _pump(
      tester,
      const PathNode(
        state: PathNodeState.completed,
        label: 'Numbers · 1/2',
        semanticLabel: 'Numbers, completed',
        progress: 0.5,
      ),
    );

    expect(
      find.byKey(PathNode.progressRingKey),
      paints
        ..arc(color: _palette.surfaceContainer)
        ..arc(color: _palette.primaryContainer),
    );
    final circle = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.byType(Icon),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .first;
    expect(circle.color, _palette.primaryContainer);
    expect(circle.boxShadow!.first.color, _palette.primaryShelf);
  });

  testWidgets("a button's face comes from the theme's palette", (tester) async {
    await _pump(tester, AppButton.primary(label: 'Continue', onPressed: () {}));

    final face = tester.widget<TactilePressable>(find.byType(TactilePressable));
    expect(face.faceColor, _palette.primaryContainer);
  });

  testWidgets("an answer tile's graded look comes from the theme's palette", (
    tester,
  ) async {
    await _pump(
      tester,
      AnswerTile(label: 'ha', state: AnswerTileState.correct, onTap: () {}),
    );

    final face = tester.widget<TactilePressable>(find.byType(TactilePressable));
    expect(face.faceColor, _palette.answerCorrectFace);
  });

  testWidgets('the patterned page background paints in the palette', (
    tester,
  ) async {
    await _pump(
      tester,
      const SizedBox(
        width: 200,
        height: 200,
        child: AppBackground(
          style: AppPageBackground.patterned,
          child: SizedBox.expand(),
        ),
      ),
    );

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<LatticePainter>()
        .single;
    expect(painter.colors, same(_palette));
    expect(
      tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(AppBackground),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color,
      _palette.surface,
    );
  });
}
