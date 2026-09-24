import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_icon_button.dart';
import '../app_page.dart';
import '../app_status.dart';
import 'audio_play_button.dart';

/// The one frame every question sits in (018-mobile-design-system, FR-7):
/// close, progress and beans along the top, the [prompt], the scrolling
/// [answers], and the [actionBar] pinned at the bottom, on [AppPage].
///
/// Built from what it is given, not from the lesson's controller, so every
/// question type gets exactly the same top bar, margins and button place.
class ExerciseLayout extends StatelessWidget {
  const ExerciseLayout({
    super.key,
    required this.onClose,
    required this.progress,
    required this.prompt,
    required this.answers,
    required this.actionBar,
    this.beans,
    this.beansMax,
    this.scrollController,
  });

  /// The close button. The lesson passes `Navigator.maybePop`, so its
  /// `PopScope` still asks before leaving part-way through.
  final VoidCallback onClose;

  /// How far through the lesson, from 0 to 1.
  final double progress;

  /// Usually a [QuestionPrompt].
  final Widget prompt;
  final Widget answers;

  /// Usually an [AnswerActionBar].
  final Widget actionBar;

  /// Beans left; `null` hides the pill (a lesson that does not use beans).
  final int? beans;
  final int? beansMax;
  final ScrollController? scrollController;

  /// Between the prompt and the answers.
  static const double promptGap = AppSpacing.spaceLg;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      scrollController: scrollController,
      topBar: ExerciseTopBar(
        onClose: onClose,
        progress: progress,
        beans: beans,
        beansMax: beansMax,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          prompt,
          const SizedBox(height: promptGap),
          answers,
        ],
      ),
      bottomDock: [actionBar],
    );
  }
}

/// A question's top bar: close, the lesson's progress, and beans left. It
/// has [AppTopBar]'s height and side padding, so it lines up with every
/// other page's top bar.
class ExerciseTopBar extends StatelessWidget {
  const ExerciseTopBar({
    super.key,
    required this.onClose,
    required this.progress,
    this.beans,
    this.beansMax,
  });

  final VoidCallback onClose;
  final double progress;
  final int? beans;
  final int? beansMax;

  @override
  Widget build(BuildContext context) {
    final left = beans;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTopBar.sidePadding,
        vertical: AppSpacing.space2xs,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTopBar.minHeight - 8),
        child: Row(
          children: [
            AppIconButton(
              icon: Icons.close,
              tooltip: 'Exit lesson',
              onPressed: onClose,
            ),
            const SizedBox(width: AppSpacing.spaceXs),
            Expanded(
              child: AppProgressBar(
                value: progress,
                semanticLabel: 'Lesson progress',
              ),
            ),
            if (left != null) ...[
              const SizedBox(width: AppSpacing.spaceSm),
              StatPill(kind: StatKind.beans, value: left, max: beansMax),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one prompt style (018-mobile-design-system, FR-7).
///
/// With a [question], the [instruction] is one muted line ("Complete the
/// sentence") and the question sits below it, large and bold. Without one,
/// the instruction alone is the headline. The optional speaker chip sits at
/// the start of the headline, the [pronunciation] under it in the muted
/// phonetic style DESIGN.md asks for under Fidel, then the [translation].
/// Fidel lines get the extra Ethiopic line height and wrap, never clip.
class QuestionPrompt extends StatelessWidget {
  const QuestionPrompt({
    super.key,
    required this.instruction,
    this.question,
    this.translation,
    this.pronunciation,
    this.onPlayAudio,
    this.audioPlaying = false,
  });

  final String instruction;
  final String? question;
  final String? translation;
  final String? pronunciation;

  /// Shows the speaker chip, which calls this.
  final VoidCallback? onPlayAudio;
  final bool audioPlaying;

  @override
  Widget build(BuildContext context) {
    final asked = question;
    final headline = asked ?? instruction;
    final play = onPlayAudio;
    final spoken = pronunciation;
    final meaning = translation;

    final headlineText = Semantics(
      header: true,
      child: Text(
        headline,
        style: AppTypography.forText(
          AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
          headline,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (asked != null) ...[
          Text(
            instruction,
            style: AppTypography.forText(
              AppTypography.labelLg.copyWith(color: AppColors.onSurfaceVariant),
              instruction,
            ),
          ),
          const SizedBox(height: AppSpacing.space2xs),
        ],
        if (play == null)
          headlineText
        else
          Row(
            children: [
              AudioPlayButton(
                onPressed: play,
                playing: audioPlaying,
                size: AudioPlayButtonSize.small,
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              Expanded(child: headlineText),
            ],
          ),
        if (spoken != null) ...[
          const SizedBox(height: AppSpacing.space2xs),
          Text(spoken, style: AppTypography.phonetic),
        ],
        if (meaning != null) ...[
          const SizedBox(height: AppSpacing.space2xs),
          Text(
            meaning,
            style: AppTypography.forText(
              AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              meaning,
            ),
          ),
        ],
      ],
    );
  }
}
