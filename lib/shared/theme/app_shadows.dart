/// Highland Pulse elevation tokens: DESIGN.md's "crisp 3D mechanical bevel"
/// model, as the Stitch mockups draw it. A raised element sits on a solid,
/// unblurred shelf in a darker shade, usually with a faint soft shadow
/// beneath (e.g. the dashboard's `0 4px 16px rgba(35,26,17,.08), 0 4px 0
/// #EDE5D8`). Pressed, the shelf collapses.
///
/// Every component takes its shadows from here; nothing outside
/// `lib/shared/` builds a `BoxShadow` (see `test/design/design_rules_test.dart`).
library;

import 'package:flutter/painting.dart';

import 'app_colors.dart';

abstract final class AppShadows {
  /// The standard shelf depth of buttons and cards.
  static const double shelfDepth = 4;

  /// The shelf depth of choice tiles and the white secondary button.
  static const double tileShelfDepth = 3;

  /// A solid shelf of [color], [depth] logical pixels deep.
  static BoxShadow shelf(Color color, {double depth = shelfDepth}) =>
      BoxShadow(color: color, offset: Offset(0, depth));

  /// The faint ambient shadow under a raised card.
  static final BoxShadow soft = BoxShadow(
    color: AppColors.shadowInk.withValues(alpha: 0.08),
    offset: const Offset(0, 4),
    blurRadius: 16,
  );

  /// DESIGN.md "Tactile Level 1": cards and standard modules.
  static final List<BoxShadow> card = [shelf(AppColors.cardBevelDefault), soft];

  /// DESIGN.md component 4: a choice tile at rest.
  static final List<BoxShadow> tile = [
    shelf(AppColors.tileShelf, depth: tileShelfDepth),
    BoxShadow(
      color: AppColors.shadowInk.withValues(alpha: 0.04),
      offset: const Offset(0, 3),
      blurRadius: 8,
    ),
  ];

  /// DESIGN.md "Tactile Level 2": a push button resting on a [bevel]-coloured
  /// shelf, with a soft glow of the same hue beneath it.
  ///
  /// [visible] is how much of the shelf shows: 1 at rest, 0 fully pressed,
  /// a little over 1 while a released button springs back past rest.
  static List<BoxShadow> button(
    Color bevel, {
    double depth = shelfDepth,
    double visible = 1,
  }) {
    final shown = visible < 0 ? 0.0 : visible;
    if (shown == 0) return none;
    return [
      shelf(bevel, depth: depth * shown),
      BoxShadow(
        color: bevel.withValues(alpha: 0.22 * (shown > 1 ? 1 : shown)),
        offset: Offset(0, depth * shown + 4),
        blurRadius: 12,
      ),
    ];
  }

  /// DESIGN.md "Floating Overlays": sheets and dialogs.
  static final List<BoxShadow> overlay = [
    BoxShadow(
      color: AppColors.scrim.withValues(alpha: 0.16),
      offset: const Offset(0, 16),
      blurRadius: 32,
      spreadRadius: -8,
    ),
  ];

  /// DESIGN.md "Streak & Chest Glows": an ambient halo in [color].
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20),
  ];

  /// Pressed: the shelf has collapsed.
  static const List<BoxShadow> none = [];
}
