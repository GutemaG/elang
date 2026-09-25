// The component gallery's picture section (019-image-choice-exercise-types,
// bolt 053, story 001): every tile state, grids of 2, 3 and 4, a loading
// and a failed picture, and a grid that grades on the tap.

import 'package:elang/shared/gallery/component_gallery.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/exercise/answer_action_bar.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/exercise/picture_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openGallery(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.3,
        maxScaleFactor: 1.3,
        child: const ComponentGallery(),
      ),
    ),
  );
  await tester.pump();
}

Finder _picture(String altText) =>
    find.byWidgetPredicate((w) => w is PictureTile && w.altText == altText);

void main() {
  testWidgets('every tile state is shown as a picture', (tester) async {
    await _openGallery(tester);

    final states = tester
        .widgetList<PictureTile>(find.byType(PictureTile, skipOffstage: false))
        .map((t) => t.state)
        .toSet();
    expect(states, AnswerTileState.values.toSet());
  });

  testWidgets('grids of 2, 3 and 4 pictures are shown', (tester) async {
    await _openGallery(tester);

    final sizes = tester
        .widgetList<PictureGrid>(find.byType(PictureGrid, skipOffstage: false))
        .map((g) => g.children.length)
        .toSet();
    expect(sizes, {2, 3, 4});
  });

  testWidgets('a loading picture and a failed one are shown, and the failed '
      'one can still be chosen', (tester) async {
    await _openGallery(tester);

    final coffee = tester.widgetList<PictureTile>(
      find.byWidgetPredicate(
        (w) => w is PictureTile && w.altText == 'A cup of coffee',
        skipOffstage: false,
      ),
    );
    expect(coffee, hasLength(2));
    expect(coffee.every((t) => t.onTap != null), isTrue);
    expect(coffee.map((t) => t.image.runtimeType.toString()).toSet(), {
      '_NeverLoads',
      'MemoryImage',
    });
  });

  testWidgets('the three-picture grid grades on the tap at 360×640 with 1.3x '
      'text, and Continue resets it', (tester) async {
    await _openGallery(tester);
    final page = find.byType(Scrollable).first;
    final demo = find.ancestor(
      of: find.textContaining('three pictures, the last centred'),
      matching: find.byType(GalleryCase),
    );
    final house = find.descendant(of: demo, matching: _picture('A house'));

    await tester.scrollUntilVisible(house, 300, scrollable: page);
    await tester.tap(house);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    PictureTile tile(String alt) => tester.widget<PictureTile>(
      find.descendant(of: demo, matching: _picture(alt)),
    );
    expect(tile('A house').state, AnswerTileState.correct);
    expect(tile('A dog').onTap, isNull);
    final bar = find.descendant(
      of: demo,
      matching: find.byType(AnswerActionBar),
    );
    expect(tester.widget<AnswerActionBar>(bar).grade, AnswerGrade.correct);

    final next = find.descendant(of: demo, matching: find.text('Continue'));
    await tester.ensureVisible(next);
    await tester.pump();
    await tester.tap(next);
    await tester.pump();
    expect(tile('A house').state, AnswerTileState.idle);
    expect(tile('A dog').onTap, isNotNull);
  });
}
