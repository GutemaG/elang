import 'package:flutter/material.dart';

/// The pixel height of [lines] lines of [style] at this context's text scale,
/// never less than what `Text` will actually render.
///
/// Every `AppTypography` style declares an explicit `height`, so a line is
/// `fontSize * height`, with the scaler applied to the font size exactly as
/// `Text` applies it. That makes the height of a fixed number of lines
/// arithmetic rather than a measurement -- which is what lets pinned chrome
/// declare a correct extent before layout instead of guessing a constant that
/// clips at 1.3x text.
///
/// **Each line is rounded up**, because that is what the text layout itself
/// does: at 1.3x, `labelMd` computes to 20.8 and renders as 21. Reserving the
/// un-rounded value left the section banner one pixel short on device, and
/// floating point made some lines a fraction short even at whole scales.
double scaledLineHeight(
  BuildContext context,
  TextStyle style, {
  int lines = 1,
}) {
  final scaled = MediaQuery.textScalerOf(context).scale(style.fontSize!);
  return (scaled * (style.height ?? 1.0)).ceilToDouble() * lines;
}

/// Chrome that stays put while the rest of the page scrolls under it
/// (011-dashboard-ui-polish, story 002).
///
/// A fixed-extent delegate: the caller computes the height (see
/// [scaledLineHeight]) and hands it in, because
/// [SliverPersistentHeaderDelegate.maxExtent] is a getter with no
/// `BuildContext` and so cannot read the ambient text scale itself.
class PinnedHeaderSliver extends SliverPersistentHeaderDelegate {
  const PinnedHeaderSliver({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant PinnedHeaderSliver oldDelegate) =>
      oldDelegate.extent != extent || oldDelegate.child != child;
}

/// Convenience for the common case: a pinned header of a known [extent].
SliverPersistentHeader pinnedHeader({
  required double extent,
  required Widget child,
}) => SliverPersistentHeader(
  pinned: true,
  delegate: PinnedHeaderSliver(extent: extent, child: child),
);
