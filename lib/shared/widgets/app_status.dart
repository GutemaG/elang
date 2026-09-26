import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tone.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Status and feedback pieces (018-mobile-design-system, FR-6): the HUD
/// pills, badges, the progress bar, icon badges, the spinner, and the empty,
/// error and loading states. Screens show stats, progress and "nothing
/// here" only through these.

/// The learner's four counters.
enum StatKind { streak, beans, xp, amole }

/// A HUD counter (DESIGN.md component 3, as the dashboard mockup draws it):
/// a translucent white pill with a tinted border, a coloured icon and the
/// number in `label-md`. A screen reader hears one phrase, such as
/// "5 day streak".
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.kind,
    required this.value,
    this.max,
  });

  final StatKind kind;
  final int value;

  /// Beans only: the most the learner can hold, for "3 of 5 beans
  /// remaining".
  final int? max;

  static const double iconSize = 18;
  static const double borderWidth = 1;

  /// The pill's outer height at the current text scale, for pinned headers
  /// whose extent must be known before layout.
  static double heightOf(BuildContext context) {
    final style = AppTypography.labelMd;
    final line =
        (MediaQuery.textScalerOf(context).scale(style.fontSize!) *
                style.height!)
            .ceilToDouble();
    return AppSpacing.space2xs * 2 + math.max(iconSize, line) + 2 * borderWidth;
  }

  (IconData, Color icon, Color text, Color border) get _look => switch (kind) {
    StatKind.streak => (
      Icons.local_fire_department,
      AppColors.streak,
      AppColors.secondary,
      AppColors.streakRim,
    ),
    StatKind.beans => (
      Icons.favorite,
      AppColors.tertiaryBrand,
      AppColors.tertiaryBrand,
      AppTone.tertiary.border,
    ),
    StatKind.xp => (
      Icons.bolt,
      AppColors.secondary,
      AppColors.secondary,
      AppTone.secondary.border,
    ),
    StatKind.amole => (
      Icons.diamond,
      AppColors.gem,
      AppColors.primaryContainer,
      AppTone.primary.border,
    ),
  };

  String get _semanticLabel => switch (kind) {
    StatKind.streak => '$value day streak',
    StatKind.beans =>
      max == null ? '$value beans' : '$value of $max beans remaining',
    StatKind.xp => '$value total XP',
    StatKind.amole => '$value Amole',
  };

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, textColor, border) = _look;
    return Semantics(
      label: _semanticLabel,
      container: true,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceXs,
          vertical: AppSpacing.space2xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(color: border, width: borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: iconColor),
            const SizedBox(width: AppSpacing.space2xs),
            Text(
              groupDigits(value),
              style: AppTypography.labelMd.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// [n] with its thousands grouped by commas: 12340 → "12,340".
String groupDigits(int n) {
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A small read-only count: the dashboard's "3/5 Completed" (neutral) or
/// the out-of-beans "0 / 5" (toned: white face, tone border).
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = AppTone.neutral,
  });

  final String label;
  final IconData? icon;
  final AppTone tone;

  static const double _verticalPadding = 2;

  /// What a badge adds above and below its label: padding and border. A
  /// pinned header adds its label's line height to this to know the
  /// badge's height before layout.
  static double verticalChrome({AppTone tone = AppTone.neutral}) =>
      2 * _verticalPadding + 2 * (tone == AppTone.neutral ? 1 : 2);

  @override
  Widget build(BuildContext context) {
    final neutral = tone == AppTone.neutral;
    final ink = neutral ? AppColors.primary : tone.ink;
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceXs,
          vertical: _verticalPadding,
        ),
        decoration: BoxDecoration(
          color: neutral
              ? AppColors.surfaceContainerHigh
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(
            color: neutral ? AppColors.outlineVariant : tone.icon,
            width: neutral ? 1 : 2,
          ),
          boxShadow: neutral ? AppShadows.badge : AppShadows.none,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: neutral ? ink : tone.icon),
              const SizedBox(width: AppSpacing.space2xs),
            ],
            Text(label, style: AppTypography.labelSm.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}

/// A filled ribbon, e.g. the "+1 TODAY" hanging over a stat card.
class RibbonBadge extends StatelessWidget {
  const RibbonBadge({
    super.key,
    required this.label,
    this.tone = AppTone.tertiary,
  });

  final String label;
  final AppTone tone;

  static const double _verticalPadding = 2;

  /// Its height at the current text scale.
  static double heightOf(BuildContext context) {
    final style = AppTypography.labelSm;
    return MediaQuery.textScalerOf(context).scale(style.fontSize!) *
            style.height! +
        2 * _verticalPadding;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceXs,
        vertical: _verticalPadding,
      ),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.labelSm.copyWith(
          color: tone.onFill,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// The height of an [AppProgressBar]'s track.
enum AppProgressBarSize {
  /// 12 px: milestones and timers.
  regular,

  /// 14 px: the lesson-complete accuracy meter.
  large,
}

/// A sunken, fully rounded track with a fill (the dashboard, out-of-beans
/// and lesson-complete mockups). It eases to a new value over
/// [AppMotion.progress], or jumps there when the system asks for less
/// motion, and always settles.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.tone = AppTone.primary,
    this.gradient = false,
    this.size = AppProgressBarSize.regular,
    this.startLabel,
    this.endLabel,
    this.semanticLabel,
    this.animate = true,
    this.onFilled = false,
  });

  /// From 0 (empty) to 1 (full); values outside are clamped.
  final double value;
  final AppTone tone;

  /// The mockups' gradient fill, with a highlight along its top half.
  final bool gradient;
  final AppProgressBarSize size;

  /// A caption row under the bar, e.g. "Refills 1 bean every 30 minutes"
  /// and "65%".
  final String? startLabel;
  final String? endLabel;

  /// What the bar measures, read before its percentage.
  final String? semanticLabel;

  /// Ease to a new value. A bar whose [value] already comes from its own
  /// animation (the splash screen's brewing bar) passes `false`, so it
  /// shows each value at once instead of trailing behind it.
  final bool animate;

  /// The bar sits on a card filled with its [tone] (the dashboard's section
  /// header, 020-dashboard-section-header): the fill takes the tone's
  /// `onFill` and the track a faint wash of it, since the tone's own fill
  /// would vanish into the card.
  final bool onFilled;

  static const double _inset = 2;

  /// The track's height at each size.
  static const double regularHeight = 12;
  static const double largeHeight = 14;

  List<Color> get _gradientColors => switch (tone) {
    AppTone.primary => const [
      AppColors.primary,
      AppColors.primaryContainer,
      AppColors.primaryFixedDim,
    ],
    AppTone.secondary => const [
      AppColors.secondaryContainer,
      AppColors.secondary,
    ],
    AppTone.tertiary => const [
      AppColors.tertiaryBrand,
      AppColors.tertiaryContainer,
    ],
    AppTone.neutral => const [AppColors.outline, AppColors.onSurfaceVariant],
  };

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final height = size == AppProgressBarSize.regular
        ? regularHeight
        : largeHeight;
    final fillHeight = height - 2 * _inset - 2;

    final bar = Semantics(
      container: true,
      label: semanticLabel,
      value: '${(target * 100).round()}%',
      child: Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(_inset),
        decoration: BoxDecoration(
          color: onFilled
              ? tone.onFill.withValues(alpha: 0.25)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(
            color: onFilled
                ? tone.onFill.withValues(alpha: 0)
                : AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: !animate || AppMotion.reduced(context)
              ? Duration.zero
              : AppMotion.progress,
          curve: AppMotion.progressCurve,
          builder: (context, shown, _) {
            if (shown <= 0) return const SizedBox.shrink();
            return LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  // A sliver of progress is still a round pill, not a dot.
                  width: math.max(fillHeight, constraints.maxWidth * shown),
                  height: fillHeight,
                  child: _Fill(
                    color: onFilled ? tone.onFill : tone.fill,
                    gradient: gradient && !onFilled ? _gradientColors : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (startLabel == null && endLabel == null) return bar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        const SizedBox(height: AppSpacing.space2xs),
        Row(
          children: [
            Expanded(
              child: Text(
                startLabel ?? '',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (endLabel != null) ...[
              const SizedBox(width: AppSpacing.spaceXs),
              Text(
                endLabel!,
                style: AppTypography.labelSm.copyWith(
                  color: tone == AppTone.neutral
                      ? AppColors.onSurfaceVariant
                      : tone.ink,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Fill extends StatelessWidget {
  const _Fill({required this.color, this.gradient});

  final Color color;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.full);
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient == null ? null : LinearGradient(colors: gradient!),
        borderRadius: radius,
      ),
    );
    if (gradient == null) return fill;
    // The dashboard's `bg-white/25` highlight over the fill's top half.
    return Stack(
      fit: StackFit.expand,
      children: [
        fill,
        FractionallySizedBox(
          alignment: Alignment.topCenter,
          heightFactor: 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest.withValues(alpha: 0.25),
              borderRadius: radius,
            ),
          ),
        ),
      ],
    );
  }
}

/// An icon on a tinted circle (or a rounded square, like the refill-timer
/// card's), for rows, stat cards and empty states. Decorative: the text
/// beside it carries the meaning.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.tone = AppTone.neutral,
    this.size = defaultSize,
    this.square = false,
  });

  final IconData icon;
  final AppTone tone;
  final double size;
  final bool square;

  static const double defaultSize = 40;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tone.surface,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(size * 0.3) : null,
          border: square
              ? Border.all(color: tone.icon.withValues(alpha: 0.2))
              : null,
        ),
        child: Icon(icon, size: size * 0.55, color: tone.icon),
      ),
    );
  }
}

/// Which page of a carousel is showing: a dot per page, the current one a
/// wide green pill (the onboarding mockup). A screen reader hears "Page 2
/// of 3".
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});

  final int count;

  /// The current page, from 0.
  final int index;

  static const double dotSize = 10;
  static const double activeWidth = 28;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.reduced(context)
        ? Duration.zero
        : AppMotion.state;
    return Semantics(
      container: true,
      label: 'Page ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: AppMotion.stateCurve,
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space2xs,
              ),
              width: i == index ? activeWidth : dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: i == index
                    ? AppColors.primaryContainer
                    : AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
            ),
        ],
      ),
    );
  }
}

/// The one spinner, in a token colour. Indeterminate spinners never
/// settle, so a place a test pumps to rest shows [LoadingState.still]
/// instead.
class AppSpinner extends StatelessWidget {
  const AppSpinner({
    super.key,
    this.size = 24,
    this.strokeWidth = 2.5,
    this.color = AppColors.primaryContainer,
  });

  const AppSpinner.small({super.key, this.color = AppColors.primaryContainer})
    : size = 16,
      strokeWidth = 2;

  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        strokeCap: StrokeCap.round,
        color: color,
      ),
    );
  }
}

/// Nothing to show yet (NN/g): what the learner is seeing, how the space
/// gets filled, and the next action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.tone = AppTone.secondary,
  });

  final IconData icon;
  final String title;

  /// How this space gets filled, e.g. "Download a lesson to learn offline."
  final String message;

  /// Usually an [AppButton].
  final Widget? action;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return _StatusLayout(
      badge: IconBadge(icon: icon, tone: tone, size: _StatusLayout.badgeSize),
      title: title,
      message: message,
      action: action,
    );
  }
}

/// Something went wrong: what happened, in plain words, and a way to try
/// again. Never a stack trace, never a blank screen.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.cloud_off,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.action,
  });

  final String title;

  /// More about what happened, when the title alone does not say it.
  final String? message;
  final IconData icon;

  /// Shows a primary "Try again" button.
  final VoidCallback? onRetry;
  final String retryLabel;

  /// A different action, when retrying is not the way out.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _StatusLayout(
      badge: IconBadge(
        icon: icon,
        tone: AppTone.tertiary,
        size: _StatusLayout.badgeSize,
      ),
      title: title,
      message: message,
      action:
          action ??
          (onRetry == null
              ? null
              : AppButton.primary(
                  label: retryLabel,
                  onPressed: onRetry,
                  expand: false,
                )),
    );
  }
}

/// Waiting for something. [LoadingState.still] draws the same layout
/// without any animation, for placeholders that sit under a sheet while a
/// test pumps to rest; it is also what shows when the system asks for less
/// motion.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message}) : animate = true;

  const LoadingState.still({super.key, this.message}) : animate = false;

  final String? message;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final spin = animate && !AppMotion.reduced(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: message ?? 'Loading',
      excludeSemantics: true,
      child: _StatusLayout(
        badge: spin
            ? Container(
                width: _StatusLayout.badgeSize,
                height: _StatusLayout.badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTone.primary.surface,
                  shape: BoxShape.circle,
                ),
                child: const AppSpinner(size: 32, strokeWidth: 3),
              )
            : const IconBadge(
                icon: Icons.hourglass_top,
                tone: AppTone.primary,
                size: _StatusLayout.badgeSize,
              ),
        message: message,
      ),
    );
  }
}

class _StatusLayout extends StatelessWidget {
  const _StatusLayout({
    required this.badge,
    this.title,
    this.message,
    this.action,
  });

  final Widget badge;
  final String? title;
  final String? message;
  final Widget? action;

  static const double badgeSize = 72;
  static const double _maxTextWidth = 320;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            if (title != null) ...[
              const SizedBox(height: AppSpacing.spaceMd),
              Text(
                title!,
                textAlign: TextAlign.center,
                style: AppTypography.forText(
                  AppTypography.headlineSm.copyWith(color: AppColors.onSurface),
                  title!,
                ),
              ),
            ],
            if (message != null) ...[
              SizedBox(
                height: title == null ? AppSpacing.spaceMd : AppSpacing.spaceXs,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxTextWidth),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppTypography.forText(
                    AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    message!,
                  ),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
