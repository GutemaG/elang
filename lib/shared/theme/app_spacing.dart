/// Highland Pulse spacing + radius tokens, converted from the `rem` values in
/// `highland_pulse/DESIGN.md` to logical pixels (1rem == 16px), so every
/// screen references one set of constants instead of scattering magic
/// numbers.
library;

abstract final class AppSpacing {
  static const double space2xs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double space2xl = 48;
  static const double space3xl = 64;

  /// Fixed horizontal safe-area padding used on every screen shell.
  static const double marginMobile = 20;
  static const double gutterMobile = 12;
}

abstract final class AppRadii {
  static const double sm = 8;
  static const double base = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
  static const double full = 9999;

  /// Choice tiles and text entry: DESIGN.md "Shapes", 1.25rem.
  static const double tile = 20;

  /// Cards and exercise panels: DESIGN.md "Shapes", `rounded-2xl`.
  static const double card = 24;
}
