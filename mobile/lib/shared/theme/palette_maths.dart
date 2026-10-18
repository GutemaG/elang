/// The colour arithmetic `app_palette.dart` builds every role with: mixing,
/// WCAG contrast, and deepening a colour until text on it reads.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

abstract final class PaletteMaths {
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static List<int> _rgb(Color c) {
    final v = c.toARGB32();
    return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
  }

  /// [a] moved [t] of the way to [b] (0 is [a], 1 is [b]), opaque.
  static Color mix(Color a, Color b, double t) {
    final x = _rgb(a), y = _rgb(b);
    int channel(int i) => (x[i] + (y[i] - x[i]) * t).round().clamp(0, 255);
    return Color.fromARGB(255, channel(0), channel(1), channel(2));
  }

  /// WCAG 2 relative luminance.
  static double luminance(Color c) {
    double channel(int v) {
      final s = v / 255;
      return s <= 0.04045
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    final [r, g, b] = _rgb(c);
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
  }

  /// WCAG 2 contrast ratio, 1 to 21.
  static double contrast(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// [c] mixed toward [target] in 1% steps, just far enough to reach
  /// [ratio] against [against] (or all the way, if it never does).
  static Color toward(Color c, Color target, Color against, double ratio) {
    var t = 0.0;
    while (contrast(mix(c, target, t), against) < ratio && t < 1) {
      t += 0.01;
    }
    return mix(c, target, t);
  }

  /// Text on the fill [c]: white when it reads at 4.5:1, else a dark
  /// shade of [c].
  static Color textOn(Color c) =>
      contrast(c, white) >= 4.5 ? white : toward(c, black, c, 4.8);

  /// A fill that carries a label: [c] deepened just enough for white text
  /// when white nearly reads on it; a light fill, like a yellow, stays as
  /// it is and takes dark text instead ([textOn]).
  static Color labelledFill(Color c) =>
      contrast(c, white) >= 3 ? toward(c, black, white, 4.6) : c;
}
