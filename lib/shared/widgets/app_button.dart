import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_status.dart';
import 'tactile_pressable.dart';

/// The kinds of action a button can stand for. Each has exactly one look,
/// so the same kind of action looks the same on every screen.
enum AppButtonVariant {
  /// The screen's main action ("Continue", "Check", "Start").
  primary,

  /// A real alternative to the main action ("Review mistakes", "Practice
  /// for free beans"): white face, green-tinted border, neutral shelf.
  secondary,

  /// A spend or reward action ("Refill with Amole"): Simien Gold.
  accent,

  /// Ends or deletes something ("Leave lesson", "Delete download").
  destructive,

  /// Dismissal ("Skip", "Cancel", "Not now"): a flat text link.
  text,
}

/// How tall a tactile button's face is.
enum AppButtonSize {
  /// 56 px face: actions in a page's bottom dock or a sheet.
  regular,

  /// 44 px face (48 px with its shelf): actions inside cards and rows.
  compact,
}

/// Highland Pulse push button (DESIGN.md component 1, as the Stitch mockups
/// draw it). Pick the constructor for the kind of action; colours are not
/// configurable, which is what keeps buttons consistent across pages.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.badge,
    this.expand = true,
    this.loading = false,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.badge,
    this.expand = true,
    this.loading = false,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.accent({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.badge,
    this.expand = true,
    this.loading = false,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.accent;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.badge,
    this.expand = true,
    this.loading = false,
    this.size = AppButtonSize.regular,
  }) : variant = AppButtonVariant.destructive;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
  }) : variant = AppButtonVariant.text,
       badge = null,
       expand = false,
       loading = false,
       size = AppButtonSize.compact;

  final AppButtonVariant variant;
  final String label;

  /// `null` disables the button: dimmed, and taps do nothing.
  final VoidCallback? onPressed;

  /// Usually an [Icon]; it takes the button's text colour.
  final Widget? leading;
  final Widget? trailing;

  /// A value pinned to the button's right edge, e.g. the "350 Amole" price.
  final AppButtonBadge? badge;

  /// Fill the available width (the default) or hug the label.
  final bool expand;

  /// Shows a spinner in place of the label, keeps the button's size and
  /// ignores taps.
  final bool loading;
  final AppButtonSize size;

  /// The tallest face a tactile button has. Its shelf sits below this.
  static const double regularHeight = 56;
  static const double compactHeight = 44;

  /// Every button, with its shelf, is at least this tall, and the text
  /// link at least this tall and wide: the minimum tap target.
  static const double minTapTarget = 48;

  static const double _borderWidth = 2;

  /// The most of a button's inner width its [badge] may take.
  static const double badgeShare = 0.5;

  bool get _interactive => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final button = variant == AppButtonVariant.text
        ? _TextLink(
            label: label,
            onPressed: _interactive ? onPressed : null,
            leading: leading,
            trailing: trailing,
          )
        : _buildTactile();
    // The badge is part of what the button says ("Refill with Amole, 350
    // Amole"), since the price is the point of it.
    return Semantics(
      button: true,
      enabled: _interactive,
      label: badge == null ? label : '$label, ${badge!.label}',
      excludeSemantics: true,
      onTap: _interactive ? onPressed : null,
      child: Opacity(opacity: onPressed == null ? 0.6 : 1, child: button),
    );
  }

  Widget _buildTactile() {
    final style = _TactileStyle.of(variant);
    final faceHeight = size == AppButtonSize.regular
        ? regularHeight
        : compactHeight;
    final labelStyle = AppTypography.labelLg.copyWith(color: style.foreground);

    Widget row({double? maxWidth}) => Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: badge == null
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.spaceXs),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.forText(labelStyle, label),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.spaceXs),
                trailing!,
              ],
            ],
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: AppSpacing.spaceSm),
          if (maxWidth == null)
            badge!
          else
            // At most half the button, shrinking to fit, so a long price
            // or large text never crowds the label out.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth * badgeShare),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: badge!,
              ),
            ),
        ],
      ],
    );
    Widget content = badge == null
        ? row()
        : LayoutBuilder(
            builder: (context, constraints) => row(
              maxWidth: constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : null,
            ),
          );
    if (loading) {
      // The label stays laid out (invisibly) so the button keeps its size.
      content = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: content),
          AppSpinner(size: 22, color: style.foreground),
        ],
      );
    }

    // Every variant takes the same height with its shelf, so buttons side
    // by side line up even when one has the shallower tile shelf.
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppShadows.shelfDepth - style.shelfDepth,
      ),
      child: TactilePressable(
        onPressed: _interactive ? onPressed : null,
        faceColor: style.face,
        borderColor: style.border,
        borderWidth: _borderWidth,
        borderRadius: BorderRadius.circular(AppRadii.full),
        shelfDepth: style.shelfDepth,
        shadows: (visible) => AppShadows.button(
          style.shelf,
          depth: style.shelfDepth,
          visible: visible,
        ),
        child: ConstrainedBox(
          // A border sits inside the face, so bordered variants are just as
          // tall as the others.
          constraints: BoxConstraints(
            minHeight:
                faceHeight - (style.border == null ? 0 : 2 * _borderWidth),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size == AppButtonSize.regular
                  ? AppSpacing.spaceLg
                  : AppSpacing.spaceMd,
              vertical: AppSpacing.spaceXs,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: style.foreground, size: 22),
              child: Center(widthFactor: 1, heightFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// A value shown inside a button's right edge, such as a price
/// (`AppButton.accent(badge: AppButtonBadge(label: '350 Amole'))`).
class AppButtonBadge extends StatelessWidget {
  const AppButtonBadge({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceXs,
        vertical: AppSpacing.space2xs / 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.onSecondaryContainer),
            const SizedBox(width: AppSpacing.space2xs),
          ],
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// One look per tactile variant: face, border, shelf and text colour.
class _TactileStyle {
  const _TactileStyle({
    required this.face,
    required this.shelf,
    required this.foreground,
    this.border,
    this.shelfDepth = AppShadows.shelfDepth,
  });

  final Color face;
  final Color? border;
  final Color shelf;
  final double shelfDepth;
  final Color foreground;

  static _TactileStyle of(AppButtonVariant variant) => switch (variant) {
    AppButtonVariant.primary => const _TactileStyle(
      face: AppColors.primaryContainer,
      shelf: AppColors.primaryBevel,
      foreground: AppColors.onPrimary,
    ),
    AppButtonVariant.secondary => _TactileStyle(
      face: AppColors.surfaceContainerLowest,
      border: AppColors.primary.withValues(alpha: 0.3),
      shelf: AppColors.tileShelf,
      shelfDepth: AppShadows.tileShelfDepth,
      foreground: AppColors.primary,
    ),
    AppButtonVariant.accent => const _TactileStyle(
      face: AppColors.secondaryContainer,
      border: AppColors.secondary,
      shelf: AppColors.secondary,
      foreground: AppColors.onSecondaryContainer,
    ),
    AppButtonVariant.destructive => const _TactileStyle(
      face: AppColors.tertiaryBrand,
      shelf: AppColors.tertiaryBevel,
      foreground: AppColors.onTertiary,
    ),
    AppButtonVariant.text => throw StateError('text has no tactile style'),
  };
}

/// The flat "Not now" link: muted `label-md` text that turns green while
/// pressed, inside a tap target of at least 48×48.
class _TextLink extends StatefulWidget {
  const _TextLink({
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;

  @override
  State<_TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<_TextLink> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null || value == _pressed) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = _pressed ? AppColors.primary : AppColors.onSurfaceVariant;
    final style = AppTypography.labelMd.copyWith(color: color);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppButton.minTapTarget,
          minWidth: AppButton.minTapTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceSm),
          child: IconTheme.merge(
            data: IconThemeData(color: color, size: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: AppSpacing.space2xs),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: AppTypography.forText(style, widget.label),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: AppSpacing.space2xs),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
