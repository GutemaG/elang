import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tone.dart';
import '../../theme/app_typography.dart';
import '../app_button.dart';
import '../app_status.dart';

/// How a checked answer was graded.
enum AnswerGrade { correct, incorrect }

/// The bottom of every question (018-mobile-design-system, FR-7): Check
/// before grading, then a tinted panel with the result above Continue.
///
/// Before grading it always takes a Check button's height, whether or not
/// Check shows, so the question does not jump. After grading, the panel
/// slides up above Continue; Continue is green when right and terracotta
/// when wrong. The result comes only from [grade]; the bar holds no state
/// of its own.
class AnswerActionBar extends StatelessWidget {
  const AnswerActionBar({
    super.key,
    this.grade,
    this.onCheck,
    this.canCheck = false,
    this.onContinue,
    this.notice,
  });

  /// `null` before grading.
  final AnswerGrade? grade;

  /// Set for a question that needs Check (a built sentence has no single
  /// tap that means "done"). `null` holds Check's space empty instead.
  final VoidCallback? onCheck;

  /// Whether there is an answer to check; Check is disabled until then.
  final bool canCheck;
  final VoidCallback? onContinue;

  /// A short terracotta line above the button, such as a failed save.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final graded = grade;
    final Widget button;
    if (graded == null) {
      final check = onCheck;
      button = check == null
          // Holds the button's place so the question does not jump when
          // Continue appears.
          ? const ExcludeSemantics(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: AppButton.primary(label: 'Check', onPressed: null),
                ),
              ),
            )
          : AppButton.primary(
              label: 'Check',
              onPressed: canCheck ? check : null,
            );
    } else {
      button = graded == AnswerGrade.correct
          ? AppButton.primary(label: 'Continue', onPressed: onContinue)
          : AppButton.destructive(label: 'Continue', onPressed: onContinue);
    }

    final message = notice;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (graded != null) ...[
          AnswerFeedbackPanel(key: ValueKey(graded), grade: graded),
          const SizedBox(height: AppSpacing.spaceSm),
        ],
        if (message != null) ...[
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.tertiaryBrand,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
        ],
        button,
      ],
    );
  }
}

/// The graded result: "Correct!" on mint in green, or "Not quite" on blush
/// in terracotta, with a check or cross badge. It slides up over
/// [AppMotion.feedback] (at once with reduced motion) and is announced to a
/// screen reader as it appears.
class AnswerFeedbackPanel extends StatefulWidget {
  const AnswerFeedbackPanel({super.key, required this.grade});

  final AnswerGrade grade;

  static const double borderWidth = 2;

  @override
  State<AnswerFeedbackPanel> createState() => _AnswerFeedbackPanelState();
}

class _AnswerFeedbackPanelState extends State<AnswerFeedbackPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: AppMotion.feedback,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _enter,
    curve: AppMotion.feedbackCurve,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enter.isDismissed) {
      if (AppMotion.reduced(context)) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correct = widget.grade == AnswerGrade.correct;
    final tone = correct ? AppTone.primary : AppTone.tertiary;
    final title = correct ? 'Correct!' : 'Not quite';
    final ink = correct ? AppColors.primaryContainer : AppColors.tertiaryBrand;

    return SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.bottomCenter,
      child: FadeTransition(
        opacity: _curve,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: title,
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spaceMd,
              vertical: AppSpacing.spaceSm,
            ),
            decoration: BoxDecoration(
              color: correct
                  ? AppColors.answerCorrect
                  : AppColors.answerIncorrect,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: tone.border,
                width: AnswerFeedbackPanel.borderWidth,
              ),
            ),
            child: Row(
              children: [
                IconBadge(
                  icon: correct ? Icons.check : Icons.close,
                  tone: tone,
                ),
                const SizedBox(width: AppSpacing.spaceSm),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.headlineSm.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
