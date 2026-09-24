import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// What sits behind a page (018-mobile-design-system, FR-3).
enum AppPageBackground {
  /// Cream `#FFF8F5`: most screens.
  plain,

  /// Cream with the dashboard mockup's faint diagonal lattice.
  patterned,

  /// Cream with a soft glow behind the top of the page, as in the
  /// lesson-complete mockup.
  celebration,
}

/// The shell every full screen is built on: background, safe area, the
/// 20 px side margins, scrolling content, and optionally a [topBar], a
/// [bottomDock] of actions and the Tibeb [footerStripe].
///
/// This is the one place in `lib/` that builds a [Scaffold], so every page
/// gets the same background, margins and action placement without setting
/// any of them itself.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.body,
    this.background = AppPageBackground.plain,
    this.topBar,
    this.bottomDock,
    this.footerStripe = false,
    this.scrollable = true,
    this.padded = true,
    this.scrollController,
  });

  final Widget body;
  final AppPageBackground background;

  /// Usually an [AppTopBar].
  final Widget? topBar;

  /// The page's main actions, stacked with 8 px between them and pinned
  /// above the safe area (and the keyboard). Content scrolls under a short
  /// fade along the dock's top edge.
  final List<Widget>? bottomDock;

  /// The woven Tibeb band at the very bottom, as in the out-of-beans mockup.
  final bool footerStripe;

  /// Wrap [body] in a scroll view. Screens that own their scrolling (a
  /// `CustomScrollView` with pinned headers) pass `false`.
  final bool scrollable;

  /// Apply the 20 px side margins. Full-bleed content passes `false`.
  final bool padded;
  final ScrollController? scrollController;

  /// The gap between content and the dock that the fade covers.
  static const double dockFade = AppSpacing.spaceMd;

  @override
  Widget build(BuildContext context) {
    final dock = bottomDock;
    final side = padded ? AppSpacing.marginMobile : 0.0;
    Widget content = scrollable
        ? SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              side,
              topBar == null ? AppSpacing.spaceMd : AppSpacing.spaceXs,
              side,
              dock == null ? AppSpacing.spaceLg : dockFade,
            ),
            child: body,
          )
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: body,
          );
    if (dock != null) {
      content = Stack(
        children: [
          Positioned.fill(child: content),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: dockFade,
            child: IgnorePointer(child: _DockFade()),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppBackground(
        style: background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?topBar,
              Expanded(child: content),
              if (dock != null) _Dock(children: dock),
              if (footerStripe) const TibebStripe(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        0,
        AppSpacing.marginMobile,
        AppSpacing.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.spaceXs),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _DockFade extends StatelessWidget {
  const _DockFade();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background,
          ],
        ),
      ),
    );
  }
}

/// A page's top bar: a leading action (close or back), a centred title and
/// trailing actions or stat pills.
///
/// Its side padding is 16 px, so a 40 px [AppIconButton] face (in its 48 px
/// tap target) lines up with the page's 20 px margin.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.leading,
    this.title,
    this.trailing = const [],
  }) : _brand = false;

  /// The "Buna" wordmark in the centre, as in the lesson-complete mockup.
  const AppTopBar.brand({super.key, this.leading, this.trailing = const []})
    : title = null,
      _brand = true;

  final Widget? leading;
  final String? title;
  final List<Widget> trailing;
  final bool _brand;

  static const double minHeight = 56;
  static const double sidePadding = AppSpacing.marginMobile - 4;

  @override
  Widget build(BuildContext context) {
    final centre = _brand
        ? Text(
            'Buna',
            style: AppTypography.headlineMd.copyWith(color: AppColors.primary),
          )
        : title == null
        ? null
        : Semantics(
            header: true,
            child: Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.forText(
                AppTypography.headlineSm.copyWith(color: AppColors.onSurface),
                title!,
              ),
            ),
          );
    final end = trailing.isEmpty
        ? const SizedBox.shrink()
        : FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < trailing.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.spaceXs),
                  trailing[i],
                ],
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: sidePadding,
        vertical: AppSpacing.space2xs,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight - 8),
        child: centre == null
            ? Row(
                children: [
                  ?leading,
                  const SizedBox(width: AppSpacing.spaceXs),
                  Expanded(
                    child: Align(alignment: Alignment.centerRight, child: end),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: leading ?? const SizedBox.shrink(),
                    ),
                  ),
                  Flexible(flex: 2, child: Center(child: centre)),
                  Expanded(
                    child: Align(alignment: Alignment.centerRight, child: end),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A page background, usable on its own behind custom layouts. Painted
/// backgrounds sit in their own [RepaintBoundary] and never ask to repaint,
/// so they are painted once per size, not on every scroll frame (NFR-3).
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    this.style = AppPageBackground.plain,
    required this.child,
  });

  final AppPageBackground style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final painter = switch (style) {
      AppPageBackground.plain => null,
      AppPageBackground.patterned => const LatticePainter(),
      AppPageBackground.celebration => const CelebrationGlowPainter(),
    };
    return ColoredBox(
      color: AppColors.background,
      child: painter == null
          ? child
          : Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: painter),
                    ),
                  ),
                ),
                Positioned.fill(child: child),
              ],
            ),
    );
  }
}

/// The dashboard mockup's lattice: 1 px lines at 45° and 135°, crossing the
/// top edge every 28 px, in the shadow ink at 3.5 %.
class LatticePainter extends CustomPainter {
  const LatticePainter();

  static const double spacing = 28;
  static const double opacity = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.shadowInk.withValues(alpha: opacity)
      ..strokeWidth = 1;
    final h = size.height;
    for (var x = -h; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), paint);
    }
    for (var x = 0.0; x <= size.width + h; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x - h, h), paint);
    }
  }

  @override
  bool shouldRepaint(LatticePainter oldDelegate) => false;
}

/// The lesson-complete mockup's "sunburst aura": a 320 px
/// `surface-container-high` glow, blurred, centred 200 px from the top.
class CelebrationGlowPainter extends CustomPainter {
  const CelebrationGlowPainter();

  static const double centreFromTop = 200;
  static const double radius = 220;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, centreFromTop);
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.surfaceContainerHigh,
          AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
          AppColors.surfaceContainerHigh.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(rect);
    canvas.drawCircle(centre, radius, paint);
  }

  @override
  bool shouldRepaint(CelebrationGlowPainter oldDelegate) => false;
}

/// The two Tibeb accents the mockups draw.
enum TibebStyle {
  /// The out-of-beans footer: diagonal terracotta, gold and green bands with
  /// a cream gap, woven like a Habesha border.
  woven,

  /// The milestone and refill-timer cards' top band: green to gold to
  /// terracotta.
  gradient,
}

/// A Tibeb band (DESIGN.md "Cultural Grounding"), full width.
class TibebStripe extends StatelessWidget {
  const TibebStripe({super.key, this.style = TibebStyle.woven, this.height});

  final TibebStyle style;

  /// Defaults to 10 px woven and 6 px gradient.
  final double? height;

  static const double wovenHeight = 10;
  static const double gradientHeight = 6;

  @override
  Widget build(BuildContext context) {
    final h =
        height ?? (style == TibebStyle.woven ? wovenHeight : gradientHeight);
    return ExcludeSemantics(
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: style == TibebStyle.woven
            ? const RepaintBoundary(
                child: CustomPaint(painter: WovenTibebPainter()),
              )
            : const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.secondaryContainer,
                      AppColors.tertiaryContainer,
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// The out-of-beans mockup's `repeating-linear-gradient(45deg, #7d0301 0 8px,
/// #ffa03b 8px 16px, #004527 16px 24px, #fff8f5 24px 28px)`.
class WovenTibebPainter extends CustomPainter {
  const WovenTibebPainter();

  static const bands = <(Color, double)>[
    (AppColors.tertiary, 8),
    (AppColors.secondaryContainer, 8),
    (AppColors.primary, 8),
    (AppColors.surface, 4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    // Bands 8 px wide across a 45° gradient are 8√2 px wide along the edge.
    final stretch = math.sqrt2;
    final period = bands.fold<double>(0, (sum, b) => sum + b.$2) * stretch;
    final h = size.height;
    final paint = Paint();
    for (var start = -h - period; start < size.width; start += period) {
      var x = start;
      for (final (color, width) in bands) {
        final w = width * stretch;
        paint.color = color;
        canvas.drawPath(
          Path()
            ..moveTo(x, 0)
            ..lineTo(x + w, 0)
            ..lineTo(x + w + h, h)
            ..lineTo(x + h, h)
            ..close(),
          paint,
        );
        x += w;
      }
    }
  }

  @override
  bool shouldRepaint(WovenTibebPainter oldDelegate) => false;
}
