import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_context.dart';
import '../theme/app_typography.dart';
import 'component_gallery.dart';

/// Every colour role with its light and dark value side by side
/// (022-light-and-dark-themes, story 005, FR-6), so a colour change can be
/// checked in both palettes at once.
///
/// The one place outside the theme that reads the palettes directly
/// ([AppPalette.all]): showing both at once is its job. The page itself
/// (headings, names, frames) still draws in the current theme.
class ColoursGallerySection extends StatelessWidget {
  const ColoursGallerySection({super.key});

  @override
  Widget build(BuildContext context) {
    final palettes = AppPalette.all.entries.toList();
    return GallerySection(
      title: 'Colours',
      note:
          'Every role in AppPalette, light and dark side by side. Edit them '
          'in app_palette.dart.',
      children: [
        for (final (group, roles) in AppPalette.roles)
          GalleryCase(
            label: group,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (name, read) in roles)
                  _RoleLine(
                    name: name,
                    values: [
                      for (final MapEntry(key: palette, value: p) in palettes)
                        (palette, read(p)),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One role: its name, then a swatch and hex for each palette.
class _RoleLine extends StatelessWidget {
  const _RoleLine({required this.name, required this.values});

  final String name;
  final List<(String, Color)> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            style: AppTypography.labelSm.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.space2xs),
          Row(
            children: [
              for (final (i, (palette, colour)) in values.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.spaceSm),
                Expanded(
                  child: _Swatch(palette: palette, colour: colour),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A colour chip over a checkerboard, so a clear or see-through colour
/// shows as one, then the palette's name and the hex.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette, required this.colour});

  final String palette;
  final Color colour;

  /// `#RRGGBB`, with the alpha after it when it isn't opaque
  /// (`#FFFFFF @00`).
  static String hex(Color colour) {
    final argb = colour.toARGB32().toRadixString(16).padLeft(8, '0');
    final rgb = '#${argb.substring(2).toUpperCase()}';
    return argb.startsWith('ff')
        ? rgb
        : '$rgb @${argb.substring(0, 2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              side: BorderSide(color: context.colors.outlineVariant),
            ),
          ),
          child: CustomPaint(
            painter: _Checkerboard(
              light: context.colors.surfaceContainerLowest,
              dark: context.colors.surfaceContainerHighest,
            ),
            child: ColoredBox(color: colour),
          ),
        ),
        const SizedBox(width: AppSpacing.spaceXs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                palette,
                style: AppTypography.bodySm.copyWith(
                  color: context.colors.textMuted,
                  fontSize: 11,
                ),
              ),
              Text(
                hex(colour),
                style: AppTypography.bodySm.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Checkerboard extends CustomPainter {
  _Checkerboard({required this.light, required this.dark});

  final Color light;
  final Color dark;

  static const double _square = 8;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    final paint = Paint()..color = dark;
    for (var y = 0.0; y < size.height; y += _square) {
      for (var x = 0.0; x < size.width; x += _square) {
        if (((x + y) / _square).round().isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, _square, _square), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Checkerboard oldDelegate) =>
      oldDelegate.light != light || oldDelegate.dark != dark;
}
