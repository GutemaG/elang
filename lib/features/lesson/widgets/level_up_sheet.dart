import 'package:flutter/material.dart';

import '../../../shared/models/lesson_completion_result.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_status.dart';

/// Story 004's crown-level-up / streak-freeze modal — maps to
/// `level_up_streak_freeze_modal/`. Only shown when
/// [LessonCompletionResult.hasLevelUpFlourish] is true; the base
/// lesson-complete summary always renders on its own regardless.
///
/// Laid out with [SheetHero] inside the library's dialog, as the mockup's
/// centred card (018-mobile-design-system, bolt 048): see
/// [showLevelUpDialog].
class LevelUpSheet extends StatelessWidget {
  const LevelUpSheet({
    super.key,
    required this.result,
    required this.onContinue,
  });

  final LessonCompletionResult result;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final bool freeze = result.streakFreezeUnlocked;
    final String title = freeze ? 'Streak Freeze Unlocked!' : 'Crown Level Up!';
    final level = result.crownLevel;

    return SheetHero(
      illustration: Icon(freeze ? Icons.ac_unit : Icons.workspace_premium),
      illustrationBadge: level != null && level > 0
          ? CountBadge(
              label: 'Lv $level',
              icon: Icons.workspace_premium,
              tone: AppTone.secondary,
            )
          : null,
      title: title,
      body:
          'You reached crown level ${result.crownLevel} '
          '${result.skillUnlockedTitle != null ? 'and unlocked ${result.skillUnlockedTitle}' : ''}'
          '${freeze ? '. A free streak freeze protects one missed day.' : '.'}',
      primaryAction: AppButton.primary(
        label: 'Continue',
        onPressed: onContinue,
      ),
    );
  }
}

/// Opens [LevelUpSheet] in the library's dialog. Continue, the close button
/// and a tap outside all close it; it returns nothing.
Future<void> showLevelUpDialog(
  BuildContext context,
  LessonCompletionResult result,
) {
  return showAppDialog<void>(
    context: context,
    builder: (dialogContext) => LevelUpSheet(
      result: result,
      onContinue: () => Navigator.of(dialogContext).pop(),
    ),
  );
}
