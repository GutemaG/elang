import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_status.dart';
import 'bean_timer_card.dart';
import '../../../shared/l10n/app_language.dart';

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
    return SheetHero(
      illustration: const Icon(Icons.local_cafe_outlined),
      illustrationBadge: CountBadge(
        label: '${status.beans} / ${status.beansMax}',
        icon: Icons.local_cafe,
        tone: AppTone.tertiary,
      ),
      tone: AppTone.tertiary,
      title: context.l10n.outOfBeans,
      body: context.l10n.outOfBeansBody,
      content: BeanTimerCard(status: status, now: DateTime.now()),
      primaryAction: AppButton.accent(
        label: status.canAffordRefill
            ? context.l10n.refillWithAmole
            : context.l10n.notEnoughAmole,
        onPressed: status.canAffordRefill ? onRefill : null,
        leading: const Icon(Icons.bolt),
        badge: AppButtonBadge(
          label: context.l10n.amoleAmount('${status.refillCostAmole}'),
          icon: Icons.diamond,
        ),
      ),
      textAction: AppButton.text(
        label: context.l10n.notNow,
        onPressed: onDismiss,
      ),
    );
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
