// What the screen migration added to the library (018-mobile-design-system,
// bolts 046 to 048): PageDots, InfoBanner.action, an ErrorState with no
// message, AppProgressBar.animate, the chip theme, PathNode, CourseGlyph,
// a stripe card that gives way when held short, the heights a pinned
// header reads, and a button that reads its badge.

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/theme/app_typography.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_card.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:elang/shared/widgets/course_glyph.dart';
import 'package:elang/shared/widgets/path_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  double textScale = 1,
  bool reduceMotion = false,
  double width = 320,
}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
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
);

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) =>
    tester.widget<Container>(finder).decoration! as BoxDecoration;

void main() {
  group('PageDots', () {
    Finder dots() => find.descendant(
      of: find.byType(PageDots),
      matching: find.byType(AnimatedContainer),
    );

    testWidgets('one dot per page; the current one is the wide green pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Center(child: PageDots(count: 3, index: 1))),
      );

      expect(dots(), findsNWidgets(3));
      final sizes = [
        for (final e in dots().evaluate())
          tester.getSize(find.byWidget(e.widget)),
      ];
      // Each dot keeps 4 px either side of it.
      const margins = 2 * AppSpacing.space2xs;
      expect(sizes.map((s) => s.width), [
        PageDots.dotSize + margins,
        PageDots.activeWidth + margins,
        PageDots.dotSize + margins,
      ]);
      expect(sizes.every((s) => s.height == PageDots.dotSize), isTrue);
      expect(PageDots.dotSize, 10);
      expect(PageDots.activeWidth, 28);

      final colours = [
        for (final e in dots().evaluate())
          ((e.widget as AnimatedContainer).decoration! as BoxDecoration).color,
      ];
      expect(colours, [
        AppColors.outlineVariant,
        AppColors.primaryContainer,
        AppColors.outlineVariant,
      ]);
    });

    testWidgets('a screen reader hears which page, and only that', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const Center(child: PageDots(count: 3, index: 1))),
      );

      expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('moving eases over AppMotion.state, or jumps with reduced '
        'motion', (tester) async {
      Widget at(int index, {bool reduce = false}) => _host(
        Center(child: PageDots(count: 3, index: index)),
        reduceMotion: reduce,
      );
      await tester.pumpWidget(at(0));
      await tester.pumpWidget(at(1));
      await tester.pump(AppMotion.state ~/ 2);
      final halfWay = tester.getSize(
        find.byWidget(dots().evaluate().elementAt(1).widget),
      );
      const margins = 2 * AppSpacing.space2xs;
      expect(halfWay.width, greaterThan(PageDots.dotSize + margins));
      expect(halfWay.width, lessThan(PageDots.activeWidth + margins));
      await tester.pumpAndSettle();

      await tester.pumpWidget(at(0, reduce: true));
      await tester.pumpWidget(at(2, reduce: true));
      await tester.pump();
      expect(
        tester
            .getSize(find.byWidget(dots().evaluate().elementAt(2).widget))
            .width,
        PageDots.activeWidth + margins,
      );
    });
  });

  group('InfoBanner.action', () {
    testWidgets('the action sits at the end and works', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          InfoBanner(
            icon: Icons.info_outline,
            message: 'Something went wrong — try again',
            action: AppButton.secondary(
              label: 'Retry',
              onPressed: () => taps++,
              expand: false,
              size: AppButtonSize.compact,
            ),
          ),
        ),
      );

      final banner = tester.getRect(find.byType(InfoBanner));
      final retry = tester.getRect(find.byType(AppButton));
      // Inside the 1 px border and the banner's 8 px end padding.
      expect(retry.right, closeTo(banner.right - 1 - AppSpacing.spaceXs, 0.01));
      expect(
        retry.left,
        greaterThan(
          tester.getRect(find.text('Something went wrong — try again')).right,
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(taps, 1);
    });

    testWidgets('with an action it is a rounded card; without, a stadium', (
      tester,
    ) async {
      BorderRadius radius() =>
          _decorationOf(
                tester,
                find
                    .descendant(
                      of: find.byType(InfoBanner),
                      matching: find.byType(Container),
                    )
                    .first,
              ).borderRadius!
              as BorderRadius;

      await tester.pumpWidget(
        _host(
          const InfoBanner(
            icon: Icons.info_outline,
            message: 'Hi',
            action: Text('Act'),
          ),
        ),
      );
      expect(radius(), BorderRadius.circular(AppRadii.base));

      await tester.pumpWidget(
        _host(const InfoBanner(icon: Icons.info_outline, message: 'Hi')),
      );
      expect(radius(), BorderRadius.circular(AppRadii.full));
    });

    testWidgets('the message is read as one phrase, and the action as its own '
        'button', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          InfoBanner(
            icon: Icons.info_outline,
            message: 'Sign-in was cancelled',
            action: AppButton.secondary(
              label: 'Retry',
              onPressed: () {},
              expand: false,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Sign-in was cancelled'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(AppButton)),
        isSemantics(label: 'Retry', isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('a long message wraps beside the action without overflowing, '
        'at 1.3x on 320 px', (tester) async {
      await tester.pumpWidget(
        _host(
          InfoBanner(
            icon: Icons.info_outline,
            message: 'Something went wrong — try again, and again, and again',
            action: AppButton.secondary(
              label: 'Retry',
              onPressed: () {},
              leading: const Icon(Icons.refresh, size: 18),
              expand: false,
              size: AppButtonSize.compact,
            ),
          ),
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ErrorState without a message', () {
    testWidgets('shows the title and Retry, and no empty line', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          ErrorState(
            title: "Couldn't load the courses.",
            onRetry: () => retries++,
            retryLabel: 'Retry',
          ),
        ),
      );

      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(ErrorState),
          matching: find.byType(Text),
        ),
      );
      expect(texts.map((t) => t.data), ["Couldn't load the courses.", 'Retry']);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });

  group('AppProgressBar', () {
    double fillWidth(WidgetTester tester) => tester
        .getSize(
          find
              .descendant(
                of: find.byType(AppProgressBar),
                matching: find.byType(SizedBox),
              )
              .last,
        )
        .width;

    testWidgets('with animate false it shows a new value at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const AppProgressBar(value: 0.2, animate: false)),
      );
      final at20 = fillWidth(tester);
      await tester.pumpWidget(
        _host(const AppProgressBar(value: 0.8, animate: false)),
      );
      await tester.pump();
      expect(fillWidth(tester), closeTo(at20 * 4, 0.5));
    });

    testWidgets('regularHeight and largeHeight are the heights it renders', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppProgressBar(value: 0.5)));
      expect(
        tester.getSize(find.byType(AppProgressBar)).height,
        AppProgressBar.regularHeight,
      );
      await tester.pumpWidget(
        _host(const AppProgressBar(value: 0.5, size: AppProgressBarSize.large)),
      );
      expect(
        tester.getSize(find.byType(AppProgressBar)).height,
        AppProgressBar.largeHeight,
      );
      expect(AppProgressBar.regularHeight, 12);
      expect(AppProgressBar.largeHeight, 14);
    });
  });

  group('CountBadge.verticalChrome', () {
    for (final tone in [AppTone.neutral, AppTone.tertiary]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('is the badge height less its label ($tone, ${scale}x)', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              Center(
                child: CountBadge(label: '3/5 Completed', tone: tone),
              ),
              textScale: scale,
            ),
          );
          final badge = tester.getSize(find.byType(CountBadge)).height;
          final label = tester.getSize(find.text('3/5 Completed')).height;
          expect(
            badge,
            closeTo(label + CountBadge.verticalChrome(tone: tone), 0.01),
          );
        });
      }
    }
  });

  group('AppCard with a top stripe', () {
    testWidgets('held shorter than its content, it squeezes a flexible child '
        'instead of overflowing', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            height: 70,
            child: AppCard(
              topStripe: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 20),
                  Flexible(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('unconstrained, it still hugs its content', (tester) async {
      await tester.pumpWidget(
        _host(const AppCard(topStripe: true, child: SizedBox(height: 40))),
      );
      expect(
        tester.getSize(find.byType(AppCard)).height,
        AppShadows.shelfDepth +
            2 * AppCard.borderWidth +
            6 +
            2 * AppSpacing.spaceMd +
            40,
      );
    });
  });

  group('AppButton with a badge', () {
    testWidgets('a screen reader hears the badge after the label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          AppButton.accent(
            label: 'Refill with Amole',
            onPressed: () {},
            badge: const AppButtonBadge(label: '350 Amole'),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppButton)),
        isSemantics(
          label: 'Refill with Amole, 350 Amole',
          isButton: true,
        ),
      );

      await tester.pumpWidget(
        _host(AppButton.primary(label: 'Continue', onPressed: () {})),
      );
      expect(
        tester.getSemantics(find.byType(AppButton)),
        isSemantics(label: 'Continue', isButton: true),
      );
      semantics.dispose();
    });
  });

  group('AppButton badge room', () {
    Widget refill(double width, {double textScale = 1}) => _host(
      AppButton.accent(
        label: 'Refill with Amole',
        onPressed: () {},
        leading: const Icon(Icons.bolt),
        badge: const AppButtonBadge(label: '350 Amole', icon: Icons.diamond),
      ),
      width: width,
      textScale: textScale,
    );

    testWidgets('a badge too wide for half the button shrinks, and the label '
        'keeps the rest', (tester) async {
      await tester.pumpWidget(refill(272, textScale: 1.3));

      expect(tester.takeException(), isNull);
      final inner = 272 - 2 * AppSpacing.spaceLg - 4;
      final badge = tester.getRect(find.byType(AppButtonBadge));
      expect(
        badge.width,
        lessThanOrEqualTo(inner * AppButton.badgeShare + 0.01),
      );
      expect(
        tester.getSize(find.text('Refill with Amole')).width,
        greaterThan(40),
      );
      expect(AppButton.badgeShare, 0.5);
    });

    testWidgets('with room to spare, the badge keeps its own size', (
      tester,
    ) async {
      await tester.pumpWidget(refill(600));
      final shown = tester.getRect(find.byType(AppButtonBadge)).width;
      final natural = tester.getSize(find.byType(AppButtonBadge)).width;
      expect(shown, closeTo(natural, 0.01));
    });
  });

  group('the chip theme', () {
    final theme = AppTheme.chipTheme;
    const chosen = {WidgetState.selected};
    const idle = <WidgetState>{};

    test('a chosen chip takes the chosen-option face and a green border', () {
      expect(theme.color!.resolve(chosen), AppColors.optionChosen);
      expect(theme.color!.resolve(idle), AppColors.surfaceContainerLowest);
      final side = theme.side! as WidgetStateBorderSide;
      expect(side.resolve(chosen)!.color, AppColors.primaryContainer);
      expect(side.resolve(idle)!.color, AppColors.cardBorderDefault);
      expect(side.resolve(chosen)!.width, 2);
      expect(side.resolve(idle)!.width, 2);
    });

    test('the label is label-md, green when chosen', () {
      final style = theme.labelStyle! as WidgetStateTextStyle;
      expect(style.resolve(chosen).color, AppColors.primary);
      expect(style.resolve(idle).color, AppColors.onSurface);
      expect(style.resolve(idle).fontSize, AppTypography.labelMd.fontSize);
    });

    test('it is a flat stadium with a check, and the app theme uses it', () {
      expect(theme.shape, const StadiumBorder());
      expect(theme.showCheckmark, isTrue);
      expect(theme.checkmarkColor, AppColors.primaryContainer);
      expect(theme.elevation, 0);
      expect(AppTheme.light.chipTheme.color, isNotNull);
      expect(
        AppTheme.light.chipTheme.color!.resolve(chosen),
        AppColors.optionChosen,
      );
    });

    testWidgets('a ChoiceChip picks it up from the theme', (tester) async {
      await tester.pumpWidget(
        _host(
          Center(
            child: ChoiceChip(
              label: const Text('English'),
              selected: true,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      // The chip paints its face and border as an Ink decoration.
      final face =
          tester
                  .widget<Ink>(
                    find.descendant(
                      of: find.byType(ChoiceChip),
                      matching: find.byType(Ink),
                    ),
                  )
                  .decoration!
              as ShapeDecoration;
      expect(face.color, AppColors.optionChosen);
      expect(
        (face.shape as OutlinedBorder).side.color,
        AppColors.primaryContainer,
      );
    });
  });

  group('PathNode', () {
    Widget node({
      PathNodeState state = PathNodeState.active,
      double? progress,
      int crownLevel = 0,
      VoidCallback? onTap,
    }) => _host(
      Center(
        child: PathNode(
          state: state,
          label: 'Numbers · 1/2',
          semanticLabel: 'Numbers, active',
          progress: progress,
          crownLevel: crownLevel,
          onTap: onTap,
        ),
      ),
    );

    BoxDecoration circle(WidgetTester tester) => _decorationOf(
      tester,
      find
          .ancestor(of: find.byType(Icon), matching: find.byType(Container))
          .first,
    );

    final looks = {
      PathNodeState.locked: (
        Icons.lock_outline,
        PathNode.size,
        AppColors.surfaceDim,
        AppColors.lockedNodeIcon,
      ),
      PathNodeState.active: (
        Icons.play_arrow,
        PathNode.activeSize,
        AppColors.secondaryContainer,
        AppColors.activeNodeShelf,
      ),
      PathNodeState.completed: (
        Icons.check,
        PathNode.size,
        AppColors.primaryContainer,
        AppColors.primaryBevel,
      ),
    };
    for (final MapEntry(key: state, value: look) in looks.entries) {
      testWidgets('$state: its icon, size, face and shelf', (tester) async {
        await tester.pumpWidget(node(state: state));
        final (icon, size, face, shelf) = look;

        expect(find.byIcon(icon), findsOneWidget);
        final box = find
            .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
            .first;
        expect(tester.getSize(box), Size(size, size));
        final decoration = circle(tester);
        expect(decoration.color, face);
        expect(decoration.boxShadow, [
          AppShadows.shelf(shelf, depth: PathNode.shelfDepth),
        ]);
      });
    }

    test('the sizes are the ones the dashboard has always used', () {
      expect(PathNode.activeSize, 80);
      expect(PathNode.size, 64);
      expect(PathNode.shelfDepth, 6);
    });

    testWidgets('a ring only with progress', (tester) async {
      await tester.pumpWidget(node());
      expect(find.byKey(PathNode.progressRingKey), findsNothing);
      await tester.pumpWidget(node(progress: 0.5));
      expect(find.byKey(PathNode.progressRingKey), findsOneWidget);
      expect(PathNode.progressRingKey, const ValueKey('skill-progress-ring'));
    });

    testWidgets('a crown badge only on a completed node with a level', (
      tester,
    ) async {
      await tester.pumpWidget(
        node(state: PathNodeState.completed, crownLevel: 2),
      );
      expect(find.text('Lv 2'), findsOneWidget);
      await tester.pumpWidget(node(state: PathNodeState.completed));
      expect(find.textContaining('Lv'), findsNothing);
      await tester.pumpWidget(node(crownLevel: 2));
      expect(find.textContaining('Lv'), findsNothing);
    });

    testWidgets('the node and its label are one tap target', (tester) async {
      var taps = 0;
      await tester.pumpWidget(node(onTap: () => taps++));
      await tester.tap(find.text('Numbers · 1/2'));
      await tester.tap(find.byIcon(Icons.play_arrow));
      expect(taps, 2);
    });

    testWidgets('a locked node never takes a tap, even with onTap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        node(state: PathNodeState.locked, onTap: () => taps++),
      );
      await tester.tap(find.byIcon(Icons.lock_outline), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('a screen reader hears its label as one button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(node(onTap: () {}));
      expect(
        tester.getSemantics(find.byType(PathNode)),
        isSemantics(
          label: 'Numbers, active',
          isButton: true,
          isEnabled: true,
        ),
      );
      await tester.pumpWidget(node(state: PathNodeState.locked));
      expect(
        tester.getSemantics(find.byType(PathNode)),
        isSemantics(
          label: 'Numbers, active',
          isButton: true,
          isEnabled: false,
        ),
      );
      semantics.dispose();
    });
  });

  group('CourseGlyph', () {
    testWidgets("shows the language's first character on a green tile", (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Center(child: CourseGlyph(languageCode: 'am', size: 44))),
      );
      expect(find.text('አ'), findsOneWidget);
      expect(tester.getSize(find.byType(CourseGlyph)), const Size(44, 44));
      final decoration = _decorationOf(tester, find.byType(Container).last);
      expect(decoration.color, AppColors.primaryContainer);
    });

    testWidgets('the active course wears the gold ring', (tester) async {
      Border border() =>
          _decorationOf(tester, find.byType(Container).last).border! as Border;

      await tester.pumpWidget(
        _host(
          const Center(child: CourseGlyph(languageCode: 'om', selected: true)),
        ),
      );
      expect(border().top.color, AppColors.secondaryContainer);
      expect(border().top.width, 3);

      await tester.pumpWidget(
        _host(const Center(child: CourseGlyph(languageCode: 'om'))),
      );
      expect(border().top.color, AppColors.outlineVariant);
      expect(border().top.width, 1);
    });
  });
}
