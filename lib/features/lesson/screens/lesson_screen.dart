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
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/exercise/answer_action_bar.dart';
import '../../../shared/widgets/exercise/answer_slot_line.dart';
import '../../../shared/widgets/exercise/answer_tile.dart';
import '../../../shared/widgets/exercise/audio_play_button.dart';
import '../../../shared/widgets/exercise/exercise_layout.dart';
import '../../../shared/widgets/exercise/picture_tile.dart';
import '../picture_source.dart';
import '../prompt_parts.dart';
import '../state/lesson_controller.dart';
import '../widgets/answer_states.dart';
import '../widgets/exit_lesson_sheet.dart';
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
    _future = _startLesson();
  }

  /// "Try again" after a failed load starts over from the top.
  void _retryLoad() {
    setState(() {
      _future = _startLesson();
    });
  }

  Future<LessonContent> _startLesson() {
    return _loadLessonContent().then((content) {
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
      _loadPicturesEarly(content);
      return content;
    });
  }

  /// Starts loading every picture in [content] now, at the size its tile
  /// will ask for, so a picture question rarely shows one still arriving
  /// (019-image-choice-exercise-types, story 004).
  ///
  /// Nothing waits on it, and a failure is dropped: Flutter forgets a
  /// picture that failed, so its tile simply loads it again when shown. A
  /// downloaded pack's pictures are files, so they load from the device.
  void _loadPicturesEarly(LessonContent content) {
    if (!mounted) return;
    final sources = {
      for (final exercise in content.exercises)
        for (final picture in _picturesOf(exercise)) picture.imageUrl,
    };
    if (sources.isEmpty) return;
    // The answers span the screen less the page's side margins; a wrong
    // guess only means the tile loads its own copy, as it would anyway.
    final answersWidth =
        MediaQuery.sizeOf(context).width - AppSpacing.marginMobile * 2;
    final pictureSide = PictureTile.pictureSideFor(
      PictureGrid.tileWidthFor(answersWidth),
    );
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    for (final source in sources) {
      unawaited(
        precacheImage(
          PictureTile.decodedImage(
            pictureImageFor(source),
            pictureSide: pictureSide,
            devicePixelRatio: devicePixelRatio,
          ),
          context,
          onError: (_, _) {},
        ),
      );
    }
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
    // A cached copy streams its clips and pictures, which cannot load
    // offline -- only a downloaded pack carries them. Without such a
    // question the copy is as good as a pack.
    if (copy != null && !copy.exercises.any(_needsItsFiles)) {
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
    return FutureBuilder<LessonContent>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StatusPage(
            child: LoadingState(message: 'Loading lesson'),
          );
        }
        if (snapshot.hasError) {
          if (snapshot.error is LessonNotDownloadedOfflineException) {
            return const _StatusPage(child: _DownloadRequiredState());
          }
          return _StatusPage(
            child: ErrorState(
              title: "Couldn't load this lesson.",
              message: 'Check your connection and try again.',
              onRetry: _retryLoad,
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
    );
  }
}

/// A lesson that is not showing a question yet: loading, failed to load,
/// or offline without a download. Close leaves; nothing is lost yet.
class _StatusPage extends StatelessWidget {
  const _StatusPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      scrollable: false,
      padded: false,
      topBar: AppTopBar(
        leading: AppIconButton(
          icon: Icons.close,
          tooltip: 'Exit lesson',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: child,
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
    return EmptyState(
      icon: Icons.cloud_off,
      title: "You're offline",
      message: 'Download this lesson while online to take it offline.',
      action: AppButton.primary(
        label: 'Go back',
        expand: false,
        onPressed: () => Navigator.of(context).pop(),
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
      // page underneath rather than stale exercise content. Not a
      // spinner: an indeterminate one runs a never-ending animation, which
      // would keep `pumpAndSettle()` from ever settling for as long as the
      // modal/summary is showing on top.
      return const AppPage(scrollable: false, body: SizedBox.shrink());
    }

    if (controller.awaitingRetryIntro) {
      return _MistakeReview(controller: controller);
    }

    // Keyed by queue position, so each question (a requeued one too) gets
    // fresh state: its own scroll position and its own first play.
    return _LessonQuestion(
      key: ValueKey(controller.currentIndex),
      controller: controller,
      audioPlayer: audioPlayer,
    );
  }
}

/// The lesson's top bar, the same on every question and the mistake review.
ExerciseTopBar _topBarFor(BuildContext context, LessonController controller) {
  final total = controller.exercises.length;
  return ExerciseTopBar(
    // Goes through the lesson's PopScope, so part-way through it asks
    // before leaving, the same as the back gesture.
    onClose: () => Navigator.of(context).maybePop(),
    progress: ((controller.currentIndex + 1) / total).clamp(0.0, 1.0),
    beans: controller.usesBeans ? controller.beansRemaining : null,
    beansMax: controller.usesBeans ? controller.content.beansMax : null,
  );
}

/// Shown between exercises whenever the queue advances onto a previously
/// missed exercise (see `LessonController.awaitingRetryIntro`) -- a short
/// beat that names the mistake(s) before dropping the learner back into
/// them, rather than the requeued exercise just silently reappearing.
///
/// Laid out like the app's pop-ups ([SheetHero]), with the count on the
/// illustration so it is the first thing seen, and Continue docked where
/// every question's button sits.
class _MistakeReview extends StatelessWidget {
  const _MistakeReview({required this.controller});

  final LessonController controller;

  @override
  Widget build(BuildContext context) {
    final missedCount = controller.wrongCount;
    final noun = missedCount == 1 ? 'question' : 'questions';
    final pronoun = missedCount == 1 ? 'it' : 'them';

    return AppPage(
      scrollable: false,
      topBar: _topBarFor(context, controller),
      body: Center(
        child: SingleChildScrollView(
          child: SheetHero(
            illustration: const Icon(Icons.replay),
            illustrationBadge: CountBadge(
              label: missedCount == 1 ? '1 mistake' : '$missedCount mistakes',
              tone: AppTone.tertiary,
            ),
            tone: AppTone.tertiary,
            title: "Let's review your mistakes",
            body:
                'You missed $missedCount $noun earlier. '
                "Let's get $pronoun right this time!",
          ),
        ),
      ),
      bottomDock: [
        AppButton.primary(
          label: 'Continue',
          onPressed: controller.startRetryExercise,
        ),
      ],
    );
  }
}

/// Whether a question can only be played offline from a download: its clip
/// or its pictures are otherwise on the network (story 003 of intent 019
/// added both picture types).
bool _needsItsFiles(Exercise exercise) =>
    _clipOf(exercise) != null || _picturesOf(exercise).isNotEmpty;

/// A picture question's pictures; none for any other question.
List<PictureChoice> _picturesOf(Exercise exercise) => switch (exercise) {
  ImageChoiceExercise e => e.choices,
  AudioImageChoiceExercise e => e.choices,
  _ => const [],
};

/// The audio a question plays, if it has any. Every question with a clip
/// plays it once by itself when it appears.
String? _clipOf(Exercise exercise) => switch (exercise) {
  ListeningExercise e => e.audioUrl,
  AudioImageChoiceExercise e => e.audioUrl,
  _ => null,
};

/// One question, whatever its type, in the one frame: [ExerciseLayout]
/// with the lesson's top bar, the type's prompt and answers, and
/// [AnswerActionBar]. Each type only supplies its prompt and answers, so
/// the frame cannot drift between them.
class _LessonQuestion extends StatefulWidget {
  const _LessonQuestion({
    super.key,
    required this.controller,
    required this.audioPlayer,
  });

  final LessonController controller;
  final LessonAudioPlayer audioPlayer;

  @override
  State<_LessonQuestion> createState() => _LessonQuestionState();
}

class _LessonQuestionState extends State<_LessonQuestion> {
  /// Plays asked for (a tap, or the first play) whose clip has not
  /// started yet; the button shows "playing" while there are any.
  int _starting = 0;

  /// A Continue still being handled; a second tap meanwhile is ignored.
  bool _continuing = false;

  LessonController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final clip = _clipOf(_controller.currentExercise);
    // Not after a refill: the question comes back already answered.
    if (clip != null && !_controller.isChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play(clip);
      });
    }
  }

  Future<void> _play(String url) async {
    setState(() => _starting++);
    try {
      await widget.audioPlayer.play(url);
    } on Object {
      // Nothing to show: the learner can tap play again.
    } finally {
      if (mounted) setState(() => _starting--);
    }
  }

  Future<void> _continue() async {
    if (_continuing) return;
    _continuing = true;
    try {
      await _controller.continueToNext();
    } finally {
      _continuing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final exercise = controller.currentExercise;
    final topBar = _topBarFor(context, controller);
    final built = exercise is SentenceConstructionExercise
        ? controller.selectedAnswer as List<String>?
        : null;
    return ExerciseLayout(
      onClose: topBar.onClose,
      progress: topBar.progress,
      beans: topBar.beans,
      beansMax: topBar.beansMax,
      prompt: _promptFor(exercise),
      answers: _answersFor(exercise),
      actionBar: AnswerActionBar(
        grade: gradeOf(controller.feedback),
        // Only a built sentence needs Check: it has no single tap that
        // means "done". Every other type grades itself as it is answered
        // -- a choice on its tap, a match pair on its second tile.
        onCheck: exercise is SentenceConstructionExercise
            ? controller.check
            : null,
        canCheck: built != null && built.isNotEmpty,
        onContinue: _continue,
        notice: controller.completionError == null
            ? null
            : "Couldn't save your progress. Tap Continue to try again.",
      ),
    );
  }

  Widget _promptFor(Exercise exercise) {
    return switch (exercise) {
      MultipleChoiceExercise e => _choicePrompt(e),
      ListeningExercise e => _listenPrompt(
        splitPrompt(e.instruction),
        e.audioUrl,
      ),
      // The prompt already names the task ("Translate: 'I am fine'"); one
      // that does not gets a generic one, rather than a second
      // "Translate:" stacked in front of the prompt's own.
      SentenceConstructionExercise e => _questionPrompt(
        _translatePrompt(e.promptTranslation),
      ),
      MatchPairsExercise e => _questionPrompt(splitPrompt(e.prompt)),
      GapFillExercise e => _questionPrompt(splitPrompt(e.prompt)),
      ImageChoiceExercise e => _questionPrompt(splitPrompt(e.prompt)),
      // Only what to do: the word is heard, never written, even when the
      // prompt was written as "Instruction: 'word'".
      AudioImageChoiceExercise e => _listenPrompt(
        PromptParts(instruction: splitPrompt(e.instruction).instruction),
        e.audioUrl,
      ),
    };
  }

  /// The instruction above the large play button, for a question that is
  /// heard.
  Widget _listenPrompt(PromptParts parts, String audioUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _questionPrompt(parts),
        const SizedBox(height: AppSpacing.spaceLg),
        Center(
          child: AudioPlayButton(
            onPressed: () => _play(audioUrl),
            playing: _starting > 0,
          ),
        ),
        const SizedBox(height: AppSpacing.space2xs),
        Text(
          'Tap to play/replay',
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _answersFor(Exercise exercise) {
    final controller = _controller;
    return switch (exercise) {
      MultipleChoiceExercise e => _choices(e.options),
      ListeningExercise e => _choices(e.options),
      SentenceConstructionExercise e => WordBankBuilder(
        wordBank: e.wordBank,
        built: (controller.selectedAnswer as List<String>?) ?? const [],
        feedback: controller.feedback,
        onToggle: controller.toggleWordBankToken,
      ),
      MatchPairsExercise e => MatchPairsBuilder(
        leftTiles: e.leftTiles,
        rightTiles: e.rightTiles,
        matchedPairs: controller.matchedPairs,
        armedTileId: controller.armedTileId,
        armedIsLeft: controller.armedIsLeft,
        wrongPair: controller.wrongPair,
        onTileTap: controller.selectMatchPairsTile,
      ),
      GapFillExercise e => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnswerSlotLine.gap(
            before: e.sentenceBefore,
            after: e.sentenceAfter,
            options: e.options,
            filled: switch (controller.selectedAnswer) {
              final int chosen => e.options[chosen],
              _ => null,
            },
            grade: gradeOf(controller.feedback),
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          // Graded on the tap, like the other choice types: the chosen
          // word drops into the gap and the tile shows right or wrong.
          _choices(e.options),
        ],
      ),
      ImageChoiceExercise e => _pictures(e.choices),
      AudioImageChoiceExercise e => _pictures(e.choices),
    };
  }

  /// Full-width answer rows. Only the chosen one shows the grade, and none
  /// takes a tap once the question is graded.
  Widget _choices(List<String> options) {
    final controller = _controller;
    final chosen = controller.selectedAnswer as int?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
            child: AnswerTile(
              label: options[i],
              state: choiceStateOf(
                chosen: chosen == i,
                feedback: controller.feedback,
              ),
              onTap: controller.isChecked
                  ? null
                  : () => controller.chooseOption(i),
            ),
          ),
      ],
    );
  }

  /// The picture grid, graded like [_choices]: only the chosen picture
  /// shows the grade, and none takes a tap once the question is graded.
  Widget _pictures(List<PictureChoice> choices) {
    final controller = _controller;
    final chosen = controller.selectedAnswer as int?;
    return PictureGrid(
      children: [
        for (var i = 0; i < choices.length; i++)
          PictureTile(
            image: pictureImageFor(choices[i].imageUrl),
            altText: choices[i].altText,
            state: choiceStateOf(
              chosen: chosen == i,
              feedback: controller.feedback,
            ),
            onTap: controller.isChecked
                ? null
                : () => controller.chooseOption(i),
          ),
      ],
    );
  }
}

/// A bare word with a gloss (the fake's "ቡና" with "What does this word
/// mean?") asks the gloss and shows the word as the question. Anything else
/// is split like every other prompt, with a gloss as its translation.
Widget _choicePrompt(MultipleChoiceExercise exercise) {
  final parts = splitPrompt(exercise.prompt);
  final gloss = exercise.promptTranslation.trim();
  if (parts.content == null && gloss.isNotEmpty) {
    return QuestionPrompt(instruction: gloss, question: parts.instruction);
  }
  return QuestionPrompt(
    instruction: parts.instruction,
    question: parts.content,
    translation: gloss.isEmpty ? null : gloss,
  );
}

Widget _questionPrompt(PromptParts parts) =>
    QuestionPrompt(instruction: parts.instruction, question: parts.content);

PromptParts _translatePrompt(String prompt) {
  final parts = splitPrompt(prompt);
  if (parts.content != null) return parts;
  return PromptParts(instruction: 'Translate this sentence', content: prompt);
}
