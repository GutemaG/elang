// Text stays readable in both palettes (022-light-and-dark-themes, bolt
// 068, story 004, FR-7), and the 3D look survives in dark: every shelf is
// darker than the face above it (story 003, FR-4).
//
// Editing a colour in `app_palette.dart` can't quietly break either: a
// failing pair names the palette, both roles and the ratio.

import 'dart:math' as math;

import 'package:elang/shared/theme/app_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2 contrast ratio, 1 to 21.
double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

typedef _Role = (String, Color Function(AppPalette));

_Role _r(String name, Color Function(AppPalette) read) => (name, read);

final _surface = _r('surface', (p) => p.surface);
final _card = _r('surfaceContainerLowest', (p) => p.surfaceContainerLowest);
final _low = _r('surfaceContainerLow', (p) => p.surfaceContainerLow);
final _container = _r('surfaceContainer', (p) => p.surfaceContainer);
final _high = _r('surfaceContainerHigh', (p) => p.surfaceContainerHigh);

/// Body text: at least 4.5:1.
final _body = <(_Role, _Role)>[
  // Text and muted text on the page, cards and containers.
  for (final bg in [_surface, _card, _low, _container, _high])
    (_r('onSurface', (p) => p.onSurface), bg),
  for (final bg in [_surface, _card, _container])
    (_r('onSurfaceVariant', (p) => p.onSurfaceVariant), bg),
  for (final bg in [_surface, _card]) ...[
    (_r('textMuted', (p) => p.textMuted), bg),
    (_r('primary', (p) => p.primary), bg),
    (_r('secondary', (p) => p.secondary), bg),
    (_r('tertiary', (p) => p.tertiary), bg),
    (_r('error', (p) => p.error), bg),
    (_r('primaryAccent', (p) => p.primaryAccent), bg),
    (_r('tertiaryAccent', (p) => p.tertiaryAccent), bg),
  ],
  // Each tone's ink on its surface and on a card.
  (
    _r('primary', (p) => p.primary),
    _r('primaryToneSurface', (p) => p.primaryToneSurface),
  ),
  (_r('secondary', (p) => p.secondary), _container),
  (
    _r('tertiaryToneInk', (p) => p.tertiaryToneInk),
    _r('tertiaryToneSurface', (p) => p.tertiaryToneSurface),
  ),
  (_r('tertiaryToneInk', (p) => p.tertiaryToneInk), _card),
  // Text on each fill: buttons, filled badges and banners.
  (
    _r('onPrimary', (p) => p.onPrimary),
    _r('primaryContainer', (p) => p.primaryContainer),
  ),
  (
    _r('onSecondaryContainer', (p) => p.onSecondaryContainer),
    _r('secondaryContainer', (p) => p.secondaryContainer),
  ),
  (
    _r('onTertiary', (p) => p.onTertiary),
    _r('tertiaryContainer', (p) => p.tertiaryContainer),
  ),
  (
    _r('onTertiary', (p) => p.onTertiary),
    _r('tertiaryBrand', (p) => p.tertiaryBrand),
  ),
  (
    _r('inverseOnSurface', (p) => p.inverseOnSurface),
    _r('inverseSurface', (p) => p.inverseSurface),
  ),
  (
    _r('inverseAction', (p) => p.inverseAction),
    _r('inverseSurface', (p) => p.inverseSurface),
  ),
  // A path popover's white button, labelled in its popover's fill.
  (
    _r('secondaryOnWhite', (p) => p.secondaryOnWhite),
    _r('onPrimary', (p) => p.onPrimary),
  ),
  (
    _r('primaryContainer', (p) => p.primaryContainer),
    _r('onPrimary', (p) => p.onPrimary),
  ),
  // Answers and choices.
  (
    _r('onSurface', (p) => p.onSurface),
    _r('answerSelectedFace', (p) => p.answerSelectedFace),
  ),
  (
    _r('primaryAccent', (p) => p.primaryAccent),
    _r('answerCorrectFace', (p) => p.answerCorrectFace),
  ),
  (
    _r('tertiaryAccent', (p) => p.tertiaryAccent),
    _r('answerIncorrectFace', (p) => p.answerIncorrectFace),
  ),
  (_r('onSurface', (p) => p.onSurface), _r('chosenFace', (p) => p.chosenFace)),
  (
    _r('primaryAccent', (p) => p.primaryAccent),
    _r('chosenFace', (p) => p.chosenFace),
  ),
];

/// Large text and icons: at least 3:1.
final _large = <(_Role, _Role)>[
  (
    _r('primaryAccent', (p) => p.primaryAccent),
    _r('primaryToneSurface', (p) => p.primaryToneSurface),
  ),
  (_r('secondaryContainer', (p) => p.secondaryContainer), _container),
  (
    _r('tertiaryToneInk', (p) => p.tertiaryToneInk),
    _r('tertiaryToneSurface', (p) => p.tertiaryToneSurface),
  ),
  (_r('onSurfaceVariant', (p) => p.onSurfaceVariant), _container),
  (
    _r('onPrimary', (p) => p.onPrimary),
    _r('primaryContainer', (p) => p.primaryContainer),
  ),
  (
    _r('onSecondary', (p) => p.onSecondary),
    _r('secondaryContainer', (p) => p.secondaryContainer),
  ),
  (_r('primaryAccent', (p) => p.primaryAccent), _surface),
];

/// Pairs the light palette falls short on as designed. Light keeps its
/// colours (the intent's D5), so these are reported, not fixed here; dark
/// must still pass them.
const _lightShortfalls = {
  // The wrong-answer red and the red button, as DESIGN.md draws them.
  'tertiaryAccent on surface',
  'tertiaryAccent on surfaceContainerLowest',
  'tertiaryAccent on answerIncorrectFace',
  'onTertiary on tertiaryBrand',
  // The gold tone's icon on cream, and the white icon on the active node.
  'secondaryContainer on surfaceContainer',
  'onSecondary on secondaryContainer',
};

/// Shelves: each is darker than the face it sits under.
final _shelves = <(_Role, _Role)>[
  (
    _r('primaryShelf', (p) => p.primaryShelf),
    _r('primaryContainer', (p) => p.primaryContainer),
  ),
  (
    _r('activeNodeShelf', (p) => p.activeNodeShelf),
    _r('secondaryContainer', (p) => p.secondaryContainer),
  ),
  (
    _r('secondaryShelf', (p) => p.secondaryShelf),
    _r('secondaryContainer', (p) => p.secondaryContainer),
  ),
  (
    _r('secondaryButtonEdge', (p) => p.secondaryButtonEdge),
    _r('secondaryContainer', (p) => p.secondaryContainer),
  ),
  (
    _r('tertiaryShelf', (p) => p.tertiaryShelf),
    _r('tertiaryBrand', (p) => p.tertiaryBrand),
  ),
  (
    _r('tertiaryFillShelf', (p) => p.tertiaryFillShelf),
    _r('tertiaryContainer', (p) => p.tertiaryContainer),
  ),
  (
    _r('lockedNodeIcon', (p) => p.lockedNodeIcon),
    _r('surfaceDim', (p) => p.surfaceDim),
  ),
];

/// Neutral shelves: darker than their face *and* the page, since soft
/// shadows barely show on a dark page.
final _neutralShelves = <(_Role, _Role)>[
  (_r('cardShelf', (p) => p.cardShelf), _card),
  (_r('tileShelf', (p) => p.tileShelf), _card),
  (_r('dialogShelf', (p) => p.dialogShelf), _card),
  (_r('primaryToneShelf', (p) => p.primaryToneShelf), _card),
  (_r('secondaryToneShelf', (p) => p.secondaryToneShelf), _card),
  (_r('tertiaryToneShelf', (p) => p.tertiaryToneShelf), _card),
];

void main() {
  // Every preset in `palette_seed.dart`, so switching to one is safe.
  final palettes = {
    for (final seed in PaletteSeed.presets) ...{
      '${seed.name}, light': AppPalette.lightFrom(seed),
      '${seed.name}, dark': AppPalette.darkFrom(seed),
    },
  };

  test('the palette the app draws is one of the checked presets', () {
    expect(PaletteSeed.presets, contains(PaletteSeed.active));
  });

  test('the contrast ratio follows WCAG', () {
    expect(
      _contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(
      _contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
      closeTo(4.48, 0.01),
    );
  });

  for (final MapEntry(key: name, value: p) in palettes.entries) {
    group('$name palette', () {
      test('text is readable on its background', () {
        final failures = <String>[];
        void check(List<(_Role, _Role)> pairs, double needs) {
          for (final ((fgName, fg), (bgName, bg)) in pairs) {
            final label = '$fgName on $bgName';
            if (name.endsWith('light') && _lightShortfalls.contains(label)) {
              continue;
            }
            final ratio = _contrast(fg(p), bg(p));
            if (ratio < needs) {
              failures.add(
                '$name: $label is ${ratio.toStringAsFixed(2)}:1, '
                'needs $needs:1',
              );
            }
          }
        }

        check(_body, 4.5);
        check(_large, 3);
        expect(failures, isEmpty, reason: failures.join('\n'));
      });

      test('every shelf is darker than its face', () {
        final failures = <String>[
          for (final ((shelfName, shelf), (faceName, face)) in [
            ..._shelves,
            ..._neutralShelves,
          ])
            if (_luminance(shelf(p)) >= _luminance(face(p)))
              '$name: $shelfName is not darker than $faceName',
        ];
        expect(failures, isEmpty, reason: failures.join('\n'));
      });

      if (name.endsWith('dark')) {
        test('neutral shelves are darker than the page', () {
          final failures = <String>[
            for (final ((shelfName, shelf), _) in _neutralShelves)
              if (_luminance(shelf(p)) >= _luminance(p.surface))
                '$name: $shelfName is not darker than surface',
          ];
          expect(failures, isEmpty, reason: failures.join('\n'));
        });
      }
    });
  }

  test('the light shortfalls are all still listed pairs', () {
    final labels = {
      for (final ((fg, _), (bg, _)) in [..._body, ..._large]) '$fg on $bg',
    };
    expect(labels.containsAll(_lightShortfalls), isTrue);
  });
}
