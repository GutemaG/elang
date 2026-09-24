// showAppSheet, showAppDialog, showAppConfirmDialog and SheetHero
// (018-mobile-design-system, story 007).

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_icon_button.dart';
import 'package:elang/shared/widgets/app_sheet.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page with one button that runs [open] and records what it returns.
class _Opener<T> extends StatefulWidget {
  const _Opener(this.open);

  final Future<T?> Function(BuildContext context) open;

  @override
  State<_Opener<T>> createState() => _OpenerState<T>();
}

class _OpenerState<T> extends State<_Opener<T>> {
  String result = 'none';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                final value = await widget.open(context);
                setState(() => result = 'result: $value');
              },
              child: const Text('open'),
            ),
            Text(result),
          ],
        ),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Future<Object?> Function(BuildContext) open, {
  Size size = const Size(360, 640),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: _Opener<Object?>(open),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Widget _hero(BuildContext context, {int items = 0}) => SheetHero(
  illustration: const Icon(Icons.local_cafe),
  illustrationBadge: const CountBadge(label: '0 / 5', tone: AppTone.tertiary),
  tone: AppTone.tertiary,
  title: 'Out of beans!',
  secondLanguage: 'ቡና አለቀ!',
  phonetic: 'Buna aleke!',
  body: 'Beans refill over time.',
  content: Column(
    children: [
      for (var i = 0; i < items; i++)
        SizedBox(height: 80, child: Text('Item $i')),
    ],
  ),
  primaryAction: AppButton.accent(
    label: 'Refill',
    onPressed: () => Navigator.of(context).pop('refill'),
  ),
  secondaryAction: AppButton.secondary(
    label: 'Practice',
    onPressed: () => Navigator.of(context).pop('practice'),
  ),
  textAction: AppButton.text(
    label: 'Not now',
    onPressed: () => Navigator.of(context).pop(),
  ),
);

void main() {
  group('showAppSheet', () {
    testWidgets('should draw the cream surface, 32 px top radius, overlay '
        'shadow and handle over the warm backdrop', (tester) async {
      await _pump(tester, (c) => showAppSheet(context: c, builder: _hero));

      final frame = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppSheetFrame),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = frame.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surface);
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(32)),
      );
      expect(decoration.boxShadow, AppShadows.overlay);

      final handle = find.descendant(
        of: find.byType(AppSheetFrame),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints ==
                  BoxConstraints.tight(
                    const Size(
                      AppSheetFrame.handleWidth,
                      AppSheetFrame.handleHeight,
                    ),
                  ),
        ),
      );
      expect(handle, findsOneWidget);

      final barrier = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .last;
      expect(barrier.color, AppColors.scrim);
    });

    testWidgets('should return what its content pops', (tester) async {
      await _pump(tester, (c) => showAppSheet(context: c, builder: _hero));

      await tester.tap(find.text('Practice'));
      await tester.pumpAndSettle();
      expect(find.text('result: practice'), findsOneWidget);
    });

    testWidgets('should return null on a backdrop tap', (tester) async {
      await _pump(tester, (c) => showAppSheet(context: c, builder: _hero));

      await tester.tapAt(const Offset(180, 10));
      await tester.pumpAndSettle();
      expect(find.text('result: null'), findsOneWidget);
    });

    testWidgets('should return null on back', (tester) async {
      await _pump(tester, (c) => showAppSheet(context: c, builder: _hero));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('result: null'), findsOneWidget);
    });

    testWidgets('should stay open on a backdrop tap when not dismissible, '
        'and hide the handle when it cannot be dragged', (tester) async {
      await _pump(
        tester,
        (c) => showAppSheet(
          context: c,
          isDismissible: false,
          enableDrag: false,
          builder: _hero,
        ),
      );

      await tester.tapAt(const Offset(180, 10));
      await tester.pumpAndSettle();
      expect(find.byType(SheetHero), findsOneWidget);
      expect(find.text('none'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppSheetFrame),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.maxWidth == AppSheetFrame.handleWidth,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('should scroll when taller than a short phone at 1.3x text, '
        'with every action still reachable', (tester) async {
      await _pump(
        tester,
        (c) => showAppSheet(context: c, builder: (c) => _hero(c, items: 12)),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byType(AppSheetFrame));
      expect(sheet.top, greaterThanOrEqualTo(0));
      expect(sheet.bottom, 640);

      final scroll = find.descendant(
        of: find.byType(AppSheetFrame),
        matching: find.byType(Scrollable),
      );
      // A finger drag, not a programmatic scroll: the learner must be
      // able to reach it.
      await tester.drag(scroll, const Offset(0, -3000));
      await tester.pumpAndSettle();
      final target = tester.getRect(find.text('Not now'));
      expect(target.top, greaterThanOrEqualTo(0));
      expect(target.bottom, lessThanOrEqualTo(640));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('result: null'), findsOneWidget);
    });

    testWidgets('should keep its scrolling area, and so its actions, above '
        'the keyboard', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await _pump(
        tester,
        (c) => showAppSheet(context: c, builder: (c) => _hero(c, items: 3)),
      );

      final scroll = find.descendant(
        of: find.byType(AppSheetFrame),
        matching: find.byType(Scrollable),
      );
      expect(tester.getRect(scroll).bottom, lessThanOrEqualTo(640 - 300));
      // A finger drag, not a programmatic scroll: the learner must be
      // able to reach it.
      await tester.drag(scroll, const Offset(0, -3000));
      await tester.pumpAndSettle();
      final target = tester.getRect(find.text('Not now'));
      expect(target.top, greaterThanOrEqualTo(0));
      expect(target.bottom, lessThanOrEqualTo(640));
      expect(
        tester.getRect(find.text('Not now')).bottom,
        lessThanOrEqualTo(640 - 300),
      );
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('result: null'), findsOneWidget);
    });
  });

  group('showAppDialog', () {
    Future<Object?> open(BuildContext c) => showAppDialog<String>(
      context: c,
      builder: (dc) => SheetHero(
        illustration: const Icon(Icons.workspace_premium),
        tone: AppTone.secondary,
        title: 'Level up!',
        primaryAction: AppButton.primary(
          label: 'Continue',
          onPressed: () => Navigator.of(dc).pop('continue'),
        ),
      ),
    );

    testWidgets('should be a white card on a deep shelf, 32 px radius, over '
        'the warm backdrop', (tester) async {
      await _pump(tester, open);

      final card = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppDialogFrame),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = card.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surfaceContainerLowest);
      expect(decoration.borderRadius, BorderRadius.circular(AppRadii.lg));
      expect(
        (decoration.border! as Border).top.color,
        AppColors.surfaceContainerHighest,
      );
      expect(decoration.boxShadow, AppShadows.dialog);
      expect(
        tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).last.color,
        AppColors.scrim,
      );
      expect(tester.getSize(find.byType(AppDialogFrame)).width, 360);
    });

    testWidgets('should return what its content pops', (tester) async {
      await _pump(tester, open);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('result: continue'), findsOneWidget);
    });

    testWidgets('its close button should return null', (tester) async {
      await _pump(tester, open);

      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();
      expect(find.text('result: null'), findsOneWidget);
    });

    testWidgets('should return null on a backdrop tap and on back', (
      tester,
    ) async {
      await _pump(tester, open);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('result: null'), findsOneWidget);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('result: null'), findsOneWidget);
    });

    testWidgets('should scroll when taller than a short phone at 1.3x text', (
      tester,
    ) async {
      await _pump(
        tester,
        (c) => showAppDialog<String>(
          context: c,
          builder: (dc) => _hero(dc, items: 12),
        ),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      final scroll = find.descendant(
        of: find.byType(AppDialogFrame),
        matching: find.byType(Scrollable),
      );
      // A finger drag, not a programmatic scroll: the learner must be
      // able to reach it.
      await tester.drag(scroll, const Offset(0, -3000));
      await tester.pumpAndSettle();
      final target = tester.getRect(find.text('Practice'));
      expect(target.top, greaterThanOrEqualTo(0));
      expect(target.bottom, lessThanOrEqualTo(640));
      await tester.tap(find.text('Practice'));
      await tester.pumpAndSettle();
      expect(find.text('result: practice'), findsOneWidget);
    });
  });

  group('showAppConfirmDialog', () {
    Future<Object?> open(BuildContext c, {bool destructive = true}) =>
        showAppConfirmDialog(
          context: c,
          title: 'Delete this download?',
          message: 'You can download it again.',
          confirmLabel: 'Delete',
          destructive: destructive,
        );

    testWidgets('should return true for confirm', (tester) async {
      await _pump(tester, open);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('result: true'), findsOneWidget);
    });

    testWidgets('should return false for cancel', (tester) async {
      await _pump(tester, open);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('result: false'), findsOneWidget);
    });

    testWidgets('should return null when dismissed, and show no close '
        'button', (tester) async {
      await _pump(tester, open);
      expect(find.byType(AppIconButton), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('result: null'), findsOneWidget);
    });

    testWidgets('should make the confirm button destructive only when asked', (
      tester,
    ) async {
      await _pump(tester, open);
      final destructive = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Delete'),
      );
      expect(destructive.variant, AppButtonVariant.destructive);
      expect(
        tester.widget<SheetHero>(find.byType(SheetHero)).tone,
        AppTone.tertiary,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await _pump(tester, (c) => open(c, destructive: false));
      final primary = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Delete'),
      );
      expect(primary.variant, AppButtonVariant.primary);
    });
  });

  group('SheetHero', () {
    Future<void> pumpHero(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Builder(builder: (c) => _hero(c)),
            ),
          ),
        ),
      );
    }

    testWidgets('should stack illustration, title, second language, body '
        'and actions in order', (tester) async {
      await pumpHero(tester);

      double top(Finder f) => tester.getRect(f).top;
      final circle = find.descendant(
        of: find.byType(SheetHero),
        matching: find.byIcon(Icons.local_cafe),
      );
      expect(top(circle), lessThan(top(find.text('Out of beans!'))));
      expect(
        top(find.text('Out of beans!')),
        lessThan(top(find.textContaining('ቡና አለቀ!', findRichText: true))),
      );
      expect(
        top(find.textContaining('ቡና', findRichText: true)),
        lessThan(top(find.text('Beans refill over time.'))),
      );
      expect(
        top(find.text('Beans refill over time.')),
        lessThan(top(find.text('Refill'))),
      );
      final refill = tester.getRect(find.byType(AppButton).at(0));
      final practice = tester.getRect(find.byType(AppButton).at(1));
      expect(practice.top - refill.bottom, AppSpacing.spaceXs);
      expect(top(find.text('Not now')), greaterThan(practice.bottom));
    });

    testWidgets('should colour the title by tone and show the phonetic in '
        'brackets', (tester) async {
      await pumpHero(tester);

      expect(
        tester.widget<Text>(find.text('Out of beans!')).style!.color,
        AppTone.tertiary.ink,
      );
      expect(
        find.textContaining('(Buna aleke!)', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('should read its title as a heading and its badge aloud, '
        'but not the decorative circle', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpHero(tester);

      expect(
        tester.getSemantics(find.text('Out of beans!')),
        isSemantics(label: 'Out of beans!', isHeader: true),
      );
      expect(find.bySemanticsLabel('0 / 5'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('should put a tone halo behind the illustration circle', (
      tester,
    ) async {
      await pumpHero(tester);

      final circle = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.local_cafe),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = circle.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.boxShadow, AppShadows.halo(AppTone.tertiary.border));
    });
  });
}
