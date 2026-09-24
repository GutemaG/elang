/// Highland Pulse motion tokens. A press goes in almost at once and comes
/// back with a small spring, which is what makes a tactile button feel
/// physical (see bolt 042's implementation plan for the references).
library;

import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  /// A tactile element sinking onto its shelf.
  static const Duration pressIn = Duration(milliseconds: 60);
  static const Curve pressInCurve = Curves.easeOut;

  /// Released: back up with a slight overshoot.
  static const Duration pressOut = Duration(milliseconds: 180);
  static const Curve pressOutCurve = Curves.easeOutBack;

  /// A colour or border changing state (selected, graded).
  static const Duration state = Duration(milliseconds: 150);
  static const Curve stateCurve = Curves.easeOut;

  /// The incorrect-answer shake.
  static const Duration shake = Duration(milliseconds: 400);

  /// The graded-answer panel sliding up above Continue (Duolingo's
  /// feedback banner: about 200 ms, easing out).
  static const Duration feedback = Duration(milliseconds: 200);
  static const Curve feedbackCurve = Curves.easeOut;

  /// A progress bar moving to a new value.
  static const Duration progress = Duration(milliseconds: 400);
  static const Curve progressCurve = Curves.easeOutCubic;

  /// Whether the system asks for less motion. Components then skip
  /// movement (press travel, shake) and keep only colour changes.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
