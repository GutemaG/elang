// AudioPlayButton: the one play button (018-mobile-design-system, unit 002
// story 003).

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/exercise/audio_play_button.dart';
import 'package:elang/shared/widgets/tactile_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

BoxDecoration _face(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(TactilePressable),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}

Finder _bars() => find.byKey(const ValueKey('audio-play-button-bars'));

List<double> _heights(WidgetTester tester) =>
    (tester.widget<CustomPaint>(_bars()).painter! as SoundBarsPainter)
        .heights();

double _ringScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('audio-play-button-ring')))
    .transform
    .getMaxScaleOnAxis();

void main() {
  testWidgets('a large round green face on a green shelf, as today\'s 88 px '
      'listening button', (tester) async {
    await tester.pumpWidget(_host(AudioPlayButton(onPressed: () {})));

    final face = _face(tester);
    expect(face.color, AppColors.primaryContainer);
    expect(face.borderRadius, BorderRadius.circular(AppRadii.full));
    expect(face.boxShadow, AppShadows.button(AppColors.primaryBevel));
    final faceSize = tester.getSize(
      find
          .descendant(
            of: find.byType(TactilePressable),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(faceSize, const Size.square(AudioPlayButton.largeFace));
    expect(
      tester.getSize(find.byType(AudioPlayButton)).height,
      AudioPlayButton.largeFace + AppShadows.shelfDepth,
    );
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.volume_up)).color,
      AppColors.onPrimary,
    );
  });

  testWidgets('a tap calls onPressed once and the face sinks while held', (
    tester,
  ) async {
    var plays = 0;
    await tester.pumpWidget(_host(AudioPlayButton(onPressed: () => plays++)));
    final rest = tester.getRect(find.byIcon(Icons.volume_up));

    final gesture = await tester.startGesture(rest.center);
    await tester.pump();
    await tester.pump(AppMotion.pressIn);
    expect(
      tester.getRect(find.byIcon(Icons.volume_up)).top,
      closeTo(rest.top + AppShadows.shelfDepth, 0.5),
    );
    expect(_face(tester).boxShadow, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(plays, 1);
    expect(tester.getRect(find.byIcon(Icons.volume_up)), rest);
  });

  testWidgets('playing swaps to sound bars and adds a halo', (tester) async {
    await tester.pumpWidget(
      _host(AudioPlayButton(playing: true, onPressed: () {})),
    );
    expect(_bars(), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsNothing);
    expect(
      _face(tester).boxShadow!.first,
      AppShadows.halo(AppColors.primaryToneBorder).single,
    );
  });

  testWidgets('while playing the bars and the ring move (bolt 058)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(AudioPlayButton(playing: true, onPressed: () {})),
    );
    final bars = _heights(tester);
    final ring = _ringScale(tester);

    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.hasRunningAnimations, isTrue);
    expect(_heights(tester), isNot(bars));
    expect(_ringScale(tester), isNot(ring));
  });

  testWidgets('at rest nothing runs, and stopping playing stops the motion', (
    tester,
  ) async {
    var playing = true;
    late StateSetter setPlaying;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            setPlaying = setState;
            return AudioPlayButton(playing: playing, onPressed: () {});
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);

    setPlaying(() => playing = false);
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-play-button-ring')), findsNothing);
  });

  testWidgets('with reduced motion, playing stays still', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: AudioPlayButton(playing: true, onPressed: () {}),
            ),
          ),
        ),
      ),
    );
    final bars = _heights(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(_heights(tester), bars);
    expect(find.byKey(const ValueKey('audio-play-button-ring')), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('the bars loop without a jump', () {
    List<double> at(double phase) =>
        SoundBarsPainter(phase: phase, color: AppColors.onPrimary).heights();
    for (var i = 0; i < 4; i++) {
      expect(at(1)[i], closeTo(at(0)[i], 1e-9));
    }
  });

  testWidgets('small is a 44 px face with its shelf and a 48 px tap '
      'target', (tester) async {
    var plays = 0;
    await tester.pumpWidget(
      _host(
        AudioPlayButton(
          size: AudioPlayButtonSize.small,
          onPressed: () => plays++,
        ),
      ),
    );
    final size = tester.getSize(find.byType(AudioPlayButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, AudioPlayButton.smallFace + AppShadows.shelfDepth);
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(AudioPlayButton));
    expect(plays, 1);
  });

  testWidgets('disabled: faded and taps do nothing', (tester) async {
    await tester.pumpWidget(_host(const AudioPlayButton(onPressed: null)));
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(AudioPlayButton),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 0.6);
    expect(
      tester.widget<TactilePressable>(find.byType(TactilePressable)).onPressed,
      isNull,
    );
  });

  testWidgets('a screen reader hears one button, "Play audio", or '
      '"Playing audio" while playing, and can press it', (tester) async {
    final handle = tester.ensureSemantics();
    var plays = 0;
    await tester.pumpWidget(_host(AudioPlayButton(onPressed: () => plays++)));
    expect(
      tester.getSemantics(find.byType(AudioPlayButton)),
      isSemantics(
        label: 'Play audio',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Play audio'));
    expect(plays, 1);

    await tester.pumpWidget(
      _host(AudioPlayButton(playing: true, onPressed: () {})),
    );
    expect(find.bySemanticsLabel('Playing audio'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a custom label replaces "Play audio"', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(AudioPlayButton(semanticLabel: 'Play the word', onPressed: () {})),
    );
    expect(find.bySemanticsLabel('Play the word'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('it sits with the page margins like any other block', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: AudioPlayButton(onPressed: () {}),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
