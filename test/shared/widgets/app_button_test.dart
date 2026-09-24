import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_icon_button.dart';
import 'package:elang/shared/widgets/tactile_button.dart';
import 'package:elang/shared/widgets/tactile_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: Center(
        child: SizedBox(width: 320, child: Center(child: child)),
      ),
    ),
  ),
);

/// How far the tactile face under [finder] has sunk.
double _sink(WidgetTester tester, [Finder? finder]) {
  final transform = tester.widget<Transform>(
    find
        .descendant(
          of: finder ?? find.byType(TactilePressable),
          matching: find.byType(Transform),
        )
        .first,
  );
  return transform.transform.getTranslation().y;
}

/// Holds a press past the tap-down delay and through the press animation.
Future<TestGesture> _hold(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await tester.pump(const Duration(milliseconds: 150)); // tap-down delay
  await tester.pump(const Duration(milliseconds: 100)); // press-in
  return gesture;
}

Color _face(WidgetTester tester) =>
    tester.widget<TactilePressable>(find.byType(TactilePressable)).faceColor;

typedef _Build = Widget Function(VoidCallback? onPressed);

void main() {
  final variants = <String, _Build>{
    'primary': (f) => AppButton.primary(label: 'Go', onPressed: f),
    'secondary': (f) => AppButton.secondary(label: 'Go', onPressed: f),
    'accent': (f) => AppButton.accent(label: 'Go', onPressed: f),
    'destructive': (f) => AppButton.destructive(label: 'Go', onPressed: f),
    'text': (f) => AppButton.text(label: 'Go', onPressed: f),
    'compact primary': (f) => AppButton.primary(
      label: 'Go',
      onPressed: f,
      expand: false,
      size: AppButtonSize.compact,
    ),
  };

  group('every variant', () {
    for (final MapEntry(key: name, value: build) in variants.entries) {
      testWidgets('$name should call onPressed when tapped', (tester) async {
        var taps = 0;
        await tester.pumpWidget(_host(build(() => taps++)));
        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });

      testWidgets('$name should ignore taps when disabled, and look it', (
        tester,
      ) async {
        await tester.pumpWidget(_host(build(null)));
        await tester.tap(find.text('Go'), warnIfMissed: false);
        await tester.pumpAndSettle();
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(of: find.text('Go'), matching: find.byType(Opacity))
              .last,
        );
        expect(opacity.opacity, 0.6);
      });

      testWidgets('$name should be at least 48×48 to tap', (tester) async {
        await tester.pumpWidget(_host(build(() {})));
        final size = tester.getSize(
          find.byWidgetPredicate((w) => w is AppButton),
        );
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      });

      testWidgets('$name should read as one enabled button with its label', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_host(build(() {})));
        expect(
          tester.getSemantics(find.byWidgetPredicate((w) => w is AppButton)),
          isSemantics(
            label: 'Go',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        semantics.dispose();
      });
    }
  });

  group('looks', () {
    testWidgets('should give each tactile variant its one face colour', (
      tester,
    ) async {
      final faces = {
        AppButton.primary(label: 'Go', onPressed: () {}):
            AppColors.primaryContainer,
        AppButton.secondary(label: 'Go', onPressed: () {}):
            AppColors.surfaceContainerLowest,
        AppButton.accent(label: 'Go', onPressed: () {}):
            AppColors.secondaryContainer,
        AppButton.destructive(label: 'Go', onPressed: () {}):
            AppColors.tertiaryBrand,
      };
      for (final MapEntry(key: button, value: face) in faces.entries) {
        await tester.pumpWidget(_host(button));
        expect(_face(tester), face, reason: button.variant.name);
      }
    });

    testWidgets('should give the text link no face at all', (tester) async {
      await tester.pumpWidget(
        _host(AppButton.text(label: 'Not now', onPressed: () {})),
      );
      expect(find.byType(TactilePressable), findsNothing);
      final text = tester.widget<Text>(find.text('Not now'));
      expect(text.style!.color, AppColors.onSurfaceVariant);
    });

    testWidgets('should line up variants: the same height with their shelves', (
      tester,
    ) async {
      final heights = <double>[];
      for (final build in [
        (VoidCallback f) => AppButton.primary(label: 'Go', onPressed: f),
        (VoidCallback f) => AppButton.secondary(label: 'Go', onPressed: f),
        (VoidCallback f) => AppButton.accent(label: 'Go', onPressed: f),
      ]) {
        await tester.pumpWidget(_host(build(() {})));
        heights.add(
          tester.getSize(find.byWidgetPredicate((w) => w is AppButton)).height,
        );
      }
      expect(heights.toSet(), hasLength(1));
      expect(heights.first, 56 + 4);
    });

    testWidgets('should show a badge at the right edge', (tester) async {
      await tester.pumpWidget(
        _host(
          AppButton.accent(
            label: 'Refill',
            onPressed: () {},
            badge: const AppButtonBadge(label: '350 Amole'),
          ),
        ),
      );
      expect(find.text('350 Amole'), findsOneWidget);
      expect(
        tester.getCenter(find.text('350 Amole')).dx,
        greaterThan(tester.getCenter(find.text('Refill')).dx),
      );
    });

    testWidgets('should hug its label when not expanded', (tester) async {
      await tester.pumpWidget(
        _host(AppButton.primary(label: 'Go', onPressed: () {}, expand: false)),
      );
      final width = tester
          .getSize(find.byWidgetPredicate((w) => w is AppButton))
          .width;
      expect(width, lessThan(320));
    });

    testWidgets('should fill the width when expanded', (tester) async {
      await tester.pumpWidget(
        _host(AppButton.primary(label: 'Go', onPressed: () {})),
      );
      expect(
        tester.getSize(find.byWidgetPredicate((w) => w is AppButton)).width,
        320,
      );
    });
  });

  group('loading', () {
    testWidgets('should show a spinner, keep its size and ignore taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppButton.primary(
            label: 'Continue',
            onPressed: () => taps++,
            expand: false,
          ),
        ),
      );
      final idleSize = tester.getSize(
        find.byWidgetPredicate((w) => w is AppButton),
      );

      await tester.pumpWidget(
        _host(
          AppButton.primary(
            label: 'Continue',
            onPressed: () => taps++,
            expand: false,
            loading: true,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byWidgetPredicate((w) => w is AppButton)),
        idleSize,
      );
      await tester.tap(
        find.byType(CircularProgressIndicator),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0);
    });

    testWidgets('should not dim a loading button like a disabled one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AppButton.primary(label: 'Go', onPressed: () {}, loading: true)),
      );
      final opacities = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.byType(TactilePressable),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity);
      expect(opacities, everyElement(1));
    });
  });

  group('pressing', () {
    testWidgets('should sink onto its shelf while held and spring back', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AppButton.primary(label: 'Go', onPressed: () {})),
      );
      expect(_sink(tester), 0);

      final gesture = await _hold(tester, find.text('Go'));
      expect(_sink(tester), closeTo(4, 0.01));

      await gesture.up();
      await tester.pump(); // the release starts on this frame
      await tester.pump(const Duration(milliseconds: 90));
      // Mid-release: on its way up.
      expect(_sink(tester), lessThan(4));
      await tester.pumpAndSettle();
      expect(_sink(tester), 0);
    });

    testWidgets('should spring slightly past rest on release', (tester) async {
      await tester.pumpWidget(
        _host(AppButton.primary(label: 'Go', onPressed: () {})),
      );
      final gesture = await _hold(tester, find.text('Go'));
      await gesture.up();
      await tester.pump();
      var lowest = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final sink = _sink(tester);
        if (sink < lowest) lowest = sink;
      }
      expect(lowest, lessThan(0));
    });

    testWidgets('should keep its size, so nothing around it moves', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AppButton.primary(label: 'Go', onPressed: () {})),
      );
      final before = tester.getRect(
        find.byWidgetPredicate((w) => w is AppButton),
      );
      final gesture = await _hold(tester, find.text('Go'));
      expect(
        tester.getRect(find.byWidgetPredicate((w) => w is AppButton)),
        before,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('should cancel the press when the finger slides away', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton.primary(label: 'Go', onPressed: () => taps++)),
      );
      final gesture = await _hold(tester, find.text('Go'));
      await gesture.moveBy(const Offset(0, 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(_sink(tester), 0);
    });

    testWidgets('should only darken, not move, when motion is reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppButton.primary(label: 'Go', onPressed: () {}),
          reduceMotion: true,
        ),
      );
      final restFace =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(TactilePressable),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      final gesture = await _hold(tester, find.text('Go'));
      expect(_sink(tester), 0);
      final pressedFace =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(TactilePressable),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(pressedFace.color, isNot(restFace.color));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('should not press at all when disabled', (tester) async {
      await tester.pumpWidget(
        _host(const AppButton.primary(label: 'Go', onPressed: null)),
      );
      final gesture = await _hold(tester, find.text('Go'));
      expect(_sink(tester), 0);
      await gesture.up();
    });
  });

  group('AppIconButton', () {
    testWidgets('should be a 48×48 target around a 40px face', (tester) async {
      await tester.pumpWidget(
        _host(
          AppIconButton(icon: Icons.close, tooltip: 'Close', onPressed: () {}),
        ),
      );
      expect(tester.getSize(find.byType(AppIconButton)), const Size(48, 48));
      expect(tester.getSize(find.byType(TactilePressable)), const Size(40, 40));
    });

    testWidgets('should read as a button named by its tooltip', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          AppIconButton(icon: Icons.close, tooltip: 'Close', onPressed: () {}),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppIconButton)),
        isSemantics(
          label: 'Close',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('should call onPressed from anywhere in its tap target', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppIconButton(
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('should ignore taps when disabled', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppIconButton(
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: null,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(AppIconButton)),
        isSemantics(label: 'Close', hasEnabledState: true, isEnabled: false),
      );
    });

    testWidgets('should have no surface when plain', (tester) async {
      await tester.pumpWidget(
        _host(
          AppIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: () {},
            plain: true,
          ),
        ),
      );
      expect(_face(tester).a, 0);
    });
  });

  group('TactileButton (legacy)', () {
    testWidgets('should keep its 56px face on a 4px shelf', (tester) async {
      await tester.pumpWidget(
        _host(TactileButton(label: 'Continue', onPressed: () {})),
      );
      expect(tester.getSize(find.byType(TactileButton)).height, 60);
    });

    testWidgets('should press like AppButton', (tester) async {
      await tester.pumpWidget(
        _host(TactileButton(label: 'Continue', onPressed: () {})),
      );
      final gesture = await _hold(tester, find.text('Continue'));
      expect(_sink(tester), closeTo(4, 0.01));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_sink(tester), 0);
    });

    testWidgets('should still take the colours a screen passes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TactileButton(
            label: 'Continue',
            onPressed: () {},
            backgroundColor: AppColors.tertiaryBrand,
            bevelColor: AppColors.tertiaryBevel,
          ),
        ),
      );
      expect(_face(tester), AppColors.tertiaryBrand);
    });
  });
}
