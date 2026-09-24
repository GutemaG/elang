import 'package:elang/shared/gallery/component_gallery.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/app_sheet.dart';
import 'package:elang/shared/widgets/exercise/answer_action_bar.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/exercise/exercise_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The gallery lays out every section at once (a Column, not a lazy list),
// so building it is enough to catch any component that overflows.
void main() {
  const sizes = [Size(360, 640), Size(430, 932)];
  const scales = [1.0, 1.3];

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('should lay out every component without overflow when '
          '${size.width.toInt()}×${size.height.toInt()} at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery.withClampedTextScaling(
              minScaleFactor: scale,
              maxScaleFactor: scale,
              child: const ComponentGallery(),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('AppButton'), findsOneWidget);
      });
    }
  }

  // The gallery shows spinners on purpose, so it never settles: wait out a
  // route transition instead.
  Future<void> settleRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  // Each sheet and dialog, opened from the gallery on a short phone with
  // large text: it must lay out, and its last action must be reachable and
  // return a value to the page.
  const opened = {
    'Out of beans': ('Not now', 'Out-of-beans sheet returned null'),
    'Leave sheet': ('Leave', 'Leave sheet returned true'),
    'Tall sheet': ('Not now', 'Tall sheet returned null'),
    'Level-up dialog': ('Continue', 'Level-up dialog returned true'),
    'Delete confirm': ('Cancel', 'Confirm dialog returned false'),
  };
  for (final MapEntry(key: button, value: (action, result)) in opened.entries) {
    testWidgets('should open "$button" at 360×640 with 1.3x text and reach '
        'its last action', (tester) async {
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
      final page = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text(button), 300, scrollable: page);
      await tester.tap(find.text(button));
      await settleRoute(tester);
      expect(tester.takeException(), isNull);

      final overlay = find.byWidgetPredicate(
        (w) => w is AppSheetFrame || w is AppDialogFrame,
      );
      expect(overlay, findsOneWidget);
      final target = find.descendant(of: overlay, matching: find.text(action));
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find
            .descendant(of: overlay, matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(target);
      await settleRoute(tester);

      expect(overlay, findsNothing);
      expect(find.textContaining(result), findsOneWidget);
    });
  }

  Future<void> openGallery(WidgetTester tester) async {
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
  }

  /// An interactive tile or pill labelled [label], nth among those.
  Finder tile(String label, {AnswerTileShape? shape}) => find.byWidgetPredicate(
    (w) =>
        w is AnswerTile &&
        w.label == label &&
        w.onTap != null &&
        (shape == null || w.shape == shape),
  );

  testWidgets('the question demo grades a tapped answer at 360×640 with '
      '1.3x text, and Continue resets it', (tester) async {
    await openGallery(tester);
    final page = find.byType(Scrollable).first;
    final tea = tile('Tea').first;
    await tester.scrollUntilVisible(tea, 300, scrollable: page);
    await tester.tap(tea);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    final demo = find.byType(ExerciseLayout);
    final panel = find.descendant(
      of: demo,
      matching: find.byType(AnswerFeedbackPanel),
    );
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: demo, matching: find.text('Not quite')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: demo, matching: find.text('Continue')),
    );
    await tester.pump();
    expect(panel, findsNothing);
  });

  testWidgets('the sentence demo builds and checks a sentence at 360×640 '
      'with 1.3x text', (tester) async {
    await openGallery(tester);
    final page = find.byType(Scrollable).first;
    final demo = find.ancestor(
      of: find.textContaining('AnswerSlotLine.sentence: build'),
      matching: find.byType(GalleryCase),
    );
    for (final word in ['እኔ', 'ቡና', 'እፈልጋለሁ']) {
      // The word-bank pill: it comes after any placed copy of the word.
      final pill = find
          .descendant(
            of: demo,
            matching: tile(word, shape: AnswerTileShape.pill),
          )
          .last;
      await tester.scrollUntilVisible(pill, 300, scrollable: page);
      await tester.tap(pill);
      await tester.pump();
    }
    // The demo's own bar: it has both Check and Continue.
    final demoBar = find.byWidgetPredicate(
      (w) => w is AnswerActionBar && w.onCheck != null && w.onContinue != null,
    );
    final check = find.descendant(of: demoBar, matching: find.text('Check'));
    await tester.scrollUntilVisible(check, 300, scrollable: page);
    await tester.tap(check.first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    // The demo's own bar (the one with Check) is now graded right.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is AnswerActionBar &&
            w.onCheck != null &&
            w.grade == AnswerGrade.correct,
      ),
      findsOneWidget,
    );
  });
}
