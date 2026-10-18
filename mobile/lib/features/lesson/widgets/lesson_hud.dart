import 'package:flutter/material.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/app_status.dart';

/// The "Stat Badges & Floating HUD" component (`DESIGN.md` component 3):
/// streak, beans, XP, and (bolt 018-amole-ui) Amole pills.
///
/// 011-dashboard-ui-polish, story 001: these live in the dashboard's pinned
/// header now, sharing one row with the course control, so every pill is an
/// icon and a value. The streak's spelled-out "N Day Streak" would not fit
/// four pills and a course name at 320dp; it survives as the pill's semantic
/// label, so a screen reader still reads what it read before.
///
/// Each pill is the library's [StatPill] (018-mobile-design-system, bolt
/// 047).
///
/// With [onOpen] the pills are buttons (013-stat-pill-interactions, bolt
/// 060). The row is scaled down to fit and the pills can be under 20 dp
/// tall, so the tap area is the whole space the row is given -- the
/// header's full height, and all its width -- and a tap goes to the pill
/// nearest it.
class LessonHud extends StatefulWidget {
  const LessonHud({
    super.key,
    required this.streakCount,
    required this.beans,
    required this.beansMax,
    required this.totalXp,
    required this.amoleBalance,
    this.onOpen,
  });

  final int streakCount;
  final int beans;
  final int beansMax;
  final int totalXp;
  final int amoleBalance;

  /// Called with the pill tapped.
  final ValueChanged<StatKind>? onOpen;

  @override
  State<LessonHud> createState() => _LessonHudState();
}

class _LessonHudState extends State<LessonHud> {
  final Map<StatKind, GlobalKey> _keys = {
    for (final kind in StatKind.values) kind: GlobalKey(),
  };

  /// The pill a finger is down on, for its pressed look.
  StatKind? _pressed;

  /// The pill nearest [global] across the row: the one under it, or the
  /// one whose edge is closer, so a gap is split down its middle.
  StatKind? _nearest(Offset global) {
    StatKind? best;
    var bestDistance = double.infinity;
    for (final MapEntry(key: kind, value: key) in _keys.entries) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final left = box.localToGlobal(Offset.zero).dx;
      final right = box.localToGlobal(box.size.topRight(Offset.zero)).dx;
      final x = global.dx;
      final distance = x < left ? left - x : (x > right ? x - right : 0.0);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = kind;
      }
    }
    return best;
  }

  void _press(StatKind? kind) {
    if (_pressed != kind) setState(() => _pressed = kind);
  }

  @override
  Widget build(BuildContext context) {
    final onOpen = widget.onOpen;
    Widget pill(StatKind kind, int value, {int? max}) => StatPill(
      key: _keys[kind],
      kind: kind,
      value: value,
      max: max,
      onPressed: onOpen == null ? null : () => onOpen(kind),
      pressed: _pressed == kind,
    );

    // Scales the whole row down rather than overflowing when the header is
    // narrow or the text is large.
    final row = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill(StatKind.streak, widget.streakCount),
          const SizedBox(width: AppSpacing.spaceXs),
          pill(StatKind.beans, widget.beans, max: widget.beansMax),
          const SizedBox(width: AppSpacing.spaceXs),
          pill(StatKind.xp, widget.totalXp),
          const SizedBox(width: AppSpacing.spaceXs),
          pill(StatKind.amole, widget.amoleBalance),
        ],
      ),
    );
    if (onOpen == null) return row;

    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        key: const ValueKey('lesson-hud-tap-area'),
        behavior: HitTestBehavior.opaque,
        // Screen readers reach each pill's own button instead.
        excludeFromSemantics: true,
        onTapDown: (details) => _press(_nearest(details.globalPosition)),
        onTapCancel: () => _press(null),
        onTapUp: (details) {
          _press(null);
          final kind = _nearest(details.globalPosition);
          if (kind != null) onOpen(kind);
        },
        // The row alone is as small as the pills; the tap area is all the
        // space the row is given.
        child: SizedBox(
          width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          child: Align(alignment: Alignment.centerRight, child: row),
        ),
      ),
    );
  }
}
