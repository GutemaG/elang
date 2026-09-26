import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tone.dart';
import '../theme/app_typography.dart';
import 'app_page.dart';
import 'app_status.dart';
import 'tactile_pressable.dart';

/// How much room a card leaves around its content.
enum AppCardPadding {
  /// 16 px: most cards.
  regular,

  /// 12 px: small cards in a row, such as stat cards.
  compact,

  /// None: the content (a list of rows) pads itself.
  none,
}

/// DESIGN.md "Tactile Level 1": a white face, a 2 px border, a 24 px radius
/// and a shelf with a soft shadow (018-mobile-design-system, FR-4).
///
/// A [tone] tints the border and shelf only; the face stays white. With
/// [onTap] the card presses like a button and is one button for a screen
/// reader. [selected] marks a chosen option: the border takes the tone's
/// strong colour and the face its selected tint. [filled] paints the whole
/// card in the tone, for the one coloured block on a page (the dashboard's
/// section header, 020-dashboard-section-header); its content then uses
/// the tone's `onFill` for text.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.tone = AppTone.neutral,
    this.topStripe = false,
    this.onTap,
    this.selected,
    this.padding = AppCardPadding.regular,
    this.filled = false,
  });

  final Widget child;
  final AppTone tone;

  /// A solid face, border and shelf in the tone: its `fill`, and its
  /// `fillShelf` underneath.
  final bool filled;

  /// The green-gold-terracotta band along the top edge, as on the milestone
  /// and refill-timer cards.
  final bool topStripe;
  final VoidCallback? onTap;

  /// `null` for a card that is not a choice; otherwise whether it is chosen.
  /// A choice is a button for a screen reader even while disabled.
  final bool? selected;
  final AppCardPadding padding;

  static const double borderWidth = 2;

  EdgeInsets get _insets => switch (padding) {
    AppCardPadding.regular => const EdgeInsets.all(AppSpacing.spaceMd),
    AppCardPadding.compact => const EdgeInsets.all(AppSpacing.spaceSm),
    AppCardPadding.none => EdgeInsets.zero,
  };

  @override
  Widget build(BuildContext context) {
    final isSelected = selected ?? false;
    final border = filled
        ? tone.fill
        : isSelected
        ? tone.icon
        : tone.border;
    final face = filled
        ? tone.fill
        : isSelected
        ? tone.selectedFace
        : AppColors.surfaceContainerLowest;
    final shelf = filled ? tone.fillShelf : tone.shelf;
    final radius = BorderRadius.circular(AppRadii.card);

    // The content is clipped to the inside of the border, so a stripe or a
    // pressed row never paints over the corners.
    final inner = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card - borderWidth),
      child: topStripe
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TibebStripe(style: TibebStyle.gradient),
                // Flexible, so a card held to a fixed height (a pinned
                // banner) squeezes its content instead of overflowing.
                Flexible(
                  child: Padding(padding: _insets, child: child),
                ),
              ],
            )
          : Padding(padding: _insets, child: child),
    );

    final Widget card;
    if (onTap == null) {
      card = Padding(
        padding: const EdgeInsets.only(bottom: AppShadows.shelfDepth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: face,
            borderRadius: radius,
            border: Border.all(color: border, width: borderWidth),
            boxShadow: AppShadows.raised(shelf),
          ),
          // A DecoratedBox, unlike the pressable's Container, does not inset
          // its child by the border.
          child: Padding(
            padding: const EdgeInsets.all(borderWidth),
            child: inner,
          ),
        ),
      );
    } else {
      card = TactilePressable(
        onPressed: onTap,
        faceColor: face,
        borderColor: border,
        borderWidth: borderWidth,
        borderRadius: radius,
        shelfDepth: AppShadows.shelfDepth,
        shadows: (visible) => AppShadows.raised(shelf, visible: visible),
        child: inner,
      );
    }

    if (onTap == null && selected == null) return card;
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      selected: selected,
      child: card,
    );
  }
}

/// A lesson-complete stat card: an icon circle, a big value, a label, and
/// optionally a ribbon ("+1 TODAY") hanging over the top edge.
///
/// It always leaves room above itself for half a ribbon, so a row of stat
/// cards lines up whether or not one has a ribbon.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.tone = AppTone.neutral,
    this.ribbon,
  });

  final IconData icon;
  final String value;
  final String label;
  final AppTone tone;
  final String? ribbon;

  @override
  Widget build(BuildContext context) {
    final ribbonHalf = RibbonBadge.heightOf(context) / 2;
    return MergeSemantics(
      child: Padding(
        padding: EdgeInsets.only(top: ribbonHalf),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              child: AppCard(
                tone: tone,
                padding: AppCardPadding.compact,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconBadge(icon: icon, tone: tone, size: 36),
                    const SizedBox(height: AppSpacing.space2xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: AppTypography.headlineSm.copyWith(
                          color: tone == AppTone.neutral
                              ? AppColors.onSurface
                              : tone.ink,
                        ),
                      ),
                    ),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.forText(
                        AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        label,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (ribbon != null)
              Positioned(
                top: -ribbonHalf,
                left: 0,
                right: 0,
                child: Center(
                  child: RibbonBadge(label: ribbon!, tone: tone),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A tinted stadium with an icon and a message, e.g. "Daily goal complete!"
/// or a sync status. [emphasis] strengthens the border for a message that
/// needs attention (unsynced for 30+ days).
///
/// An [action] (usually a compact [AppButton], such as sign-in's "Retry")
/// sits at the end, and the banner becomes a rounded card so a two-line
/// message still fits beside it.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.tone = AppTone.secondary,
    this.emphasis = false,
    this.action,
  });

  final IconData icon;
  final String message;
  final AppTone tone;
  final bool emphasis;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ink = tone == AppTone.neutral ? AppColors.onSurfaceVariant : tone.ink;
    final text = Text(
      message,
      style: AppTypography.forText(
        AppTypography.bodySm.copyWith(color: ink, fontWeight: FontWeight.w600),
        message,
      ),
    );
    final iconWidget = Icon(icon, size: 20, color: emphasis ? tone.icon : ink);
    final decoration = BoxDecoration(
      color: tone.surface,
      borderRadius: BorderRadius.circular(
        action == null ? AppRadii.full : AppRadii.base,
      ),
      border: Border.all(
        color: emphasis ? tone.icon : ink.withValues(alpha: 0.2),
        width: emphasis ? 2 : 1,
      ),
    );

    if (action == null) {
      return Semantics(
        container: true,
        label: message,
        excludeSemantics: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceMd,
            vertical: AppSpacing.spaceXs,
          ),
          decoration: decoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: AppSpacing.spaceXs),
              Flexible(child: text),
            ],
          ),
        ),
      );
    }
    // The message is read as one phrase; the action stays its own button.
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.spaceMd,
          AppSpacing.spaceXs,
          AppSpacing.spaceXs,
          AppSpacing.spaceXs,
        ),
        decoration: decoration,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                label: message,
                excludeSemantics: true,
                child: Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: AppSpacing.spaceXs),
                    Expanded(child: text),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.spaceXs),
            action!,
          ],
        ),
      ),
    );
  }
}

/// One settings or downloads row: a leading icon badge, a title, an
/// optional subtitle, and a trailing control (Material 3 list anatomy).
///
/// With [onTap] the whole row is one button, darkens while pressed and, if
/// no [trailing] is given, shows a chevron.
class ListRow extends StatefulWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.tone = AppTone.neutral,
    this.trailing,
    this.onTap,
    this.toggled,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final AppTone tone;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Set by [SwitchRow]: the row is read as a switch that is on or off
  /// instead of as a button.
  final bool? toggled;

  static const double oneLineHeight = 56;
  static const double twoLineHeight = 72;

  @override
  State<ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<ListRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || value == _pressed) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final trailing =
        widget.trailing ??
        (widget.onTap == null
            ? null
            : const Icon(
                Icons.chevron_right,
                size: 24,
                color: AppColors.onSurfaceVariant,
              ));
    final row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: widget.subtitle == null
            ? ListRow.oneLineHeight
            : ListRow.twoLineHeight,
      ),
      child: ColoredBox(
        color: _pressed
            ? AppColors.surfaceContainerLow
            : AppColors.surfaceContainerLowest.withValues(alpha: 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceMd,
            vertical: AppSpacing.spaceSm,
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                IconBadge(icon: widget.icon!, tone: widget.tone),
                const SizedBox(width: AppSpacing.spaceMd),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.forText(
                        AppTypography.labelLg.copyWith(
                          color: AppColors.onSurface,
                        ),
                        widget.title,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: AppTypography.forText(
                          AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          widget.subtitle!,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.spaceSm),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
    if (widget.onTap == null) {
      return MergeSemantics(
        child: widget.toggled == null
            ? row
            : Semantics(toggled: widget.toggled, enabled: false, child: row),
      );
    }
    return MergeSemantics(
      child: Semantics(
        button: widget.toggled == null,
        toggled: widget.toggled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: row,
        ),
      ),
    );
  }
}

/// A settings row with a switch (Notifications, Sound). Tapping anywhere
/// on the row flips it, and a screen reader hears one node: the title,
/// then on or off (Material 3 switch guidance).
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.tone = AppTone.neutral,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final AppTone tone;
  final bool value;

  /// `null` disables the row.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return ListRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      tone: tone,
      toggled: value,
      onTap: onChanged == null ? null : () => onChanged(!value),
      // The row carries the switch's meaning; the switch itself would be a
      // second node saying the same thing.
      trailing: ExcludeSemantics(
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// Rows grouped on one card with dividers between them: the settings
/// pattern. Dividers start where the text does.
class ListRowGroup extends StatelessWidget {
  const ListRowGroup({super.key, required this.children});

  final List<Widget> children;

  static const double dividerIndent =
      AppSpacing.spaceMd + IconBadge.defaultSize + AppSpacing.spaceMd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppCardPadding.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: dividerIndent),
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: AppColors.cardBorderDefault),
                ),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Where one section of the skill path ends and the next begins: the
/// section's title, grey and in italics, centred between two hairlines
/// (020-dashboard-section-header, after Duolingo's path).
///
/// Deliberately quiet -- no card, colour or progress -- so the fixed
/// section header stays the only coloured block on the path. A long title
/// wraps to two lines; the hairlines shrink but always keep [minLine] each.
class PathSectionDivider extends StatelessWidget {
  const PathSectionDivider({super.key, required this.title});

  final String title;

  /// The shortest each hairline gets beside a long title.
  static const double minLine = AppSpacing.spaceLg;

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: AppColors.outlineVariant),
      ),
    );
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceLg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxText =
                constraints.maxWidth - 2 * (minLine + AppSpacing.spaceSm);
            return Row(
              children: [
                line,
                const SizedBox(width: AppSpacing.spaceSm),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxText),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.forText(
                      AppTypography.bodyMd.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      title,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceSm),
                line,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The heading above a group of rows or cards: an optional small gold
/// eyebrow ("Current milestone"), the title, and an optional trailing
/// action such as a text link.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.spaceLg,
        bottom: AppSpacing.spaceXs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null)
                    Text(
                      eyebrow!,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  Text(
                    title,
                    style: AppTypography.forText(
                      AppTypography.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                      title,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.spaceSm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
