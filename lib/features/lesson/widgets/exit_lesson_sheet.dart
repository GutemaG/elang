import 'package:flutter/material.dart';

import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Asked when the learner backs out of a lesson part-way through: nothing
/// is saved until the last exercise, so leaving loses this lesson's
/// progress. Pops `true` for Leave; Keep learning, a tap on the scrim or a
/// swipe down all stay in the lesson.
///
/// Laid out with [SheetHero] (018-mobile-design-system, bolt 048): Keep
/// learning is the main action and Leave the real alternative. Opened by
/// [showExitLessonSheet].
class ExitLessonSheet extends StatelessWidget {
  const ExitLessonSheet({super.key, this.isPractice = false});

  final bool isPractice;

  @override
  Widget build(BuildContext context) {
    final what = isPractice ? 'practice' : 'lesson';
    return SheetHero(
      illustration: const Icon(Icons.logout),
      illustrationSize: 96,
      tone: AppTone.tertiary,
      title: 'Leave this $what?',
      body: "Your progress in this $what won't be saved.",
      primaryAction: AppButton.primary(
        label: 'Keep learning',
        onPressed: () => Navigator.of(context).pop(false),
      ),
      secondaryAction: AppButton.secondary(
        label: 'Leave',
        onPressed: () => Navigator.of(context).pop(true),
      ),
    );
  }
}

/// `true` for Leave; `false` for Keep learning; `null` if dismissed.
Future<bool?> showExitLessonSheet(
  BuildContext context, {
  bool isPractice = false,
}) {
  return showAppSheet<bool>(
    context: context,
    builder: (_) => ExitLessonSheet(isPractice: isPractice),
  );
}
