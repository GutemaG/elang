import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/models/exercise.dart';
import '../../../shared/models/lesson_content.dart';
import '../../../shared/models/skill_lesson_progress.dart';
import '../../../shared/services/answer_feedback_player.dart';
import '../../../shared/services/connectivity_monitor.dart';
import '../../../shared/services/course_cache_store.dart';
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
import '../widgets/exercise_prompt_header.dart';
import '../widgets/exit_lesson_sheet.dart';
import '../widgets/gap_sentence.dart';
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
    this.lessonCache,
    this.skillVersion,
    this.beansNow,
    this.isReview = false,
    this.skillProgress,
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
       lessonPackStore = null,
       lessonCache = null,
       skillVersion = null,
       beansNow = null,
       isReview = false,
       skillProgress = null;

  final String lessonId;
  final LessonApi lessonApi;
  final LessonAudioPlayer audioPlayer;
  final AnswerFeedbackPlayer feedbackPlayer;
  final ConnectivityMonitor? connectivityMonitor;
  final LessonPackStore? lessonPackStore;
  final SyncEngine syncEngine;
  final LessonContent? practiceContent;
  final Map<String, String>? practiceVocabItemIdByExerciseId;

  /// The last fetched copy of each lesson. When set, a lesson opened before
  /// starts from its copy at once and the copy is refreshed in the
  /// background; `null` always fetches.
  final CourseCacheStore? lessonCache;

  /// The tapped node's `contentVersion`. A cached copy saved under a
  /// different version is stale and is not played.
  final DateTime? skillVersion;

  /// The beans balance the dashboard is showing. A cached copy's own
  /// `beansAtStart` is from whenever it was fetched, so this replaces it.
  /// The server recomputes beans on completion either way; this only drives
  /// the local out-of-beans prompt.
  final int? beansNow;

  /// Replaying a skill already completed: see `LessonController.isReview`.
  final bool isReview;

  /// Which lesson of its skill this is, passed on to the summary so it can
  /// say how many lessons are left; `null` shows nothing there (see
  /// [SkillLessonProgress.forNode]).
  final SkillLessonProgress? skillProgress;

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
        isReview: widget.isReview,
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
    final copy = await _cachedCopy();
    if (online) {
      if (copy != null) {
        unawaited(_fetchAndCache().then<void>((_) {}, onError: (Object _) {}));
        return _withCurrentBeans(copy);
      }
      return _fetchAndCache();
    }
    final pack = await widget.lessonPackStore!.load(widget.lessonId);
    if (pack != null) return pack;
    // A cached copy streams its audio, which cannot play offline -- only a
    // downloaded pack carries the clips. Without listening exercises the
    // copy is as good as a pack.
    if (copy != null && !copy.exercises.any((e) => e is ListeningExercise)) {
      return _withCurrentBeans(copy);
    }
    throw const LessonNotDownloadedOfflineException();
  }

  /// This lesson's cached copy, if there is one and it is still current.
  Future<LessonContent?> _cachedCopy() async {
    final cache = widget.lessonCache;
    if (cache == null) return null;
    try {
      final cached = await cache.loadLesson(widget.lessonId);
      if (cached == null || !cached.isFreshFor(widget.skillVersion)) {
        return null;
      }
      return cached.content;
    } on Object {
      return null;
    }
  }

  Future<LessonContent> _fetchAndCache() async {
    final content = await widget.lessonApi.startLesson(widget.lessonId);
    try {
      await widget.lessonCache?.saveLesson(
        content,
        skillVersion: widget.skillVersion,
      );
    } on Object {
      // No copy just means the next open fetches again.
    }
    return content;
  }

  LessonContent _withCurrentBeans(LessonContent content) {
    final beans = widget.beansNow;
    if (beans == null) return content;
    return LessonContent(
      lessonId: content.lessonId,
      skillId: content.skillId,
      title: content.title,
      exercises: content.exercises,
      beansAtStart: beans.clamp(0, content.beansMax),
      beansMax: content.beansMax,
      contentVersion: content.contentVersion,
      unrenderableCount: content.unrenderableCount,
    );
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
        builder: (_) => LessonCompleteScreen(
          result: controller.completionResult!,
          skillProgress: widget.skillProgress,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  /// Part-way through: exercises on screen, not yet finished, and not
  /// stopped by the out-of-beans prompt (which has its own way out).
  bool get _midLesson {
    final controller = _controller;
    return controller != null &&
        !controller.lessonFinished &&
        !controller.lessonInterrupted;
  }

  /// Back gesture, back button or the close button, part-way through:
  /// asks first, because nothing is saved until the lesson is finished.
  Future<void> _confirmExit() async {
    final leave = await showModalBottomSheet<bool>(
      context: context,
      // Sized to its content, not capped at the default 9/16 of the screen,
      // so it fits on a short phone.
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (_) => ExitLessonSheet(isPractice: widget.isPractice),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
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
              // Inside the builder so `canPop` follows the controller: once
              // the lesson is finished or out of beans, back just goes back.
              builder: (context, _) => PopScope(
                canPop: !_midLesson,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _confirmExit();
                },
                child: _ExerciseBody(
                  controller: _controller!,
                  audioPlayer: widget.audioPlayer,
                ),
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
              style: AppTypography.bodySm.copyWith(
                color: AppColors.tertiaryBrand,
              ),
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
                  colors: [
                    AppColors.tertiaryBrand,
                    AppColors.tertiaryContainer,
                  ],
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
        // Goes through the lesson's PopScope, so part-way through it asks
        // before leaving, the same as the back gesture.
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
          tooltip: 'Exit lesson',
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: AppSpacing.space2xs),
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
        if (controller.usesBeans) ...[
          const SizedBox(width: AppSpacing.spaceSm),
          Semantics(
            label: '${controller.beansRemaining} beans remaining',
            child: Row(
              children: [
                const Icon(
                  Icons.favorite,
                  color: AppColors.tertiaryBrand,
                  size: 18,
                ),
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
      MatchPairsExercise e => _MatchPairsBody(
        exercise: e,
        controller: controller,
      ),
      GapFillExercise e => _GapFillBody(exercise: e, controller: controller),
    };
  }
}

class _GapFillBody extends StatelessWidget {
  const _GapFillBody({required this.exercise, required this.controller});

  final GapFillExercise exercise;
  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedAnswer as int?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExercisePromptHeader(parts: splitPrompt(exercise.prompt)),
        const SizedBox(height: AppSpacing.spaceMd),
        GapSentence(
          before: exercise.sentenceBefore,
          after: exercise.sentenceAfter,
          options: exercise.options,
          filled: selected == null ? null : exercise.options[selected],
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
              // Graded on the tap, like the other choice types: the chosen
              // word drops into the gap and the tile shows right or wrong.
              onTap: controller.isChecked
                  ? null
                  : () => controller.chooseOption(i),
            ),
          ),
      ],
    );
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
                  : () => controller.chooseOption(i),
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
                  : () => controller.chooseOption(i),
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
        // The prompt already names the task ("Translate: 'I am fine'"); one
        // that does not gets a generic one, rather than a second
        // "Translate:" stacked in front of the prompt's own.
        ExercisePromptHeader(
          parts: _translatePrompt(exercise.promptTranslation),
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

PromptParts _translatePrompt(String prompt) {
  final parts = splitPrompt(prompt);
  if (parts.content != null) return parts;
  return PromptParts(instruction: 'Translate this sentence', content: prompt);
}

class _MatchPairsBody extends StatelessWidget {
  const _MatchPairsBody({required this.exercise, required this.controller});

  final MatchPairsExercise exercise;
  final LessonController controller;

  @override
  Widget build(BuildContext context) {
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
          matchedPairs: controller.matchedPairs,
          armedTileId: controller.armedTileId,
          armedIsLeft: controller.armedIsLeft,
          wrongPair: controller.wrongPair,
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
      // Only a built sentence needs Check: it has no single tap that means
      // "done". Every other type grades itself as it is answered -- a
      // choice on its tap, a match pair on its second tile.
      if (controller.currentExercise is SentenceConstructionExercise) {
        final built = controller.selectedAnswer as List<String>?;
        return TactileButton(
          label: 'Check',
          onPressed: built != null && built.isNotEmpty
              ? controller.check
              : null,
        );
      }
      // Holds the button's place so the exercise does not jump when
      // Continue appears.
      return const ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: TactileButton(label: '', onPressed: null),
          ),
        ),
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
