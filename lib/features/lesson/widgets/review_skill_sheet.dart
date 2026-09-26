import 'package:flutter/material.dart';

import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Shown when a completed skill is tapped: a completed skill is only ever
/// reviewed, so the learner says so here instead of dropping straight into
/// the lesson as if it were new. Pops `true` for Review, `null` otherwise.
///
/// Laid out with [SheetHero] (018-mobile-design-system, bolt 048); "Not now"
/// does what a swipe down does. Opened by [showReviewSkillSheet].
class ReviewSkillSheet extends StatelessWidget {
  const ReviewSkillSheet({super.key, required this.skillTitle});

  final String skillTitle;

  @override
  Widget build(BuildContext context) {
    return SheetHero(
      illustration: const Icon(Icons.workspace_premium),
      illustrationSize: 96,
      title: skillTitle,
      body:
          "You've completed this skill. Review it any time -- reviews "
          "don't earn XP or use beans.",
      primaryAction: AppButton.primary(
        label: 'Review',
        onPressed: () => Navigator.of(context).pop(true),
      ),
      textAction: AppButton.text(
        label: 'Not now',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Asks whether to review [skillTitle]: `true` for Review, `null` for Not
/// now or a dismissal.
Future<bool?> showReviewSkillSheet(BuildContext context, String skillTitle) {
  return showAppSheet<bool>(
    context: context,
    builder: (_) => ReviewSkillSheet(skillTitle: skillTitle),
  );
}
