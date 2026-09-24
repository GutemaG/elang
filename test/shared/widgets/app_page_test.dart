// AppPage, AppTopBar, AppBackground and TibebStripe (018-mobile-design-system,
// story 005).

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_icon_button.dart';
import 'package:elang/shared/widgets/app_page.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:elang/shared/widgets/tactile_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void _noop() {}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
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
        child: page,
      ),
    ),
  );
}

Widget _rows(int count) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < count; i++) SizedBox(height: 60, child: Text('Row $i')),
  ],
);

const _dock = [
  AppButton.primary(label: 'Continue', onPressed: _noop),
  AppButton.secondary(label: 'Review mistakes', onPressed: _noop),
];

void main() {
  group('AppPage', () {
    testWidgets('should give the body the cream background, 20 px margins '
        'and scrolling without the screen setting any of them', (tester) async {
      await _pump(tester, const AppPage(body: Text('Hello')));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.background);
      expect(find.byType(SafeArea), findsOneWidget);
      expect(tester.getTopLeft(find.text('Hello')).dx, AppSpacing.marginMobile);
      expect(
        find.ancestor(
          of: find.text('Hello'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });

    testWidgets('should leave scrolling and margins to screens that own them', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppPage(scrollable: false, padded: false, body: Text('Edge')),
      );

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.getTopLeft(find.text('Edge')).dx, 0);
    });

    testWidgets('should pin the dock above the safe area, 8 px apart', (
      tester,
    ) async {
      await _pump(tester, AppPage(body: _rows(3), bottomDock: _dock));

      final buttons = find.byType(AppButton);
      final first = tester.getRect(buttons.at(0));
      final second = tester.getRect(buttons.at(1));
      expect(second.bottom, 640 - AppSpacing.spaceLg);
      expect(second.top - first.bottom, AppSpacing.spaceXs);
      expect(first.left, AppSpacing.marginMobile);
      expect(first.right, 360 - AppSpacing.marginMobile);
    });

    testWidgets('should let the last line of content scroll fully clear of '
        'the dock', (tester) async {
      await _pump(tester, AppPage(body: _rows(30), bottomDock: _dock));

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();

      final lastRow = tester.getRect(find.text('Row 29'));
      final dockTop = tester.getRect(find.byType(AppButton).first).top;
      expect(lastRow.bottom, lessThanOrEqualTo(dockTop - AppPage.dockFade));
    });

    testWidgets('should keep the dock above the keyboard', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await _pump(tester, AppPage(body: _rows(30), bottomDock: _dock));

      expect(
        tester.getRect(find.byType(AppButton).last).bottom,
        640 - 300 - AppSpacing.spaceLg,
      );
    });

    testWidgets('should scroll and keep the dock visible on a short phone '
        'at 1.3x text', (tester) async {
      await _pump(
        tester,
        AppPage(
          topBar: const AppTopBar(title: 'Lesson complete'),
          body: _rows(30),
          bottomDock: _dock,
          footerStripe: true,
        ),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      final dock = tester.getRect(find.byType(AppButton).last);
      expect(dock.bottom, lessThanOrEqualTo(640));
      expect(dock.top, greaterThan(0));
      await tester.tap(find.text('Review mistakes'));
    });

    testWidgets('should put the woven Tibeb stripe at the very bottom', (
      tester,
    ) async {
      await _pump(tester, const AppPage(body: Text('x'), footerStripe: true));

      final stripe = find.byType(TibebStripe);
      expect(tester.widget<TibebStripe>(stripe).style, TibebStyle.woven);
      expect(tester.getRect(stripe).bottom, 640);
      expect(tester.getRect(stripe).height, TibebStripe.wovenHeight);
      expect(tester.getRect(stripe).width, 360);
    });

    testWidgets('should draw no stripe unless asked', (tester) async {
      await _pump(tester, const AppPage(body: Text('x')));

      expect(find.byType(TibebStripe), findsNothing);
    });
  });

  group('AppBackground', () {
    CustomPaint? paintOf(WidgetTester tester, Type painter) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((p) => p.painter?.runtimeType == painter)
        .firstOrNull;

    testWidgets('plain should paint nothing but cream', (tester) async {
      await _pump(tester, const AppPage(body: Text('x')));

      expect(paintOf(tester, LatticePainter), isNull);
      expect(paintOf(tester, CelebrationGlowPainter), isNull);
    });

    testWidgets('patterned should paint the lattice once, not again when '
        'the page scrolls or a button on it animates', (tester) async {
      await _pump(
        tester,
        AppPage(
          background: AppPageBackground.patterned,
          body: _rows(30),
          bottomDock: _dock,
        ),
      );

      final lattice = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is LatticePainter,
      );
      expect(lattice, findsOneWidget);
      // The layer the lattice is painted into: its nearest repaint boundary.
      RenderObject node = tester.renderObject(lattice);
      while (!node.isRepaintBoundary) {
        node = node.parent!;
      }
      final boundary = node as RenderRepaintBoundary;
      // A layer of its own: nothing else on the page can make it repaint.
      expect(boundary.child, tester.renderObject(lattice));
      int paints() =>
          boundary.debugSymmetricPaintCount +
          boundary.debugAsymmetricPaintCount;
      final before = paints();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      final press = await tester.startGesture(
        tester.getCenter(find.byType(AppButton).first),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      await press.up();
      await tester.pumpAndSettle();

      expect(paints(), before);
      expect(
        const LatticePainter().shouldRepaint(const LatticePainter()),
        isFalse,
      );
    });

    testWidgets('celebration should paint the glow behind the content', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppPage(
          background: AppPageBackground.celebration,
          body: Text('Lesson complete!'),
        ),
      );

      expect(paintOf(tester, CelebrationGlowPainter), isNotNull);
      expect(
        const CelebrationGlowPainter().shouldRepaint(
          const CelebrationGlowPainter(),
        ),
        isFalse,
      );
    });

    testWidgets('painted backgrounds should be hidden from screen readers', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppPage(background: AppPageBackground.patterned, body: Text('x')),
      );

      expect(
        find.ancestor(
          of: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is LatticePainter,
          ),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });
  });

  group('AppTopBar', () {
    testWidgets('should line a leading icon button up with the page margin '
        'and centre the title', (tester) async {
      await _pump(
        tester,
        const AppPage(
          topBar: AppTopBar(
            leading: AppIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              onPressed: _noop,
            ),
            title: 'Settings',
            trailing: [AppButton.text(label: 'Skip', onPressed: _noop)],
          ),
          body: Text('Body'),
        ),
      );

      final face = tester.getRect(
        find.descendant(
          of: find.byType(AppIconButton),
          matching: find.byType(TactilePressable),
        ),
      );
      expect(face.left, AppSpacing.marginMobile);
      expect(tester.getCenter(find.text('Settings')).dx, 180);
      expect(
        tester.getRect(find.byType(AppTopBar)).height,
        AppTopBar.minHeight,
      );
    });

    testWidgets('should mark its title as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const AppPage(
          topBar: AppTopBar(title: 'Settings'),
          body: SizedBox(),
        ),
      );

      expect(
        tester.getSemantics(find.text('Settings')),
        isSemantics(label: 'Settings', isHeader: true),
      );
      semantics.dispose();
    });

    testWidgets('brand should show the Buna wordmark', (tester) async {
      await _pump(
        tester,
        const AppPage(topBar: AppTopBar.brand(), body: SizedBox()),
      );

      final wordmark = tester.widget<Text>(find.text('Buna'));
      expect(wordmark.style!.color, AppColors.primary);
    });

    testWidgets('should shrink a crowded row of stat pills rather than '
        'overflow at 320 px and 1.3x text', (tester) async {
      await _pump(
        tester,
        const AppPage(
          topBar: AppTopBar(
            leading: AppIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              onPressed: _noop,
            ),
            trailing: [
              StatPill(kind: StatKind.streak, value: 365),
              StatPill(kind: StatKind.beans, value: 5, max: 5),
              StatPill(kind: StatKind.xp, value: 123456),
              StatPill(kind: StatKind.amole, value: 12340),
            ],
          ),
          body: SizedBox(),
        ),
        size: const Size(320, 640),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(StatPill).last).right, lessThan(320));
    });
  });

  group('TibebStripe', () {
    testWidgets('gradient should run green to gold to terracotta', (
      tester,
    ) async {
      await _pump(
        tester,
        const Center(child: TibebStripe(style: TibebStyle.gradient)),
      );

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(TibebStripe),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, [
        AppColors.primary,
        AppColors.secondaryContainer,
        AppColors.tertiaryContainer,
      ]);
      expect(
        tester.getSize(find.byType(TibebStripe)).height,
        TibebStripe.gradientHeight,
      );
    });

    test('woven should repeat the mockup\'s four bands', () {
      expect(WovenTibebPainter.bands.map((b) => b.$1), [
        AppColors.tertiary,
        AppColors.secondaryContainer,
        AppColors.primary,
        AppColors.surface,
      ]);
      expect(WovenTibebPainter.bands.map((b) => b.$2), [8, 8, 8, 4]);
    });
  });
}
