import 'package:flutter/material.dart';

import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_context.dart';
import '../theme/app_tone.dart';
import '../theme/app_typography.dart';
import 'tactile_pressable.dart';

/// One letter of a script and how it is read, as a pressable tile: the
/// Sounds tab's chart is a grid of these (ሀ over "he").
///
/// [muted] draws a letter that only borrows another's sound in a quieter
/// face; [tone] colours one that stands out, such as a vowel. The tile scales its text down rather than overflow, so the
/// Fidel's seven columns fit a narrow phone at any text size.
class GlyphTile extends StatelessWidget {
  const GlyphTile({
    super.key,
    required this.glyph,
    required this.caption,
    required this.semanticLabel,
    required this.onTap,
    this.muted = false,
    this.tone,
  });

  final String glyph;

  /// Under the glyph: its romanization.
  final String caption;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool muted;
  final AppTone? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final toned = muted || tone == null ? null : context.tone(tone!);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: TactilePressable(
        onPressed: onTap,
        faceColor:
            toned?.surface ??
            (muted ? colors.surfaceContainer : colors.surfaceContainerLowest),
        borderColor: toned?.border ?? colors.tileBorder,
        borderWidth: 1.5,
        borderRadius: BorderRadius.circular(AppRadii.sm + 2),
        shelfDepth: AppShadows.tileShelfDepth,
        shadows: (visible) =>
            context.shadows.raised(colors.tileShelf, visible: visible),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    glyph,
                    style: AppTypography.forText(
                      AppTypography.headlineSm.copyWith(
                        color:
                            toned?.ink ??
                            (muted ? colors.textMuted : colors.onSurface),
                        height: 1.15,
                      ),
                      glyph,
                    ),
                  ),
                  Text(
                    caption,
                    style: AppTypography.labelSm.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small square coloured like a [GlyphTile] of [tone] (or a plain one),
/// for a key that says what the colours mean.
class GlyphSwatch extends StatelessWidget {
  const GlyphSwatch({super.key, this.tone});

  final AppTone? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final toned = tone == null ? null : context.tone(tone!);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: toned?.surface ?? colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.sm / 2),
        border: Border.all(
          color: toned?.border ?? colors.tileBorder,
          width: 1.5,
        ),
      ),
    );
  }
}

/// A letter drawn large in a green square: the head of a letter's sheet.
class GlyphHero extends StatelessWidget {
  const GlyphHero({super.key, required this.glyph, this.size = 96});

  final String glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = context.tone(AppTone.primary);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: tone.border, width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spaceXs),
          child: Text(
            glyph,
            style: AppTypography.displayLg.copyWith(color: tone.ink),
          ),
        ),
      ),
    );
  }
}

/// One letter in a row to choose from, such as a Fidel family's seven
/// forms; [selected] marks the one shown.
class GlyphChoice extends StatelessWidget {
  const GlyphChoice({
    super.key,
    required this.glyph,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String glyph;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = context.tone(AppTone.primary);
    final radius = BorderRadius.circular(AppRadii.sm);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? tone.surface : colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? tone.border : colors.cardBorder),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  glyph,
                  style: AppTypography.forText(
                    AppTypography.labelLg.copyWith(
                      color: selected ? tone.ink : colors.onSurface,
                      fontSize: 18,
                    ),
                    glyph,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
