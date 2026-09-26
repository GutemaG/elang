import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_status.dart';

/// Story 003's out-of-beans modal — maps to `out_of_beans_refill_modal/`.
///
/// Shown the instant local beans hit 0 mid-lesson. Offers an Amole refill
/// (disabled when the account can't afford it, per that story's edge
/// case) or a "Not now" dismiss; either path hands control back to the
/// caller via the two callbacks rather than navigating itself, so
/// `LessonScreen` stays in charge of what "resume" vs. "return to
/// dashboard" actually does.
///
/// Laid out as the mockup with [SheetHero] (018-mobile-design-system, bolt
/// 048): the beans count on the illustration, a refill-timer card, the
/// Amole refill with its price, and "Not now". Opened by
/// [showOutOfBeansSheet], which cannot be dismissed any other way.
class OutOfBeansSheet extends StatelessWidget {
  const OutOfBeansSheet({
    super.key,
    required this.status,
    required this.onRefill,
    required this.onDismiss,
  });

  final BeansStatus status;
  final VoidCallback onRefill;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final remaining = status.nextBeanAt?.difference(DateTime.now());
    final String countdown = remaining == null
        ? '--:--'
        : _formatDuration(remaining);
    final period = Duration(minutes: status.regenMinutesPerBean);
    // How far the next bean has come: the part of its period already gone.
    final brewed = remaining == null || period.inSeconds == 0
        ? 0.0
        : 1 - remaining.inSeconds / period.inSeconds;
    final every = status.regenMinutesPerBean;

    return SheetHero(
      illustration: const Icon(Icons.local_cafe_outlined),
      illustrationBadge: CountBadge(
        label: '${status.beans} / ${status.beansMax}',
        icon: Icons.local_cafe,
        tone: AppTone.tertiary,
      ),
      tone: AppTone.tertiary,
      title: 'Out of Beans!',
      body:
          "Don't worry, mistakes help you brew fluency! Beans refill "
          'automatically over time so you can continue your lessons.',
      content: AppCard(
        topStripe: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: Icons.hourglass_top,
                  tone: AppTone.tertiary,
                  square: true,
                ),
                const SizedBox(width: AppSpacing.spaceXs),
                Expanded(
                  child: Text(
                    'Next bean in',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Text(
                  countdown,
                  semanticsLabel: 'Next bean in $countdown',
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.tertiaryBrand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            AppProgressBar(
              value: brewed,
              tone: AppTone.secondary,
              gradient: true,
              startLabel: every > 0
                  ? 'Refills 1 bean every $every '
                        '${every == 1 ? 'minute' : 'minutes'}'
                  : null,
              semanticLabel: 'Next bean',
            ),
          ],
        ),
      ),
      primaryAction: AppButton.accent(
        label: status.canAffordRefill
            ? 'Refill with Amole'
            : 'Not enough Amole',
        onPressed: status.canAffordRefill ? onRefill : null,
        leading: const Icon(Icons.bolt),
        badge: AppButtonBadge(
          label: '${status.refillCostAmole} Amole',
          icon: Icons.diamond,
        ),
      ),
      textAction: AppButton.text(label: 'Not now', onPressed: onDismiss),
    );
  }

  static String _formatDuration(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Opens [OutOfBeansSheet]. It cannot be dismissed by a tap outside or a
/// drag; only its own two actions close it.
Future<void> showOutOfBeansSheet(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showAppSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: builder,
  );
}
