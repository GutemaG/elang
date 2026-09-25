// PictureTile and PictureGrid: the picture answer and its grid
// (019-image-choice-exercise-types, bolt 053, story 001).

import 'dart:ui' as ui;

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/exercise/picture_tile.dart';
import 'package:elang/shared/widgets/tactile_pressable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// --- pictures, faked ---------------------------------------------------------

late ui.Image _bitmap;

/// A picture that is there at once, so a test sees it drawn.
class _Loaded extends ImageProvider<_Loaded> {
  const _Loaded();

  @override
  Future<_Loaded> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Loaded key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: _bitmap.clone())),
      );
}

/// A picture that never arrives.
class _Pending extends ImageProvider<_Pending> {
  const _Pending();

  @override
  Future<_Pending> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Pending key, ImageDecoderCallback decode) =>
      _NeverCompletes();
}

class _NeverCompletes extends ImageStreamCompleter {}

/// A picture whose address fails, as a missing file or no network does.
class _Broken extends ImageProvider<_Broken> {
  const _Broken();

  @override
  Future<_Broken> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Broken key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(StateError('no such picture')),
      );
}

// --- hosts and finders -------------------------------------------------------

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
        body: SingleChildScrollView(
          child: Center(
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
  ),
);

/// A tile in a column [width] wide, as the lesson's grid gives one.
Widget _tile(
  PictureTile tile, {
  double width = 150,
  double scale = 1,
  bool reduceMotion = false,
}) => _host(
  Center(
    child: SizedBox(width: width, child: tile),
  ),
  scale: scale,
  reduceMotion: reduceMotion,
);

BoxDecoration _face(WidgetTester tester, Finder of) {
  final pressable = find.descendant(
    of: of,
    matching: find.byType(TactilePressable),
  );
  final container = tester.widget<Container>(
    find.descendant(of: pressable, matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

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

/// The opacity the picture is drawn at: 1 when nothing fades it.
double _pictureOpacity(WidgetTester tester) {
  final fades = find.ancestor(
    of: find.byType(Image),
    matching: find.byType(Opacity),
  );
  var opacity = 1.0;
  for (final o in tester.widgetList<Opacity>(fades)) {
    opacity *= o.opacity;
  }
  return opacity;
}

/// The drawn colour of the description a failed picture shows.
Color? _fallbackTextColour(WidgetTester tester, String altText) => tester
    .widget<RichText>(
      find.descendant(of: find.text(altText), matching: find.byType(RichText)),
    )
    .text
    .style
    ?.color;

/// Grades itself wrong on the first tap, as a lesson's picture does.
class _GradesOnTap extends StatefulWidget {
  const _GradesOnTap();

  @override
  State<_GradesOnTap> createState() => _GradesOnTapState();
}

class _GradesOnTapState extends State<_GradesOnTap> {
  AnswerTileState _state = AnswerTileState.idle;

  @override
  Widget build(BuildContext context) => PictureTile(
    image: const _Loaded(),
    altText: 'A cat',
    state: _state,
    onTap: _state == AnswerTileState.idle
        ? () => setState(() => _state = AnswerTileState.incorrect)
        : null,
  );
}

void main() {
  setUpAll(() async {
    _bitmap = await createTestImage(width: 40, height: 20);
  });

  tearDown(() => imageCache.clear());

  group('the same states as every answer (DESIGN.md component 4)', () {
    for (final state in AnswerTileState.values) {
      testWidgets('${state.name}: face, border, rim and radius match a text '
          'tile\'s', (tester) async {
        await tester.pumpWidget(
          _host(
            Column(
              children: [
                AnswerTile(
                  key: const Key('text'),
                  label: 'Coffee',
                  state: state,
                  onTap: () {},
                ),
                SizedBox(
                  width: 150,
                  child: PictureTile(
                    key: const Key('picture'),
                    image: const _Loaded(),
                    altText: 'Coffee',
                    state: state,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final text = _face(tester, find.byKey(const Key('text')));
        final picture = _face(tester, find.byKey(const Key('picture')));
        expect(picture.color, text.color);
        expect(picture.border, text.border);
        expect(picture.boxShadow, text.boxShadow);
        expect(picture.borderRadius, text.borderRadius);
      });
    }

    testWidgets('a failed picture\'s text takes the state\'s text colour', (
      tester,
    ) async {
      for (final (state, colour) in [
        (AnswerTileState.idle, AppColors.onSurface),
        (AnswerTileState.selected, AppColors.onSurface),
        (AnswerTileState.correct, AppColors.primaryContainer),
        (AnswerTileState.incorrect, AppColors.tertiaryBrand),
      ]) {
        await tester.pumpWidget(
          _tile(
            PictureTile(
              image: const _Broken(),
              altText: 'A cup of coffee',
              state: state,
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          _fallbackTextColour(tester, 'A cup of coffee'),
          colour,
          reason: state.name,
        );
      }
    });

    testWidgets('correct shows a check and incorrect a cross, in the top '
        'end corner; idle and selected show neither', (tester) async {
      Future<Rect?> iconOf(AnswerTileState state) async {
        await tester.pumpWidget(
          _tile(
            PictureTile(image: const _Loaded(), altText: 'A', state: state),
          ),
        );
        await tester.pumpAndSettle();
        final icon = find.descendant(
          of: find.byType(AnswerTile),
          matching: find.byType(Icon),
        );
        return icon.evaluate().isEmpty ? null : tester.getRect(icon);
      }

      expect(await iconOf(AnswerTileState.idle), isNull);
      expect(await iconOf(AnswerTileState.selected), isNull);

      final check = await iconOf(AnswerTileState.correct);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_circle)).color,
        AppColors.primaryContainer,
      );
      final tile = tester.getRect(find.byType(AnswerTile));
      // Inside the border and the inset, at the top end.
      expect(check!.top - tile.top, lessThan(AnswerTile.pictureInset * 2));
      expect(tile.right - check.right, lessThan(AnswerTile.pictureInset * 2));

      await iconOf(AnswerTileState.incorrect);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.cancel)).color,
        AppColors.tertiaryBrand,
      );
    });

    testWidgets('in a right-to-left language the grade sits top left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 150,
                child: PictureTile(
                  image: const _Loaded(),
                  altText: 'A',
                  state: AnswerTileState.correct,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tile = tester.getRect(find.byType(AnswerTile));
      final check = tester.getRect(find.byIcon(Icons.check_circle));
      expect(check.left - tile.left, lessThan(AnswerTile.pictureInset * 2));
    });

    testWidgets('used dims the whole tile', (tester) async {
      await tester.pumpWidget(
        _tile(
          const PictureTile(
            image: _Loaded(),
            altText: 'A',
            state: AnswerTileState.used,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_pictureOpacity(tester), closeTo(0.35, 1e-9));
    });

    testWidgets('disabled fades the picture, as a row fades its text, and '
        'ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _tile(
          PictureTile(
            image: const _Loaded(),
            altText: 'A',
            state: AnswerTileState.disabled,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PictureTile), warnIfMissed: false);
      expect(taps, 0);
      expect(_pictureOpacity(tester), closeTo(0.6, 1e-9));
    });

    testWidgets('once graded, the other pictures fade and the graded one '
        'keeps its full colour', (tester) async {
      await tester.pumpWidget(
        _tile(const PictureTile(image: _Loaded(), altText: 'A')),
      );
      await tester.pumpAndSettle();
      expect(_pictureOpacity(tester), closeTo(0.6, 1e-9));

      await tester.pumpWidget(
        _tile(
          const PictureTile(
            image: _Loaded(),
            altText: 'A',
            state: AnswerTileState.correct,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_pictureOpacity(tester), 1);
    });

    testWidgets('a tappable idle picture is not faded', (tester) async {
      await tester.pumpWidget(
        _tile(PictureTile(image: const _Loaded(), altText: 'A', onTap: () {})),
      );
      await tester.pumpAndSettle();
      expect(_pictureOpacity(tester), 1);
    });
  });

  group('press and tap', () {
    testWidgets('a tap calls onTap once, and the tile presses like every '
        'tactile element', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _tile(
          PictureTile(
            image: const _Loaded(),
            altText: 'A',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rest = tester.getRect(find.byType(Image));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PictureTile)),
      );
      await tester.pump();
      await tester.pump(AppMotion.pressIn);
      expect(_face(tester, find.byType(PictureTile)).boxShadow, hasLength(1));
      expect(
        tester.getRect(find.byType(Image)).top,
        greaterThan(rest.top + AppShadows.tileShelfDepth / 2),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.getRect(find.byType(Image)), rest);
    });

    for (final state in [
      AnswerTileState.idle,
      AnswerTileState.correct,
      AnswerTileState.incorrect,
    ]) {
      testWidgets('${state.name} with onTap null does not press', (
        tester,
      ) async {
        await tester.pumpWidget(
          _tile(
            PictureTile(image: const _Loaded(), altText: 'A', state: state),
          ),
        );
        expect(
          tester
              .widget<TactilePressable>(find.byType(TactilePressable))
              .onPressed,
          isNull,
        );
      });
    }

    testWidgets('used takes no tap even with onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _tile(
          PictureTile(
            image: const _Loaded(),
            altText: 'A',
            state: AnswerTileState.used,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(PictureTile), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('shake', () {
    testWidgets('a picture graded wrong shakes once, without moving the '
        'layout', (tester) async {
      await tester.pumpWidget(
        _host(const Center(child: SizedBox(width: 150, child: _GradesOnTap()))),
      );
      await tester.pumpAndSettle();
      final layout = tester.getRect(find.byType(AnswerTile));
      await tester.tap(find.byType(AnswerTile));
      await tester.pump();

      var moved = 0.0;
      for (var t = 0; t < 8; t++) {
        await tester.pump(AppMotion.shake ~/ 10);
        final now = _shakeOffset(tester).abs();
        if (now > moved) moved = now;
        expect(tester.getRect(find.byType(AnswerTile)), layout);
      }
      expect(moved, greaterThan(2));
      expect(moved, lessThanOrEqualTo(AnswerTile.shakeDistance));
      await tester.pumpAndSettle();
      expect(_shakeOffset(tester), 0);
    });

    testWidgets('no shake with reduced motion; the colour still changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Center(child: SizedBox(width: 150, child: _GradesOnTap())),
          reduceMotion: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AnswerTile));
      for (var t = 0; t < 6; t++) {
        await tester.pump(AppMotion.shake ~/ 10);
        expect(_shakeOffset(tester), 0);
      }
      await tester.pumpAndSettle();
      expect(
        _face(tester, find.byType(AnswerTile)).color,
        AppColors.answerIncorrect,
      );
    });
  });

  group('screen readers', () {
    testWidgets('one button read as its description, selected once chosen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final (state, selected) in [
        (AnswerTileState.idle, false),
        (AnswerTileState.selected, true),
        (AnswerTileState.correct, true),
        (AnswerTileState.incorrect, true),
      ]) {
        await tester.pumpWidget(
          _tile(
            PictureTile(
              image: const _Loaded(),
              altText: 'A dog',
              state: state,
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byType(AnswerTile)),
          isSemantics(
            label: 'A dog',
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

    testWidgets('the picture, its fallback text and the grade are not read '
        'twice', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _tile(
          const PictureTile(
            image: _Broken(),
            altText: 'A dog',
            state: AnswerTileState.correct,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('A dog'), findsOneWidget);
      var children = 0;
      tester.getSemantics(find.byType(AnswerTile)).visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      handle.dispose();
    });

    testWidgets('a screen-reader tap chooses the picture', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _tile(
          PictureTile(
            image: const _Loaded(),
            altText: 'A dog',
            onTap: () => taps++,
          ),
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('A dog'));
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('the picture', () {
    testWidgets('the face is square, with the picture inset 8 px inside the '
        'border', (tester) async {
      await tester.pumpWidget(
        _tile(PictureTile(image: const _Loaded(), altText: 'A', onTap: () {})),
      );
      await tester.pumpAndSettle();
      final tile = tester.getRect(find.byType(AnswerTile));
      expect(tile.width, 150);
      expect(tile.height, 150 + AppShadows.tileShelfDepth);

      final picture = tester.getRect(find.byType(Image));
      const inset = AnswerTile.borderWidth + AnswerTile.pictureInset;
      expect(picture.left - tile.left, inset);
      expect(picture.top - tile.top, inset);
      expect(picture.width, 150 - inset * 2);
      expect(picture.height, 150 - inset * 2);
    });

    testWidgets('it is fitted, never cropped, and decoded at the tile\'s '
        'size in device pixels', (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _tile(PictureTile(image: const _Loaded(), altText: 'A', onTap: () {})),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect(image.excludeFromSemantics, isTrue);
      final resized = image.image as ResizeImage;
      const side = 150 - (AnswerTile.borderWidth + AnswerTile.pictureInset) * 2;
      expect(resized.width, side * 3);
      expect(resized.height, side * 3);
      expect(resized.policy, ResizeImagePolicy.fit);
      expect(resized.allowUpscaling, isFalse);
      expect(resized.imageProvider, const _Loaded());
    });

    testWidgets('while loading, a quiet placeholder shows', (tester) async {
      await tester.pumpWidget(
        _tile(PictureTile(image: const _Pending(), altText: 'A', onTap: () {})),
      );
      await tester.pump();
      expect(find.byKey(PictureTile.loadingKey), findsOneWidget);
      expect(find.byKey(PictureTile.failedKey), findsNothing);
      expect(
        tester.widget<ColoredBox>(find.byKey(PictureTile.loadingKey)).color,
        AppColors.surfaceContainerLow,
      );
    });

    testWidgets('once loaded, the placeholder is gone', (tester) async {
      await tester.pumpWidget(
        _tile(PictureTile(image: const _Loaded(), altText: 'A', onTap: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(PictureTile.loadingKey), findsNothing);
      expect(find.byKey(PictureTile.failedKey), findsNothing);
      expect(find.byType(RawImage), findsOneWidget);
    });

    testWidgets('a picture that fails shows its description, and can still '
        'be chosen', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _tile(
          PictureTile(
            image: const _Broken(),
            altText: 'A cup of coffee',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(PictureTile.failedKey), findsOneWidget);
      expect(find.text('A cup of coffee'), findsOneWidget);

      await tester.tap(find.byType(PictureTile));
      expect(taps, 1);
    });

    testWidgets('a picture tile must have a picture, and only a picture tile '
        'takes one', (tester) async {
      expect(
        () => AnswerTile(label: 'A', shape: AnswerTileShape.picture),
        throwsAssertionError,
      );
      expect(
        () => AnswerTile(label: 'A', picture: const SizedBox()),
        throwsAssertionError,
      );
    });
  });

  group('the grid', () {
    Widget grid(int count, {double width = 320, double scale = 1}) => _host(
      width: width,
      scale: scale,
      PictureGrid(
        children: [
          for (var i = 0; i < count; i++)
            PictureTile(
              key: Key('p$i'),
              image: const _Loaded(),
              altText: 'Picture $i',
              onTap: () {},
            ),
        ],
      ),
    );

    Rect rectOf(WidgetTester tester, int i) =>
        tester.getRect(find.byKey(Key('p$i')));

    for (final count in [2, 3, 4]) {
      testWidgets('$count pictures: two to a row, all one square size, '
          '12 px apart', (tester) async {
        await tester.pumpWidget(grid(count));
        await tester.pumpAndSettle();

        const side = (320 - PictureGrid.gap) / 2;
        for (var i = 0; i < count; i++) {
          final r = rectOf(tester, i);
          expect(r.width, side, reason: '$i');
          expect(r.height, side + AppShadows.tileShelfDepth, reason: '$i');
        }
        // Side by side, 12 px apart.
        expect(rectOf(tester, 1).left - rectOf(tester, 0).right, 12);
        expect(rectOf(tester, 1).top, rectOf(tester, 0).top);
        if (count > 2) {
          // The next row starts 12 px below the first.
          expect(rectOf(tester, 2).top - rectOf(tester, 0).bottom, 12);
        }
        if (count == 4) {
          expect(rectOf(tester, 2).left, rectOf(tester, 0).left);
          expect(rectOf(tester, 3).left, rectOf(tester, 1).left);
        }
      });
    }

    testWidgets('three pictures sit two then one, the last centred', (
      tester,
    ) async {
      await tester.pumpWidget(grid(3));
      await tester.pumpAndSettle();
      final grid3 = tester.getRect(find.byType(PictureGrid));
      expect(rectOf(tester, 2).center.dx, closeTo(grid3.center.dx, 0.01));
      expect(rectOf(tester, 2).top, greaterThan(rectOf(tester, 0).bottom));
    });

    testWidgets('on a wide screen it stops at 400 px, centred', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(grid(4, width: 900));
      await tester.pumpAndSettle();

      final left = rectOf(tester, 0).left;
      final right = rectOf(tester, 1).right;
      // The 400 px of the plan, not the constant: that would check itself.
      expect(right - left, 400);
      final host = tester.getRect(find.byType(PictureGrid));
      expect((left + right) / 2, closeTo(host.center.dx, 0.01));
    });

    testWidgets('tileWidthFor gives the width the grid really lays a tile '
        'out at, narrow and wide', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final width in [300.0, 412.0, 900.0]) {
        await tester.pumpWidget(grid(2, width: width));
        await tester.pumpAndSettle();
        expect(
          PictureGrid.tileWidthFor(width),
          rectOf(tester, 0).width,
          reason: '$width',
        );
      }
      // Capped: past 400 px the tiles stop growing.
      expect(PictureGrid.tileWidthFor(900), (400 - 12) / 2);
    });

    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('at ${width}px and ${scale}x: every tile is over the '
            '48 px tap target and no text overflows', (tester) async {
          // The longest description the admin allows, in Fidel, on a
          // picture that failed: the most text a tile can hold.
          final long = 'ቡና ' * 50;
          await tester.pumpWidget(
            _host(
              width: width,
              scale: scale,
              PictureGrid(
                children: [
                  for (var i = 0; i < 3; i++)
                    PictureTile(
                      key: Key('p$i'),
                      image: const _Broken(),
                      altText: long,
                      onTap: () {},
                    ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 3; i++) {
            final size = tester.getSize(find.byKey(Key('p$i')));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
          expect(find.byKey(PictureTile.failedKey), findsNWidgets(3));
        });
      }
    }

    testWidgets('fewer than 2 or more than 4 pictures is a mistake', (
      tester,
    ) async {
      for (final count in [1, 5]) {
        await tester.pumpWidget(grid(count));
        expect(tester.takeException(), isAssertionError, reason: '$count');
      }
    });
  });

  test('the grid gap and inset come from the spacing tokens', () {
    expect(PictureGrid.gap, AppSpacing.spaceSm);
    expect(AnswerTile.pictureInset, AppSpacing.spaceXs);
  });
}
