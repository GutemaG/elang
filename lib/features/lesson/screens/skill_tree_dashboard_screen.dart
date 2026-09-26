import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/lesson_content.dart';
import '../../../shared/models/skill_lesson_progress.dart';
import '../../../shared/models/skill_tree.dart';
import '../../../shared/services/answer_feedback_player.dart';
import '../../../shared/services/connectivity_monitor.dart';
import '../../../shared/services/course_api.dart';
import '../../../shared/services/lesson_api.dart';
import '../../../shared/services/lesson_api_exception.dart';
import '../../../shared/services/lesson_audio_player.dart';
import '../../../shared/services/lesson_pack_downloader.dart';
import '../../../shared/services/lesson_pack_store.dart';
import '../../../shared/services/session_api.dart';
import '../../../shared/services/session_repository.dart';
import '../../../shared/services/sound_preference_repository.dart';
import '../../../shared/services/course_cache_store.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/services/user_preferences_api.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';
import '../../auth/auth_routes.dart';
import '../../courses/course_badge.dart';
import '../../courses/course_panel.dart';
import '../../courses/course_picker.dart';
import '../../courses/course_rail_source.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/category_banner.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/lesson_hud.dart';
import '../widgets/pinned_header_sliver.dart';
import '../widgets/review_skill_sheet.dart';
import '../widgets/skill_path_node.dart';
import '../widgets/sync_status_banner.dart';
import 'download_management_screen.dart';
import 'lesson_screen.dart';

/// Story 001's skill-tree home dashboard — maps to
/// `4._home_skill_tree_dashboard/`. This is the new post-sign-in
/// destination, replacing `HomePlaceholderScreen` (wired in
/// `AuthRoutes`/`main.dart`, not here).
///
/// Fetches the skill tree once on load (and again whenever a lesson
/// screen is popped back to this one, so a completed lesson's updated
/// node state is visible without a manual refresh).
///
/// Cache first: the active course's saved copy is on screen as soon as it
/// is read from the device, and the network result replaces it when it
/// arrives. The learner only ever waits on a course never opened here.
class SkillTreeDashboardScreen extends StatefulWidget {
  const SkillTreeDashboardScreen({
    super.key,
    required this.lessonApi,
    required this.audioPlayer,
    required this.feedbackPlayer,
    required this.connectivityMonitor,
    required this.lessonPackStore,
    required this.lessonPackDownloader,
    required this.syncEngine,
    required this.courseApi,
    required this.sessionRepository,
    required this.userPreferencesApi,
    required this.soundPreferenceRepository,
    this.courseCache,
  });

  final LessonApi lessonApi;

  /// Per-course offline copy of the dashboard (010-multi-language-courses,
  /// story 003). When set, every successful load is saved, and a failed load
  /// falls back to the active course's saved copy. `null` disables caching.
  final CourseCacheStore? courseCache;

  /// The course list and switching (010-multi-language-courses): opened from
  /// the course chip, and threaded down to Settings.
  final CourseApi courseApi;
  final LessonAudioPlayer audioPlayer;
  final AnswerFeedbackPlayer feedbackPlayer;
  final ConnectivityMonitor connectivityMonitor;
  final LessonPackStore lessonPackStore;
  final LessonPackDownloader lessonPackDownloader;
  final SyncEngine syncEngine;

  /// Threaded down to build [SettingsScreen] on tap, and cleared when the
  /// server says the session is no longer valid (see [_SignedOutState]).
  final SessionRepository sessionRepository;
  final UserPreferencesApi userPreferencesApi;
  final SoundPreferenceRepository soundPreferenceRepository;

  @override
  State<SkillTreeDashboardScreen> createState() =>
      _SkillTreeDashboardScreenState();
}

/// Bolt 018-amole-ui: `GET /api/v1/skill-tree` carries no Amole field
/// (that's `GET /api/v1/beans`, already called elsewhere by
/// `LessonScreen`'s out-of-Beans modal) -- so the dashboard combines both
/// fetches here rather than reusing a single existing one.
class _DashboardData {
  const _DashboardData({
    required this.tree,
    required this.beansStatus,
    required this.dueCount,
    this.fromCache = false,
  });

  final SkillTreeResponse tree;
  final BeansStatus beansStatus;
  final int dueCount;

  /// True when the network failed and this is the saved copy of the course.
  final bool fromCache;

  /// The same data shown while a refresh is still in flight -- not yet
  /// known to be offline, so without the offline note.
  _DashboardData get whileRefreshing =>
      _DashboardData(tree: tree, beansStatus: beansStatus, dueCount: dueCount);
}

/// How many lessons one dashboard load may fetch ahead of a tap. Each is two
/// requests, and every copy fetched stays until its skill changes, so a
/// small number per load still ends with every open lesson on the device.
const _prefetchPerLoad = 4;

class _SkillTreeDashboardScreenState extends State<SkillTreeDashboardScreen> {
  late Future<_DashboardData> _future;

  /// Owned here so a course change can animate back to the top rather than
  /// leaving the learner mid-tree in a course they just left
  /// (011-dashboard-ui-polish, story 002).
  final ScrollController _scrollController = ScrollController();

  /// The last dashboard that loaded, shown while a *re*load is in flight.
  ///
  /// Without it every reload swaps the scroll view for a spinner, which
  /// detaches the scroll position and drops the learner back at the top of
  /// the tree on the way back from a lesson. `null` only before the first
  /// successful load, which is when a spinner is the right answer.
  _DashboardData? _lastData;

  /// Whether the course panel is dropped from the badge
  /// (011-dashboard-ui-polish, story 003).
  bool _panelOpen = false;

  /// Whether the panel is in the tree at all. It outlives [_panelOpen] by the
  /// length of the closing animation and is then removed, so a closed panel
  /// is not merely invisible -- it is gone, and a screen reader cannot reach
  /// rows the learner cannot see.
  bool _panelMounted = false;

  /// The rail's courses, loaded the first time the panel opens and dropped
  /// after a switch so the next open reflects the new active course. `null`
  /// means "never loaded", which is why the panel is not built before then.
  Future<List<Course>>? _railFuture;

  /// The sync queue depth last seen, so a drain can be told from a new
  /// entry (see [_onSyncChanged]).
  int _pendingSeen = 0;

  bool _prefetching = false;

  /// The section the fixed header shows: the last one whose divider has
  /// scrolled under the header (020-dashboard-section-header, FR-2).
  int _section = 0;

  /// Which way the jump button points, or `null` while the learner's
  /// current lesson is in view and the button is hidden (FR-4).
  AxisDirection? _jumpTo;

  /// Everything pinned at the top: the stats bar plus the section header.
  /// A path element under this is hidden behind them.
  double _pinnedExtent = 0;

  /// One key per section divider (sections 1 onwards), for finding where
  /// each section begins in the scroll.
  final Map<int, GlobalKey> _dividerKeys = {};

  /// The section holding the active node, and the node itself, for the
  /// jump button.
  final GlobalKey _activeSectionKey = GlobalKey();
  final GlobalKey _activeNodeKey = GlobalKey();

  /// The index of the section holding the active node; -1 when none.
  int _activeSection = -1;

  GlobalKey _dividerKey(int index) =>
      _dividerKeys.putIfAbsent(index, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _pendingSeen = widget.syncEngine.pendingCount;
    widget.syncEngine.addListener(_onSyncChanged);
    _future = _load();
    // So a previously-downloaded pack shows as downloaded immediately,
    // without the user re-tapping the download affordance.
    unawaited(widget.lessonPackDownloader.refreshDownloadedStatuses());
    // Drains any entries queued from a previous session -- the "survives
    // app restart" durability requirement (010-offline-caching-and-
    // sync-ui, story 003).
    unawaited(widget.syncEngine.refresh());
  }

  @override
  void dispose() {
    widget.syncEngine.removeListener(_onSyncChanged);
    _scrollController.dispose();
    super.dispose();
  }

  /// Offline completions reaching the server change XP, streak and crowns,
  /// so the tree is reloaded once the queue shrinks.
  void _onSyncChanged() {
    final pending = widget.syncEngine.pendingCount;
    final drained = pending < _pendingSeen;
    _pendingSeen = pending;
    if (drained && mounted) _reload();
  }

  Future<_DashboardData> _load() async {
    // The saved copy goes up first, so opening the app or switching course
    // never waits on the network. Only when it is a different course from
    // what is showing: after a lesson, the tree already on screen is newer.
    final cached = await _loadFromCache();
    final shownCourse = _lastData?.tree.course?.id;
    if (cached != null &&
        mounted &&
        (shownCourse == null || shownCourse != cached.tree.course?.id)) {
      setState(() => _lastData = cached.whileRefreshing);
    }

    // An offline course choice is sent first, so the tree fetched below is
    // the course the learner picked.
    await widget.courseApi.syncPendingSwitch();
    try {
      final results = await Future.wait([
        widget.lessonApi.getSkillTree(),
        widget.lessonApi.getBeansStatus(),
        widget.lessonApi.getDueCount(),
      ]);
      final data = _DashboardData(
        tree: results[0] as SkillTreeResponse,
        beansStatus: results[1] as BeansStatus,
        dueCount: results[2] as int,
      );
      widget.lessonPackDownloader.currentCourse = data.tree.course;
      unawaited(_saveToCache(data));
      unawaited(_prefetchLessons(data.tree));
      _lastData = data;
      return data;
    } on LessonApiException catch (e) {
      // A backend answer (e.g. an expired session) is not "offline".
      if (e.errorCode != null) rethrow;
      if (cached == null) rethrow;
      _lastData = cached;
      return cached;
    }
  }

  /// Fetches the lessons the learner can open and keeps a copy of each, so a
  /// tap starts the lesson at once. The next thing to learn goes first.
  /// Copies still current for their skill are skipped, so this settles to
  /// nothing once the device has them all.
  Future<void> _prefetchLessons(SkillTreeResponse tree) async {
    final cache = widget.courseCache;
    if (cache == null || _prefetching) return;
    _prefetching = true;
    try {
      final open = [
        ...tree.nodes.where((n) => n.state == SkillNodeState.active),
        ...tree.nodes.where((n) => n.state == SkillNodeState.completed),
      ];
      var fetched = 0;
      for (final node in open) {
        if (fetched >= _prefetchPerLoad || !mounted) return;
        final cached = await cache.loadLesson(node.lessonId);
        if (cached != null && cached.isFreshFor(node.contentVersion)) continue;
        fetched++;
        try {
          final content = await widget.lessonApi.startLesson(node.lessonId);
          await cache.saveLesson(content, skillVersion: node.contentVersion);
        } on Object {
          // Offline or refused: this lesson just fetches when tapped.
        }
      }
    } on Object {
      // A prefetch is an optimisation; nothing depends on it finishing.
    } finally {
      _prefetching = false;
    }
  }

  Future<void> _saveToCache(_DashboardData data) async {
    final cache = widget.courseCache;
    final course = data.tree.course;
    if (cache == null || course == null) return;
    try {
      await cache.saveDashboard(
        course.id,
        data.tree,
        amoleBalance: data.beansStatus.amoleBalance,
        dueCount: data.dueCount,
      );
      await cache.setActiveCourseId(course.id);
    } on Object {
      // No offline copy is better than a broken dashboard.
    }
  }

  Future<_DashboardData?> _loadFromCache() async {
    final cache = widget.courseCache;
    if (cache == null) return null;
    try {
      final courseId = await cache.activeCourseId();
      if (courseId == null) return null;
      final cached = await cache.loadDashboard(courseId);
      if (cached == null) return null;
      final tree = cached.tree;
      widget.lessonPackDownloader.currentCourse = tree.course;
      return _DashboardData(
        tree: tree,
        beansStatus: BeansStatus(
          beans: tree.beans,
          beansMax: tree.beansMax,
          regenMinutesPerBean: 0,
          amoleBalance: cached.amoleBalance,
          refillCostAmole: 0,
        ),
        dueCount: cached.dueCount,
        fromCache: true,
      );
    } on Object {
      return null;
    }
  }

  void _openDownloadManagement() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DownloadManagementScreen(
          lessonPackStore: widget.lessonPackStore,
          syncEngine: widget.syncEngine,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          sessionApi: SessionApi(),
          userPreferencesApi: widget.userPreferencesApi,
          soundPreferenceRepository: widget.soundPreferenceRepository,
          sessionRepository: widget.sessionRepository,
          courseApi: widget.courseApi,
        ),
      ),
    );
  }

  void _togglePanel() {
    setState(() {
      _panelOpen = !_panelOpen;
      if (_panelOpen) {
        _panelMounted = true;
        _railFuture ??= _loadRail();
      }
    });
  }

  void _closePanel() {
    if (!_panelOpen) return;
    setState(() => _panelOpen = false);
  }

  /// The saved course list when there is one, refreshed in the background;
  /// the network only when this device has never listed courses.
  Future<List<Course>> _loadRail() async {
    final cache = widget.courseCache;
    if (cache != null) {
      try {
        final saved = await cache.loadCourseList();
        if (saved != null) {
          final active = await cache.activeCourseId();
          unawaited(_refreshRail());
          return await railCoursesFor(
            active == null ? saved : saved.withActive(active),
            cache: cache,
          );
        }
      } on Object {
        // Fall through to the network.
      }
    }
    final list = await widget.courseApi.getCourses();
    return railCoursesFor(list, cache: cache);
  }

  Future<void> _refreshRail() async {
    try {
      final list = await widget.courseApi.getCourses();
      final rail = await railCoursesFor(list, cache: widget.courseCache);
      if (mounted && _railFuture != null) {
        setState(() => _railFuture = Future.value(rail));
      }
    } on Object {
      // The saved rail stays; it is what offline shows anyway.
    }
  }

  /// Switching from the rail. The active course just closes the panel; a
  /// successful switch reloads the dashboard onto the new course's tree, and
  /// a failure leaves the current course alone with a message.
  Future<void> _switchFromRail(Course course) async {
    _closePanel();
    if (course.isActive) return;
    try {
      await widget.courseApi.switchCourse(course.id);
    } on CourseApiException catch (e) {
      if (mounted) showCourseSwitchError(context, e);
      return;
    }
    if (!mounted) return;
    _railFuture = null;
    _reload(scrollToTop: true);
  }

  /// Opens the course catalog from the panel's "+ Course" tile (and from
  /// Settings, via the same helper). A failed switch keeps the current course
  /// -- the helper shows the message.
  Future<void> _openCoursePicker() async {
    _closePanel();
    final switched = await pickAndSwitchCourse(
      context,
      courseApi: widget.courseApi,
    );
    if (switched == null || !mounted) return;
    _railFuture = null;
    _reload(scrollToTop: true);
  }

  /// Forgets the session the server refused and starts sign-in afresh, the
  /// same way logging out from Settings does. Queued offline lessons stay
  /// queued and are sent once the learner is signed in again.
  Future<void> _signInAgain() async {
    await widget.sessionRepository.clearSession();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AuthRoutes.signIn, (route) => false);
  }

  /// [scrollToTop] belongs to a course change: the new course's tree has
  /// nothing to do with where the learner was. A reload after a lesson keeps
  /// its position, so the learner comes back to the node they just finished.
  void _reload({bool scrollToTop = false}) {
    setState(() {
      _future = _load();
    });
    if (scrollToTop) _section = 0;
    if (scrollToTop && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// An active skill starts its lesson. A completed one asks first, because
  /// replaying it is a review -- nothing earned, nothing spent -- and the
  /// learner should know that before starting, not find out at the end.
  Future<void> _onNodeTap(SkillTreeNode node) async {
    final isReview = node.state == SkillNodeState.completed;
    if (isReview) {
      final review = await showReviewSkillSheet(context, node.title);
      if (review != true || !mounted) return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          lessonId: node.lessonId,
          lessonApi: widget.lessonApi,
          audioPlayer: widget.audioPlayer,
          feedbackPlayer: widget.feedbackPlayer,
          connectivityMonitor: widget.connectivityMonitor,
          lessonPackStore: widget.lessonPackStore,
          syncEngine: widget.syncEngine,
          lessonCache: widget.courseCache,
          skillVersion: node.contentVersion,
          beansNow: _lastData?.beansStatus.beans,
          isReview: isReview,
          skillProgress: SkillLessonProgress.forNode(node),
        ),
      ),
    );
    if (!mounted) return;
    _reload();
  }

  /// Assembles a [LessonContent] directly from the fetched due items (no
  /// `startLesson` fetch-by-id -- there is no single lesson to fetch) and
  /// launches [LessonScreen.practice]. The synthetic `lessonId`/`skillId`
  /// and zeroed beans fields are never read in practice mode -- Beans
  /// consumption is bypassed entirely (see `LessonController.isPractice`).
  Future<void> _openPractice() async {
    final dueItems = await widget.lessonApi.getDueItems();
    if (!mounted) return;
    final content = LessonContent(
      lessonId: '',
      skillId: '',
      title: 'Practice',
      exercises: dueItems.map((item) => item.exercise).toList(),
      beansAtStart: 0,
      beansMax: 0,
    );
    final vocabItemIdByExerciseId = {
      for (final item in dueItems) item.exercise.id: item.vocabItemId,
    };
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LessonScreen.practice(
          practiceContent: content,
          practiceVocabItemIdByExerciseId: vocabItemIdByExerciseId,
          lessonApi: widget.lessonApi,
          audioPlayer: widget.audioPlayer,
          feedbackPlayer: widget.feedbackPlayer,
          syncEngine: widget.syncEngine,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    // The lattice page from the dashboard mockup. The scroll view below owns
    // its scrolling and margins, because its header and banners are pinned.
    return AppPage(
      background: AppPageBackground.patterned,
      scrollable: false,
      padded: false,
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            // A reload keeps the tree on screen: swapping in a spinner
            // would tear down the scroll view and lose the learner's place.
            final previous = _lastData;
            if (previous == null) {
              return const LoadingState();
            }
            return _dashboard(context, previous);
          }
          if (snapshot.hasError) {
            if (_isSignedOut(snapshot.error)) {
              return _SignedOutState(onSignIn: _signInAgain);
            }
            return _LoadFailedState(onRetry: _reload);
          }
          return _dashboard(context, snapshot.data!);
        },
      ),
    );
  }

  /// One scroll surface (011-dashboard-ui-polish, story 002): the header is
  /// pinned, then the banners, the Practice card, and for each category its
  /// own pinned banner followed by its own nodes. Nothing else is fixed, so
  /// the skill path is what fills the screen.
  Widget _dashboard(BuildContext context, _DashboardData data) {
    // The panel floats over the path rather than pushing it down, so opening
    // it never reflows the tree. It hangs from the header, whose height the
    // header itself is the authority on.
    final jumpTo = _jumpTo;
    return Stack(
      children: [
        _scrollView(context, data),
        // Back to the learner's current lesson (FR-4). Hidden while the
        // course panel is open, so it never sits on top of it.
        Positioned(
          right: AppSpacing.marginMobile,
          bottom: AppSpacing.spaceMd,
          child: AnimatedSwitcher(
            duration: AppMotion.reduced(context)
                ? Duration.zero
                : AppMotion.feedback,
            child: jumpTo == null || _panelOpen
                ? const SizedBox.shrink()
                : AppIconButton(
                    key: ValueKey(jumpTo),
                    icon: jumpTo == AxisDirection.up
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    tooltip: 'Jump to your current lesson',
                    onPressed: _jumpToCurrent,
                  ),
          ),
        ),
        if (_panelMounted)
          Positioned(
            top: DashboardHeader.extentOf(context),
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_panelOpen,
              child: AnimatedOpacity(
                opacity: _panelOpen ? 1 : 0,
                duration: _panelDuration,
                onEnd: () {
                  if (!_panelOpen && mounted) {
                    setState(() => _panelMounted = false);
                  }
                },
                child: _panelOverlay(data),
              ),
            ),
          ),
      ],
    );
  }

  /// The panel plus the scrim that closes it. Built only once the panel has
  /// been opened at least once, so a learner who never opens it never pays
  /// for a course-list fetch.
  Widget _panelOverlay(_DashboardData data) {
    final railFuture = _railFuture;
    if (railFuture == null) return const SizedBox.shrink();
    // The scrim fills everything under the header and the panel sits on top
    // of it, so a tap anywhere the panel is not dismisses it.
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('course-panel-scrim'),
            onTap: _closePanel,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: AppColors.scrim),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: _panelOpen ? Offset.zero : const Offset(0, -0.08),
            duration: _panelDuration,
            child: FutureBuilder<List<Course>>(
              future: railFuture,
              builder: (context, snapshot) => CoursePanel(
                // A refreshed rail swaps its future; the rail it replaces
                // stays up meanwhile rather than flashing a spinner.
                loading:
                    snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasData,
                courses: snapshot.data ?? const [],
                activeCourseId: data.tree.course?.id,
                onCourseSelected: _switchFromRail,
                onAddCourse: _openCoursePicker,
                onSettings: () {
                  _closePanel();
                  _openSettings();
                },
                onDownloads: () {
                  _closePanel();
                  _openDownloadManagement();
                },
                onRetry: snapshot.hasError
                    ? () => setState(() => _railFuture = _loadRail())
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const Duration _panelDuration = Duration(milliseconds: 180);

  Widget _scrollView(BuildContext context, _DashboardData data) {
    final tree = data.tree;
    final categories = tree.categories;
    final sectionExtent = categories.isEmpty
        ? 0.0
        : CategoryBanner.extentOfAll(context, categories);
    _pinnedExtent = DashboardHeader.extentOf(context) + sectionExtent;
    final section = categories.isEmpty
        ? 0
        : _section.clamp(0, categories.length - 1);
    final active = tree.nodes
        .where((n) => n.state == SkillNodeState.active)
        .firstOrNull;
    final activeSection = active == null
        ? -1
        : categories.indexWhere((c) => c.id == active.categoryId);
    _activeSection = activeSection;
    // Where things are only settles after layout, so the header and the
    // jump button are brought up to date once this frame is drawn too.
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackScroll());

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _trackScroll();
        return false;
      },
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (_) {
          _trackScroll();
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          // Always scrollable so a course shorter than the viewport still
          // drags and settles instead of refusing to move.
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            pinnedHeader(
              extent: DashboardHeader.extentOf(context),
              child: DashboardHeader(
                leading: CourseBadge(
                  course: tree.course,
                  expanded: _panelOpen,
                  onTap: _togglePanel,
                ),
                hud: LessonHud(
                  streakCount: tree.streakCount,
                  beans: tree.beans,
                  beansMax: tree.beansMax,
                  totalXp: tree.totalXp,
                  amoleBalance: data.beansStatus.amoleBalance,
                ),
              ),
            ),
            // The one section header (020-dashboard-section-header, FR-1):
            // always pinned, one height for every section, and cross-fading
            // to the section scrolled to.
            if (categories.isNotEmpty)
              pinnedHeader(
                extent: sectionExtent,
                // An opaque band, so the path scrolls cleanly under the
                // header instead of peeking through the gaps around the card.
                child: ColoredBox(
                  color: AppColors.background,
                  child: AnimatedSwitcher(
                    duration: AppMotion.reduced(context)
                        ? Duration.zero
                        : AppMotion.feedback,
                    child: CategoryBanner(
                      key: ValueKey('section-header-$section'),
                      category: categories[section],
                      colorIndex: section,
                      completed: tree
                          .nodesIn(categories[section])
                          .where((n) => n.state == SkillNodeState.completed)
                          .length,
                      total: tree.nodesIn(categories[section]).length,
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    SyncStatusBanner(
                      syncEngine: widget.syncEngine,
                      lessonPackStore: widget.lessonPackStore,
                      lessonPackDownloader: widget.lessonPackDownloader,
                    ),
                    if (data.fromCache) const _OfflineNote(),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spaceSm,
              ),
              sliver: SliverToBoxAdapter(
                child: _PracticeEntryCard(
                  dueCount: data.dueCount,
                  syncEngine: widget.syncEngine,
                  onTap: _openPractice,
                ),
              ),
            ),
            for (int i = 0; i < categories.length; i++) ...[
              // A quiet divider instead of a banner (FR-3). The first
              // section has none: the header names it at the top.
              if (i > 0)
                SliverToBoxAdapter(
                  key: _dividerKey(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                    ),
                    child: PathSectionDivider(title: categories[i].title),
                  ),
                ),
              SliverToBoxAdapter(
                key: i == activeSection ? _activeSectionKey : null,
                child: _CategoryNodes(
                  nodes: tree.nodesIn(categories[i]),
                  onNodeTap: _onNodeTap,
                  downloader: widget.lessonPackDownloader,
                  activeNodeId: i == activeSection ? active?.id : null,
                  activeNodeKey: _activeNodeKey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Where the active node's top and bottom sit in the scroll, or `null`
  /// when there is none or it is not laid out.
  ({double top, double bottom})? _activeNodeSpan() {
    final node = _activeNodeKey.currentContext?.findRenderObject();
    final sliver = _activeSectionKey.currentContext?.findRenderObject();
    if (node is! RenderBox || !node.hasSize) return null;
    if (sliver is! RenderSliverToBoxAdapter || sliver.geometry == null) {
      return null;
    }
    final box = sliver.child;
    if (box == null) return null;
    final within = node.localToGlobal(Offset.zero, ancestor: box).dy;
    final top = sliver.constraints.precedingScrollExtent + within;
    return (top: top, bottom: top + node.size.height);
  }

  /// Where the line of the divider under [key] sits in the scroll: the
  /// middle of the divider, past its padding. `null` if not laid out.
  double? _dividerLine(GlobalKey? key) {
    final sliver = key?.currentContext?.findRenderObject();
    if (sliver is! RenderSliver) return null;
    final geometry = sliver.geometry;
    if (geometry == null) return null;
    return sliver.constraints.precedingScrollExtent + geometry.scrollExtent / 2;
  }

  /// Where the divider of section [index] begins in the scroll.
  double _dividerStart(int index) {
    final sliver = _dividerKeys[index]?.currentContext?.findRenderObject();
    return sliver is RenderSliver
        ? sliver.constraints.precedingScrollExtent
        : 0;
  }

  /// Works out which section the header shows and where the jump button
  /// points, from where things sit in the scroll. Rebuilds only when either
  /// changes, so scrolling within a section costs no rebuild (NFR-1).
  void _trackScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasViewportDimension) return;
    final offset = position.pixels;

    // A section is current once its divider's line -- the middle of the
    // divider -- has gone under the header's bottom edge. Sliver scroll
    // positions are known for every section, on screen or not.
    var section = 0;
    for (final MapEntry(key: index, value: key) in _dividerKeys.entries) {
      final line = _dividerLine(key);
      if (line == null) continue;
      if (line - offset <= _pinnedExtent && index > section) {
        section = index;
      }
    }

    AxisDirection? jumpTo;
    final span = _activeNodeSpan();
    if (span != null) {
      // Judged by the node's middle: a node whose circle is hidden under
      // the header, with only its label showing, is out of view.
      final middle = (span.top + span.bottom) / 2;
      if (middle <= offset + _pinnedExtent) {
        jumpTo = AxisDirection.up;
      } else if (middle >= offset + position.viewportDimension) {
        jumpTo = AxisDirection.down;
      }
    }

    if (section != _section || jumpTo != _jumpTo) {
      setState(() {
        _section = section;
        _jumpTo = jumpTo;
      });
    }
  }

  /// Scrolls the active node to the middle of the space below the pinned
  /// header -- and, if that leaves its section's divider still in view, on
  /// until the divider is tucked under the header, so the header names the
  /// node's section. Smooth, or at once with reduced motion (FR-4).
  void _jumpToCurrent() {
    final span = _activeNodeSpan();
    if (span == null || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final visible = position.viewportDimension - _pinnedExtent;
    var target = (span.top + span.bottom) / 2 - _pinnedExtent - visible / 2;
    // The whole divider, not just its line, so no half-cut title is left
    // at the header's edge.
    final line = _dividerLine(_dividerKeys[_activeSection]);
    if (line != null) {
      final tucked =
          line + (line - _dividerStart(_activeSection)) - _pinnedExtent;
      if (tucked > target) target = tucked;
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (AppMotion.reduced(context)) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }
}

/// One category's skill path. The zig-zag offset restarts at the top of every
/// category; the section's divider is a sliver above this, not part of it
/// (011-dashboard-ui-polish, story 002; 020-dashboard-section-header).
class _CategoryNodes extends StatelessWidget {
  const _CategoryNodes({
    required this.nodes,
    required this.onNodeTap,
    required this.downloader,
    required this.activeNodeKey,
    this.activeNodeId,
  });

  final List<SkillTreeNode> nodes;
  final ValueChanged<SkillTreeNode> onNodeTap;
  final LessonPackDownloader downloader;

  /// The learner's current node in this section, if it is here; it gets
  /// [activeNodeKey] so the jump button can find it.
  final String? activeNodeId;
  final GlobalKey activeNodeKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMobile,
        vertical: AppSpacing.spaceMd,
      ),
      child: Column(
        children: [
          for (int i = 0; i < nodes.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceMd),
              child: Align(
                alignment: _lateralOffset(i),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SkillPathNode(
                      key: nodes[i].id == activeNodeId ? activeNodeKey : null,
                      node: nodes[i],
                      onTap: nodes[i].state == SkillNodeState.locked
                          ? null
                          : () => onNodeTap(nodes[i]),
                    ),
                    if (nodes[i].state != SkillNodeState.locked)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _DownloadAffordance(
                          lessonId: nodes[i].lessonId,
                          downloader: downloader,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A gentle left/center/right alternation so the path reads as a
  /// serpentine trail (`DESIGN.md`'s node-offset-lateral) rather than a
  /// flat vertical list, without needing a fixed-height custom-paint path.
  static Alignment _lateralOffset(int index) => switch (index % 3) {
    0 => Alignment.center,
    1 => Alignment.centerRight,
    _ => Alignment.centerLeft,
  };
}

/// Dashboard entry point into a Practice session (008-srs-and-practice,
/// bolt 020, story 001). Shows the due-count as the entry hook and is
/// disabled -- never hidden -- both when there is nothing due and when
/// the device is offline (Practice is online-only per FR-5), reusing
/// [SyncEngine.isOnline] -- the same reactive connectivity plumbing
/// [SyncStatusBanner] already listens to on this screen, rather than
/// polling `ConnectivityMonitor` separately.
class _PracticeEntryCard extends StatelessWidget {
  const _PracticeEntryCard({
    required this.dueCount,
    required this.syncEngine,
    required this.onTap,
  });

  final int dueCount;
  final SyncEngine syncEngine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: syncEngine,
      builder: (context, _) {
        final offline = !syncEngine.isOnline;
        final enabled = !offline && dueCount > 0;
        final subtitle = offline
            ? 'Offline -- Practice needs a connection'
            : dueCount > 0
            ? '$dueCount word${dueCount == 1 ? '' : 's'} to review today'
            : "You're all caught up -- nothing due today";
        return Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: AppCard(
            onTap: enabled ? onTap : null,
            child: Row(
              children: [
                const IconBadge(icon: Icons.refresh, tone: AppTone.primary),
                const SizedBox(width: AppSpacing.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Practice',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A small icon-button overlay on a skill-tree node letting the user
/// download that lesson for offline use (009-offline-caching-and-sync-ui,
/// story 001): an [IconBadge] per state, or a spinner while downloading,
/// in a 48dp tap target (018-mobile-design-system, bolt 047).
class _DownloadAffordance extends StatelessWidget {
  const _DownloadAffordance({required this.lessonId, required this.downloader});

  final String lessonId;
  final LessonPackDownloader downloader;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: downloader,
      builder: (context, _) {
        final status = downloader.statusFor(lessonId);
        return _iconFor(
          status,
          onTap: () => downloader.downloadLesson(lessonId),
        );
      },
    );
  }

  Widget _iconFor(LessonDownloadStatus status, {required VoidCallback onTap}) {
    switch (status) {
      case LessonDownloadStatus.downloaded:
        return const _AffordanceBadge(
          label: 'Downloaded for offline use',
          child: IconBadge(
            icon: Icons.download_done,
            tone: AppTone.primary,
            size: _AffordanceBadge.badgeSize,
          ),
        );
      case LessonDownloadStatus.downloading:
        return const _AffordanceBadge(
          label: 'Downloading',
          child: SizedBox.square(
            dimension: _AffordanceBadge.badgeSize,
            child: Center(
              child: AppSpinner.small(color: AppColors.secondaryContainer),
            ),
          ),
        );
      case LessonDownloadStatus.failed:
        return _AffordanceBadge(
          label: 'Download failed, tap to try again',
          onTap: onTap,
          child: const IconBadge(
            icon: Icons.error_outline,
            tone: AppTone.tertiary,
            size: _AffordanceBadge.badgeSize,
          ),
        );
      case LessonDownloadStatus.notDownloaded:
        return _AffordanceBadge(
          label: 'Download for offline use',
          onTap: onTap,
          child: const IconBadge(
            icon: Icons.download_outlined,
            size: _AffordanceBadge.badgeSize,
          ),
        );
    }
  }
}

/// The badge sits in the tap target's top-right corner, where the node's
/// corner is, and the rest of the 48dp square extends into the node.
class _AffordanceBadge extends StatelessWidget {
  const _AffordanceBadge({
    required this.label,
    required this.child,
    this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  static const double badgeSize = 28;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppButton.minTapTarget,
          child: Align(alignment: Alignment.topRight, child: child),
        ),
      ),
    );
  }
}

/// Shown when the dashboard is the saved copy of the course because the
/// network is unavailable.
class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.spaceSm),
      child: InfoBanner(
        icon: Icons.cloud_off_outlined,
        tone: AppTone.neutral,
        message: 'Offline, showing saved progress',
      ),
    );
  }
}

/// The server's answer when the saved session is unknown or expired: it was
/// signed out elsewhere, it expired, or it was issued by a different
/// server/database than the one the app is now talking to.
bool _isSignedOut(Object? error) =>
    error is LessonApiException &&
    (error.errorCode == 'invalid_session' ||
        error.errorCode == 'missing_credentials');

/// Shown instead of [_LoadFailedState] when the session is no longer valid.
/// Retrying can never help there, and "check your connection" would be
/// wrong, so this says what happened and leads back to sign-in.
class _SignedOutState extends StatelessWidget {
  const _SignedOutState({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_clock,
      tone: AppTone.tertiary,
      title: 'Please sign in again',
      message:
          'Your session has ended. Your progress is saved to your '
          'account and will be back once you sign in.',
      action: AppButton.primary(
        label: 'Sign in',
        onPressed: onSignIn,
        expand: false,
      ),
    );
  }
}

class _LoadFailedState extends StatelessWidget {
  const _LoadFailedState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      icon: Icons.wifi_off,
      title: "Couldn't load your skill tree",
      message: 'Check your connection and try again.',
      onRetry: onRetry,
      retryLabel: 'Retry',
    );
  }
}
