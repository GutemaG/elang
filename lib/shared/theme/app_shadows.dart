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

  /// A card on a [shelfColor] shelf (a tone's), with [visible] of the shelf
  /// showing, as for [button]. The soft shadow stays put.
  static List<BoxShadow> raised(Color shelfColor, {double visible = 1}) {
    final shown = visible < 0 ? 0.0 : visible;
    return [if (shown > 0) shelf(shelfColor, depth: shelfDepth * shown), soft];
  }

  /// A small read-only badge ("3/5 Completed"): the dashboard's
  /// `0 2px 0 #EDE5D8`.
  static final List<BoxShadow> badge = [
    shelf(AppColors.cardBorderDefault, depth: 2),
  ];

  /// A dialog card: the level-up mockup's `0 8px 0 #e5d8c3,
  /// 0 24px 48px -12px rgba(43,33,24,.28)`.
  static final List<BoxShadow> dialog = [
    shelf(AppColors.dialogShelf, depth: 8),
    BoxShadow(
      color: AppColors.scrim.withValues(alpha: 0.28),
      offset: const Offset(0, 24),
      blurRadius: 48,
      spreadRadius: -12,
    ),
  ];

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

  /// The pastel halo behind a sheet's illustration circle (the out-of-beans
  /// mockup's blurred `tertiary-fixed` vignette): [color] spread past the
  /// circle and softened.
  static List<BoxShadow> halo(Color color) => [
    BoxShadow(color: color, blurRadius: 24, spreadRadius: 4),
  ];

  /// Pressed: the shelf has collapsed.
  static const List<BoxShadow> none = [];
}
