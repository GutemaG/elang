import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'answer_tile.dart';

/// A picture answer (019-image-choice-exercise-types, story 001).
///
/// It is an [AnswerTile] with the [AnswerTileShape.picture] shape, so it
/// has the same six states, colours, press, shelf and shake as every other
/// answer, and nothing about a grade is drawn twice. [altText] is what a
/// screen reader reads; it is never shown beside the picture.
///
/// The picture is fitted inside the square, never cropped, and decoded at
/// the tile's size rather than its own. While it loads the tile shows a
/// quiet placeholder; if it fails, the tile shows [altText] instead and can
/// still be chosen.
///
/// [image] is a provider rather than an address, so the lesson can pass a
/// network, bundled or (from bolt 054) downloaded picture, and tests an
/// in-memory one.
class PictureTile extends StatelessWidget {
  const PictureTile({
    super.key,
    required this.image,
    required this.altText,
    this.state = AnswerTileState.idle,
    this.onTap,
  });

  final ImageProvider image;
  final String altText;
  final AnswerTileState state;
  final VoidCallback? onTap;

  /// The placeholder shown while the picture loads.
  static const loadingKey = ValueKey('picture-tile-loading');

  /// What shows in place of a picture that could not be loaded.
  static const failedKey = ValueKey('picture-tile-failed');

  /// The side of the square picture inside a tile [tileWidth] wide: the
  /// tile less its border and inset on each side.
  static double pictureSideFor(double tileWidth) =>
      tileWidth - (AnswerTile.borderWidth + AnswerTile.pictureInset) * 2;

  /// [image] as a tile decodes it: to fit a square of [pictureSide]
  /// logical pixels on a screen of [devicePixelRatio], and never enlarged.
  ///
  /// The tile and anything loading its picture early (the lesson screen)
  /// both use this, so an early load is the very image the tile draws
  /// rather than a second copy at another size.
  static ImageProvider decodedImage(
    ImageProvider image, {
    required double pictureSide,
    required double devicePixelRatio,
  }) {
    if (!pictureSide.isFinite || pictureSide <= 0) return image;
    final pixels = (pictureSide * devicePixelRatio).ceil();
    return ResizeImage(
      image,
      width: pixels,
      height: pixels,
      policy: ResizeImagePolicy.fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnswerTile(
      label: altText,
      state: state,
      shape: AnswerTileShape.picture,
      onTap: onTap,
      picture: _FittedPicture(image: image, altText: altText),
    );
  }
}

/// 2 to 4 picture answers, two to a row (story 001).
///
/// Every tile is the same square size, [gap] apart both ways. Three
/// pictures sit two then one, the last centred. On a wide screen the grid
/// stops at [maxWidth] and is centred, so pictures stay a comfortable size.
class PictureGrid extends StatelessWidget {
  const PictureGrid({super.key, required this.children});

  final List<Widget> children;

  static const double gap = AppSpacing.spaceSm;
  static const double maxWidth = 400;

  /// How wide each tile is in a grid given [availableWidth].
  static double tileWidthFor(double availableWidth) =>
      (math.min(availableWidth, maxWidth) - gap) / 2;

  @override
  Widget build(BuildContext context) {
    assert(
      children.length >= 2 && children.length <= 4,
      'A picture question has 2 to 4 pictures',
    );
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = tileWidthFor(constraints.maxWidth);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: gap),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: side, child: children[i]),
                      if (i + 1 < children.length) ...[
                        const SizedBox(width: gap),
                        SizedBox(width: side, child: children[i + 1]),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The picture inside a picture tile: fitted, decoded at the tile's size,
/// with a placeholder while it loads and the alt text if it fails.
class _FittedPicture extends StatelessWidget {
  const _FittedPicture({required this.image, required this.altText});

  final ImageProvider image;
  final String altText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decoded no bigger than it is drawn: a 512 px picture in a 138 px
        // tile costs a 138 px bitmap's memory, not a 512 px one's.
        final decoded = PictureTile.decodedImage(
          image,
          pictureSide: math.max(constraints.maxWidth, constraints.maxHeight),
          devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
        );
        return Image(
          image: decoded,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, _) =>
              frame == null ? const _Loading() : child,
          errorBuilder: (context, error, stackTrace) =>
              _Failed(altText: altText),
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: PictureTile.loadingKey,
      color: AppColors.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: AppColors.outlineVariant,
        ),
      ),
    );
  }
}

/// The alt text, centred, in the tile's text colour (from the tile's
/// [DefaultTextStyle]).
class _Failed extends StatelessWidget {
  const _Failed({required this.altText});

  final String altText;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return Center(
      key: PictureTile.failedKey,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space2xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 28, color: style.color),
            const SizedBox(height: AppSpacing.space2xs),
            Flexible(
              child: Text(
                altText,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.forText(style, altText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
