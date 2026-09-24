// StatPill, CountBadge, RibbonBadge, AppProgressBar, IconBadge, AppSpinner
// and the empty, error and loading states (018-mobile-design-system,
// story 008).

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_status.dart';
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

Widget _center(Widget child, {double textScale = 1}) =>
    _host(Center(child: child), textScale: textScale);

void main() {
  group('groupDigits', () {
    test('should group thousands with commas', () {
      expect(groupDigits(0), '0');
      expect(groupDigits(999), '999');
      expect(groupDigits(1000), '1,000');
      expect(groupDigits(12340), '12,340');
      expect(groupDigits(1234567), '1,234,567');
      expect(groupDigits(-1234), '-1,234');
    });
  });

  group('StatPill', () {
    // The labels LessonHud's pills read today, so moving the dashboard onto
    // StatPill changes nothing for a screen reader.
    final cases = <(StatPill, String, IconData, Color)>[
      (
        const StatPill(kind: StatKind.streak, value: 5),
        '5 day streak',
        Icons.local_fire_department,
        AppColors.streak,
      ),
      (
        const StatPill(kind: StatKind.beans, value: 3, max: 5),
        '3 of 5 beans remaining',
        Icons.favorite,
        AppColors.tertiaryBrand,
      ),
      (
        const StatPill(kind: StatKind.xp, value: 340),
        '340 total XP',
        Icons.bolt,
        AppColors.secondary,
      ),
      (
        const StatPill(kind: StatKind.amole, value: 420),
        '420 Amole',
        Icons.diamond,
        AppColors.gem,
      ),
    ];

    for (final (pill, label, icon, colour) in cases) {
      testWidgets('${pill.kind.name} should read "$label" and show its '
          'coloured icon', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_center(pill));

        expect(
          tester.getSemantics(find.byType(StatPill)),
          isSemantics(label: label),
        );
        expect(tester.widget<Icon>(find.byIcon(icon)).color, colour);
        semantics.dispose();
      });
    }

    testWidgets('should be a translucent white pill with a tinted border', (
      tester,
    ) async {
      await tester.pumpWidget(
        _center(const StatPill(kind: StatKind.streak, value: 5)),
      );

      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(StatPill),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color!.a, closeTo(0.9, 0.01));
      expect((decoration.border! as Border).top.color, AppColors.streakRim);
    });

    testWidgets('should group large numbers and fit them at 1.3x text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _center(
          const Wrap(
            children: [
              StatPill(kind: StatKind.xp, value: 12340),
              StatPill(kind: StatKind.amole, value: 1234567),
            ],
          ),
          textScale: 1.3,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('12,340'), findsOneWidget);
      expect(find.text('1,234,567'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('heightOf should match the rendered height at ${scale}x', (
        tester,
      ) async {
        late double predicted;
        await tester.pumpWidget(
          _center(
            Builder(
              builder: (context) {
                predicted = StatPill.heightOf(context);
                return const StatPill(kind: StatKind.xp, value: 340);
              },
            ),
            textScale: scale,
          ),
        );

        expect(tester.getSize(find.byType(StatPill)).height, predicted);
      });
    }
  });

  group('CountBadge and RibbonBadge', () {
    testWidgets('neutral CountBadge should sit on a small shelf', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _center(const CountBadge(label: '3/5 Completed', icon: Icons.flag)),
      );

      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(CountBadge),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, AppColors.surfaceContainerHigh);
      expect(decoration.boxShadow, isNotEmpty);
      expect(
        tester.getSemantics(find.byType(CountBadge)),
        isSemantics(label: '3/5 Completed'),
      );
      semantics.dispose();
    });

    testWidgets('toned CountBadge should be white with the tone border', (
      tester,
    ) async {
      await tester.pumpWidget(
        _center(const CountBadge(label: '0 / 5', tone: AppTone.tertiary)),
      );

      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(CountBadge),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, AppColors.surfaceContainerLowest);
      final border = (decoration.border! as Border).top;
      expect(border.color, AppTone.tertiary.icon);
      expect(border.width, 2);
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('RibbonBadge should be filled in its tone, and heightOf '
          'should match at ${scale}x', (tester) async {
        late double predicted;
        await tester.pumpWidget(
          _center(
            Builder(
              builder: (context) {
                predicted = RibbonBadge.heightOf(context);
                return const RibbonBadge(label: '+1 TODAY');
              },
            ),
            textScale: scale,
          ),
        );

        expect(
          tester.getSize(find.byType(RibbonBadge)).height,
          closeTo(predicted, 0.5),
        );
        final decoration =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byType(RibbonBadge),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.color, AppTone.tertiary.fill);
        expect(
          tester.widget<Text>(find.text('+1 TODAY')).style!.color,
          AppTone.tertiary.onFill,
        );
      });
    }
  });

  group('AppProgressBar', () {
    final fillFinder = find.descendant(
      of: find.descendant(
        of: find.byType(AppProgressBar),
        matching: find.byType(LayoutBuilder),
      ),
      matching: find.byType(SizedBox),
    );
    Rect fill(WidgetTester tester) => tester.getRect(fillFinder.first);
    Rect track(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(AppProgressBar),
            matching: find.byType(Container),
          )
          .first,
    );
    // The fill runs inside a 1 px border and a 2 px inset.
    const inside = 2 * (1 + 2);

    testWidgets('should fill its share of the sunken track', (tester) async {
      await tester.pumpWidget(_host(const AppProgressBar(value: 0.6)));

      final t = track(tester);
      expect(t.width, 320);
      expect(t.height, 12);
      expect(fill(tester).width, closeTo((320 - inside) * 0.6, 0.01));
      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(AppProgressBar),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, AppColors.surfaceContainerHigh);
    });

    testWidgets('large should be 14 px', (tester) async {
      await tester.pumpWidget(
        _host(const AppProgressBar(value: 0.5, size: AppProgressBarSize.large)),
      );
      expect(track(tester).height, 14);
    });

    testWidgets('should show no fill when empty, a round sliver when '
        'barely started, and clamp past full', (tester) async {
      // In a centring parent too, where nothing stretches it.
      await tester.pumpWidget(_center(const AppProgressBar(value: 0)));
      expect(track(tester).width, 320);
      expect(fillFinder, findsNothing);

      await tester.pumpWidget(_host(const AppProgressBar(value: 0.001)));
      await tester.pumpAndSettle();
      final sliver = fill(tester);
      expect(sliver.width, greaterThanOrEqualTo(sliver.height));
      expect(sliver.height, greaterThan(0));

      await tester.pumpWidget(_host(const AppProgressBar(value: 1.7)));
      await tester.pumpAndSettle();
      expect(fill(tester).width, closeTo(320 - inside, 0.01));
    });

    testWidgets('should ease to a new value over AppMotion.progress, then '
        'settle', (tester) async {
      await tester.pumpWidget(_host(const AppProgressBar(value: 0.2)));
      final start = fill(tester).width;

      await tester.pumpWidget(_host(const AppProgressBar(value: 0.8)));
      await tester.pump(AppMotion.progress ~/ 4);
      final partWay = fill(tester).width;
      expect(partWay, greaterThan(start));
      expect(partWay, lessThan((320 - inside) * 0.8));

      await tester.pumpAndSettle();
      expect(fill(tester).width, closeTo((320 - inside) * 0.8, 0.01));
    });

    testWidgets('should jump straight to a new value with reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const AppProgressBar(value: 0.2), reduceMotion: true),
      );
      await tester.pumpWidget(
        _host(const AppProgressBar(value: 0.8), reduceMotion: true),
      );
      await tester.pump();

      expect(fill(tester).width, closeTo((320 - inside) * 0.8, 0.01));
    });

    testWidgets('should use the tone gradient when asked', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppProgressBar(
            value: 0.65,
            tone: AppTone.secondary,
            gradient: true,
          ),
        ),
      );

      final gradients = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(AppProgressBar),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((b) => (b.decoration as BoxDecoration).gradient)
          .whereType<LinearGradient>();
      expect(gradients.single.colors, [
        AppColors.secondaryContainer,
        AppColors.secondary,
      ]);
    });

    testWidgets('should read what it measures and its percentage, with its '
        'caption row', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const AppProgressBar(
            value: 0.65,
            semanticLabel: 'Next bean',
            startLabel: 'Refills every 30 minutes',
            endLabel: '65%',
          ),
        ),
      );

      expect(find.text('Refills every 30 minutes'), findsOneWidget);
      expect(
        tester.getSemantics(
          find
              .descendant(
                of: find.byType(AppProgressBar),
                matching: find.byType(Container),
              )
              .first,
        ),
        isSemantics(label: 'Next bean', value: '65%'),
      );
      semantics.dispose();
    });
  });

  group('IconBadge and AppSpinner', () {
    testWidgets('IconBadge should be a tinted circle hidden from screen '
        'readers', (tester) async {
      await tester.pumpWidget(
        _center(const IconBadge(icon: Icons.flag, tone: AppTone.primary)),
      );

      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(IconBadge),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, AppTone.primary.surface);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.flag)).color,
        AppTone.primary.icon,
      );
      expect(
        tester.getSize(find.byType(IconBadge)),
        const Size.square(IconBadge.defaultSize),
      );
      expect(
        find.ancestor(
          of: find.byIcon(Icons.flag),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });

    testWidgets('square IconBadge should be a rounded square', (tester) async {
      await tester.pumpWidget(
        _center(const IconBadge(icon: Icons.hourglass_top, square: true)),
      );
      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(IconBadge),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.shape, BoxShape.rectangle);
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('AppSpinner should be the token-coloured indicator', (
      tester,
    ) async {
      await tester.pumpWidget(_center(const AppSpinner.small()));

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, AppColors.primaryContainer);
      expect(tester.getSize(find.byType(AppSpinner)), const Size.square(16));
    });

    testWidgets('AppButton should use it while loading', (tester) async {
      await tester.pumpWidget(
        _center(
          AppButton.primary(label: 'Go', onPressed: () {}, loading: true),
        ),
      );
      expect(find.byType(AppSpinner), findsOneWidget);
    });
  });

  group('EmptyState, ErrorState and LoadingState', () {
    testWidgets('EmptyState should show its badge, title, message and '
        'action', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.download,
            title: 'No downloads yet',
            message: 'Download a lesson to learn offline.',
            action: Text('Go to lessons'),
          ),
        ),
      );

      expect(find.byType(IconBadge), findsOneWidget);
      expect(find.text('No downloads yet'), findsOneWidget);
      expect(find.text('Download a lesson to learn offline.'), findsOneWidget);
      expect(find.text('Go to lessons'), findsOneWidget);
    });

    testWidgets('ErrorState should offer "Try again" when it can retry', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          ErrorState(
            title: "Couldn't load this lesson",
            message: 'Check your connection and try again.',
            onRetry: () => retries++,
          ),
        ),
      );

      expect(
        tester.widget<IconBadge>(find.byType(IconBadge)).tone,
        AppTone.tertiary,
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });

    testWidgets('ErrorState should show no button when it cannot retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ErrorState(title: 'Offline', message: 'Reconnect.')),
      );
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('LoadingState should spin and announce itself', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const LoadingState(message: 'Loading lesson')),
      );

      expect(find.byType(AppSpinner), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(LoadingState)),
        isSemantics(label: 'Loading lesson', isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('LoadingState.still should let pumpAndSettle finish', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const LoadingState.still()));

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(IconBadge), findsOneWidget);
    });

    testWidgets('LoadingState should hold still with reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const LoadingState(), reduceMotion: true));

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should fit a short slot at 1.3x text by scrolling', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            height: 160,
            child: ErrorState(
              title: "Couldn't load this lesson",
              message:
                  'Check your connection and try again. If it keeps '
                  'happening, restart the app.',
            ),
          ),
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
