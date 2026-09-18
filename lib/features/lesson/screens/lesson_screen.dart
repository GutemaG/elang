import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/models/exercise.dart';
import '../../../shared/models/lesson_content.dart';
import '../../../shared/services/answer_feedback_player.dart';
import '../../../shared/services/connectivity_monitor.dart';
import '../../../shared/services/lesson_api.dart';
import '../../../shared/services/lesson_audio_player.dart';
import '../../../shared/services/lesson_pack_store.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';
import '../state/lesson_controller.dart';
import '../widgets/choice_tile.dart';
import '../widgets/match_pairs_builder.dart';
import '../widgets/out_of_beans_sheet.dart';
import '../widgets/word_bank_builder.dart';
import 'lesson_complete_screen.dart';

/// Thrown by [LessonScreen]'s content loader when the device is offline
/// and this lesson was never downloaded (009-offline-caching-and-sync-ui,
/// story 002's "download required" edge case).
class LessonNotDownloadedOfflineException implements Exception {
  const LessonNotDownloadedOfflineException();
}

/// Story 002's lesson exercise screen — hosts all 3 exercise types
/// (multiple-choice, listening, sentence-construction) against a single
/// [LessonContent] payload fetched once at lesson start.
///
/// Also owns triggering story 003's out-of-beans modal (the instant local
/// beans hit 0) and handing off to story 004's lesson-complete screen once
/// the last exercise is answered.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.lessonId,
    required this.lessonApi,
    required this.audioPlayer,
    required this.feedbackPlayer,
    required this.connectivityMonitor,
    required this.lessonPackStore,
    required this.syncEngine,
  }) : practiceContent = null,
       practiceVocabItemIdByExerciseId = null;

  /// Bolt 020 (008-srs-and-practice): launches a Practice session instead
  /// of a regular lesson. [practiceContent] is pre-assembled from due
  /// items (no `startLesson` fetch-by-id) and [practiceVocabItemIdByExerciseId]
  /// resolves each of its exercises back to the vocab item it tests, for
  /// completion reporting. Beans/offline-pack machinery is bypassed
  /// entirely -- Practice is online-only (FR-5) and has no mistake-
  /// tolerance gating -- so [connectivityMonitor]/[lessonPackStore] are
  /// not needed here.
  const LessonScreen.practice({
    super.key,
    required this.practiceContent,
    required this.practiceVocabItemIdByExerciseId,
    required this.lessonApi,
    required this.audioPlayer,
    required this.feedbackPlayer,
    required this.syncEngine,
  }) : lessonId = '',
       connectivityMonitor = null,
       lessonPackStore = null;

  final String lessonId;
  final LessonApi lessonApi;
  final LessonAudioPlayer audioPlayer;
  final AnswerFeedbackPlayer feedbackPlayer;
  final ConnectivityMonitor? connectivityMonitor;
  final LessonPackStore? lessonPackStore;
  final SyncEngine syncEngine;
  final LessonContent? practiceContent;
  final Map<String, String>? practiceVocabItemIdByExerciseId;

  bool get isPractice => practiceContent != null;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late Future<LessonContent> _future;
  LessonController? _controller;
  bool _outOfBeansModalShown = false;

  /// The online/offline decision made once at load time by
  /// [_loadLessonContent] -- threaded into [LessonController] and never
  /// re-checked at completion time (see that controller's `startedOffline`
  /// doc comment).
  bool _startedOffline = false;

  @override
  void initState() {
    super.initState();
    _future = _loadLessonContent().then((content) {
      final controller = LessonController(
        lessonApi: widget.lessonApi,
        feedbackPlayer: widget.feedbackPlayer,
        syncEngine: widget.syncEngine,
        content: content,
        startedOffline: _startedOffline,
        isPractice: widget.isPractice,
        vocabItemIdByExerciseId: widget.practiceVocabItemIdByExerciseId,
      );
      controller.addListener(_onControllerChanged);
      _controller = controller;
      return content;
    });
  }

  /// Practice -> the pre-assembled [LessonScreen.practiceContent], no
  /// fetch at all (never offline, per FR-5). Regular lesson, online ->
  /// unchanged (fetches from `001-lesson-service`). Regular lesson,
  /// offline -> falls back to a downloaded pack
  /// (009-offline-caching-and-sync-ui, story 002); throws
  /// [LessonNotDownloadedOfflineException] if this lesson was never
  /// downloaded, so the screen can show a distinct "download this lesson
  /// first" state instead of a generic error.
  Future<LessonContent> _loadLessonContent() async {
    final practiceContent = widget.practiceContent;
    if (practiceContent != null) {
      _startedOffline = false;
      return practiceContent;
    }
    final online = await widget.connectivityMonitor!.isOnline();
    _startedOffline = !online;
    if (online) {
      return widget.lessonApi.startLesson(widget.lessonId);
    }
    final cached = await widget.lessonPackStore!.load(widget.lessonId);
    if (cached == null) {
      throw const LessonNotDownloadedOfflineException();
    }
    return cached;
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.lessonInterrupted && !_outOfBeansModalShown) {
      _outOfBeansModalShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOutOfBeans());
    }
    if (controller.lessonFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToSummary());
    }
    if (mounted) setState(() {});
  }

  Future<void> _showOutOfBeans() async {
    if (!mounted) return;
    final status = await widget.lessonApi.getBeansStatus();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (sheetContext) => OutOfBeansSheet(
        status: status,
        onRefill: () => _handleRefill(sheetContext),
        onDismiss: () => _handleDismiss(sheetContext),
      ),
    );
  }

  Future<void> _handleRefill(BuildContext sheetContext) async {
    final result = await widget.lessonApi.refillBeansWithAmole();
    if (!sheetContext.mounted) return;
    if (result is RefillSuccess) {
      _controller?.resumeAfterRefill(result.newBeans);
      _outOfBeansModalShown = false;
      Navigator.of(sheetContext).pop();
    }
    // RefillFailure shouldn't normally be reachable — the sheet disables
    // the refill action when the account can't afford it (story 003's
    // edge case) — but if it is, the sheet just stays open rather than
    // failing silently.
  }

  void _handleDismiss(BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context).pop();
  }

  void _goToSummary() {
    final controller = _controller;
    if (controller == null || controller.completionResult == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            LessonCompleteScreen(result: controller.completionResult!),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<LessonContent>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              if (snapshot.error is LessonNotDownloadedOfflineException) {
                return const _DownloadRequiredState();
              }
              return Center(
                child: Text(
                  "Couldn't load this lesson.",
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              );
            }
            return AnimatedBuilder(
              animation: _controller!,
              builder: (context, _) => _ExerciseBody(
                controller: _controller!,
                audioPlayer: widget.audioPlayer,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shown when the device is offline and this lesson was never downloaded
/// (009-offline-caching-and-sync-ui, story 002's edge case) -- a clear,
/// actionable state rather than a generic error or an indefinite spinner.
class _DownloadRequiredState extends StatelessWidget {
  const _DownloadRequiredState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 40,
              color: AppColors.tertiaryBrand,
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              "You're offline",
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.space2xs),
            Text(
              'Download this lesson while online to take it offline.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceMd),
            TactileButton(
              label: 'Go back',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseBody extends StatelessWidget {
  const _ExerciseBody({required this.controller, required this.audioPlayer});

  final LessonController controller;
  final LessonAudioPlayer audioPlayer;

  @override
  Widget build(BuildContext context) {
    if (controller.lessonInterrupted || controller.lessonFinished) {
      // Out-of-beans modal / navigation to the summary is already in
      // flight (triggered by the controller listener) — render an inert
      // placeholder underneath rather than stale exercise content. Not a
      // spinner: an indeterminate `CircularProgressIndicator` runs a
      // never-ending animation, which would keep `pumpAndSettle()` from
      // ever settling for as long as the modal/summary is showing on top.
      return const SizedBox.shrink();
    }

    if (controller.awaitingRetryIntro) {
      return _MistakeReviewCard(controller: controller);
    }

    final exercise = controller.currentExercise;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.spaceSm),
          _ProgressHeader(controller: controller),
          const SizedBox(height: AppSpacing.spaceLg),
          Expanded(
            child: SingleChildScrollView(
              child: _ExercisePrompt(
                exercise: exercise,
                controller: controller,
                audioPlayer: audioPlayer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          if (controller.completionError != null) ...[
            Text(
              "Couldn't save your progress. Tap Continue to try again.",
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: AppColors.tertiaryBrand),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
          ],
          _ActionBar(controller: controller),
          const SizedBox(height: AppSpacing.spaceMd),
        ],
      ),
    );
  }
}

/// Shown between exercises whenever the queue advances onto a previously
/// missed exercise (see `LessonController.awaitingRetryIntro`) -- a short
/// beat that names the mistake(s) before dropping the learner back into
/// them, rather than the requeued exercise just silently reappearing.
class _MistakeReviewCard extends StatelessWidget {
  const _MistakeReviewCard({required this.controller});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final missedCount = controller.wrongCount;
    final noun = missedCount == 1 ? 'question' : 'questions';
    final pronoun = missedCount == 1 ? 'it' : 'them';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MistakeBadge(count: missedCount),
            const SizedBox(height: AppSpacing.spaceLg),
            Text(
              "Let's review your mistakes",
              textAlign: TextAlign.center,
              style: AppTypography.headlineLg.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.space2xs),
            Text(
              'You missed $missedCount $noun earlier. '
              "Let's get $pronoun right this time!",
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),
            TactileButton(
              label: 'Continue',
              onPressed: controller.startRetryExercise,
            ),
          ],
        ),
      ),
    );
  }
}

/// The [_MistakeReviewCard]'s illustration: a soft terracotta halo behind a
/// gradient "retry" badge, with the actual missed-question count pinned
/// to its corner -- so the number the copy quotes is also the first thing
/// the learner sees, not just read in a sentence.
class _MistakeBadge extends StatelessWidget {
  const _MistakeBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tertiaryFixed,
            ),
          ),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.tertiaryBrand, AppColors.tertiaryContainer],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tertiaryBevel.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.replay,
                size: 44,
                color: AppColors.onTertiary,
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryContainer,
                border: Border.all(color: AppColors.background, width: 3),
              ),
              child: Text(
                '$count',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.controller});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final total = controller.exercises.length;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: LinearProgressIndicator(
              value: ((controller.currentIndex + 1) / total).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainer,
              valueColor: const AlwaysStoppedAnimation(
                AppColors.primaryContainer,
              ),
            ),
          ),
        ),
        if (!controller.isPractice) ...[
          const SizedBox(width: AppSpacing.spaceSm),
          Semantics(
            label: '${controller.beansRemaining} beans remaining',
            child: Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.tertiaryBrand, size: 18),
                const SizedBox(width: 2),
                Text(
                  '${controller.beansRemaining}',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.tertiaryBrand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ExercisePrompt extends StatelessWidget {
  const _ExercisePrompt({
    required this.exercise,
    required this.controller,
    required this.audioPlayer,
  });

  final Exercise exercise;
  final LessonController controller;
  final LessonAudioPlayer audioPlayer;

  @override
  Widget build(BuildContext context) {
    return switch (exercise) {
      MultipleChoiceExercise e => _MultipleChoiceBody(
        exercise: e,
        controller: controller,
      ),
      ListeningExercise e => _ListeningBody(
        exercise: e,
        controller: controller,
        audioPlayer: audioPlayer,
      ),
      SentenceConstructionExercise e => _SentenceConstructionBody(
        exercise: e,
        controller: controller,
      ),
      MatchPairsExercise e => _MatchPairsBody(exercise: e, controller: controller),
    };
  }
}

class _MultipleChoiceBody extends StatelessWidget {
  const _MultipleChoiceBody({required this.exercise, required this.controller});

  final MultipleChoiceExercise exercise;
  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedAnswer as int?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          exercise.prompt,
          style: AppTypography.displayLgMobile.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.space2xs),
        Text(
          exercise.promptTranslation,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        for (int i = 0; i < exercise.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
            child: ChoiceTile(
              label: exercise.options[i],
              selected: selected == i,
              feedback: controller.isChecked
                  ? controller.feedback
                  : TileFeedback.none,
              onTap: controller.isChecked
                  ? null
                  : () => controller.selectOption(i),
            ),
          ),
      ],
    );
  }
}

class _ListeningBody extends StatelessWidget {
  const _ListeningBody({
    required this.exercise,
    required this.controller,
    required this.audioPlayer,
  });

  final ListeningExercise exercise;
  final LessonController controller;
  final LessonAudioPlayer audioPlayer;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedAnswer as int?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          exercise.instruction,
          style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        Center(
          child: InkWell(
            onTap: () => audioPlayer.play(exercise.audioUrl),
            customBorder: const CircleBorder(),
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer,
              ),
              child: const Icon(
                Icons.volume_up,
                color: AppColors.onPrimary,
                size: 36,
              ),
            ),
          ),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: AppSpacing.space2xs),
            child: Text(
              'Tap to play/replay',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        for (int i = 0; i < exercise.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
            child: ChoiceTile(
              label: exercise.options[i],
              selected: selected == i,
              feedback: controller.isChecked
                  ? controller.feedback
                  : TileFeedback.none,
              onTap: controller.isChecked
                  ? null
                  : () => controller.selectOption(i),
            ),
          ),
      ],
    );
  }
}

class _SentenceConstructionBody extends StatelessWidget {
  const _SentenceConstructionBody({
    required this.exercise,
    required this.controller,
  });

  final SentenceConstructionExercise exercise;
  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final built = (controller.selectedAnswer as List<String>?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Translate: "${exercise.promptTranslation}"',
          style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        WordBankBuilder(
          wordBank: exercise.wordBank,
          built: built,
          feedback: controller.isChecked
              ? controller.feedback
              : TileFeedback.none,
          onToggle: controller.toggleWordBankToken,
        ),
      ],
    );
  }
}

class _MatchPairsBody extends StatelessWidget {
  const _MatchPairsBody({required this.exercise, required this.controller});

  final MatchPairsExercise exercise;
  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final pairs = (controller.selectedAnswer as Map<String, String>?) ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          exercise.prompt,
          style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        MatchPairsBuilder(
          leftTiles: exercise.leftTiles,
          rightTiles: exercise.rightTiles,
          pairs: pairs,
          armedLeftTileId: controller.armedLeftTileId,
          feedback: controller.isChecked ? controller.feedback : TileFeedback.none,
          onTileTap: controller.selectMatchPairsTile,
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.controller});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.isChecked) {
      final hasAnswer = controller.selectedAnswer != null;
      final currentExercise = controller.currentExercise;
      final ready = switch (currentExercise) {
        SentenceConstructionExercise _ =>
          hasAnswer && (controller.selectedAnswer as List<String>).isNotEmpty,
        MatchPairsExercise e =>
          hasAnswer &&
              (controller.selectedAnswer as Map<String, String>).length ==
                  e.leftTiles.length,
        MultipleChoiceExercise _ || ListeningExercise _ => hasAnswer,
      };
      return TactileButton(
        label: 'Check',
        onPressed: ready ? controller.check : null,
      );
    }
    final correct = controller.feedback == TileFeedback.correct;
    return TactileButton(
      label: 'Continue',
      onPressed: controller.continueToNext,
      backgroundColor: correct
          ? AppColors.primaryContainer
          : AppColors.tertiaryBrand,
      bevelColor: correct ? AppColors.primaryBevel : AppColors.tertiaryBevel,
    );
  }
}
