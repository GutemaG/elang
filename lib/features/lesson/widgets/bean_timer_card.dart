import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_status.dart';

/// "Next bean in 12:34", with a bar for how far the next bean has come and
/// how often beans come back. Shared by the out-of-beans sheet and the
/// stats sheet's beans tab (013-stat-pill-interactions, bolt 060), so both
/// look the same.
///
/// Draws [status] as of [now]; a caller that wants it to tick rebuilds it
/// with a new [now].
class BeanTimerCard extends StatelessWidget {
  const BeanTimerCard({super.key, required this.status, required this.now});

  final BeansStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final remaining = status.nextBeanAt?.difference(now);
    final countdown = remaining == null ? '--:--' : formatCountdown(remaining);
    final period = Duration(minutes: status.regenMinutesPerBean);
    // How far the next bean has come: the part of its period already gone.
    final brewed = remaining == null || period.inSeconds == 0
        ? 0.0
        : (1 - remaining.inSeconds / period.inSeconds).clamp(0.0, 1.0);
    final every = status.regenMinutesPerBean;

    return AppCard(
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
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              Text(
                countdown,
                semanticsLabel: 'Next bean in $countdown',
                style: AppTypography.headlineSm.copyWith(
                  color: context.colors.tertiaryBrand,
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
    );
  }
}

/// "12:34", or "1:02:03" from an hour up; never negative.
String formatCountdown(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  String two(int n) => n.toString().padLeft(2, '0');
  final seconds = two(clamped.inSeconds.remainder(60));
  if (clamped.inHours > 0) {
    return '${clamped.inHours}:${two(clamped.inMinutes.remainder(60))}:'
        '$seconds';
  }
  return '${two(clamped.inMinutes)}:$seconds';
}
