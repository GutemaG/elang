import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/models/course.dart';
import '../../../shared/models/lesson_content.dart';
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
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';
import '../../courses/course_badge.dart';
import '../../courses/course_panel.dart';
import '../../courses/course_picker.dart';
import '../../courses/course_rail_source.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/category_banner.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/lesson_hud.dart';
import '../widgets/pinned_header_sliver.dart';
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

  /// Threaded down purely to build [SettingsScreen] on tap -- the
  /// dashboard itself has no other use for these.
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

  /// [scrollToTop] belongs to a course change: the new course's tree has
  /// nothing to do with where the learner was. A reload after a lesson keeps
  /// its position, so the learner comes back to the node they just finished.
  void _reload({bool scrollToTop = false}) {
    setState(() {
      _future = _load();
    });
    if (scrollToTop && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _onNodeTap(SkillTreeNode node) async {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<_DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              // A reload keeps the tree on screen: swapping in a spinner
              // would tear down the scroll view and lose the learner's place.
              final previous = _lastData;
              if (previous == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _dashboard(context, previous);
            }
            if (snapshot.hasError) {
              return _ErrorState(onRetry: _reload);
            }
            return _dashboard(context, snapshot.data!);
          },
        ),
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
    return Stack(
      children: [
        _scrollView(context, data),
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
            child: ColoredBox(
              color: AppColors.inverseSurface.withValues(alpha: 0.32),
            ),
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
    return CustomScrollView(
      controller: _scrollController,
      // Always scrollable so a course shorter than the viewport still drags
      // and settles instead of refusing to move.
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
        for (int i = 0; i < tree.categories.length; i++)
          // The group is what makes the banner a *section* header: pinned
          // slivers otherwise accumulate at the top, each one stopping below
          // the last, so every category the learner scrolled past would still
          // be sitting there. Grouped, a banner is pinned only while its own
          // nodes are on screen and is pushed off by the next category's.
          SliverMainAxisGroup(
            slivers: [
              pinnedHeader(
                extent: CategoryBanner.extentOf(context, tree.categories[i]),
                child: CategoryBanner(
                  category: tree.categories[i],
                  // Consecutive sections take consecutive colours, so one is
                  // never mistaken for the next while scrolling.
                  colorIndex: i,
                  completed: tree
                      .nodesIn(tree.categories[i])
                      .where((n) => n.state == SkillNodeState.completed)
                      .length,
                  total: tree.nodesIn(tree.categories[i]).length,
                ),
              ),
              SliverToBoxAdapter(
                child: _CategoryNodes(
                  nodes: tree.nodesIn(tree.categories[i]),
                  onNodeTap: _onNodeTap,
                  downloader: widget.lessonPackDownloader,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// One category's skill path. The zig-zag offset restarts at the top of every
/// category; the category's banner is a pinned sliver above this, not part of
/// it (011-dashboard-ui-polish, story 002).
class _CategoryNodes extends StatelessWidget {
  const _CategoryNodes({
    required this.nodes,
    required this.onNodeTap,
    required this.downloader,
  });

  final List<SkillTreeNode> nodes;
  final ValueChanged<SkillTreeNode> onNodeTap;
  final LessonPackDownloader downloader;

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
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.spaceMd,
              ),
              child: Align(
                alignment: _lateralOffset(i),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SkillPathNode(
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
          child: Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.base),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.base),
              onTap: enabled ? onTap : null,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.spaceMd),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.base),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.refresh,
                      color: AppColors.primaryContainer,
                    ),
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
            ),
          ),
        );
      },
    );
  }
}

/// A small icon-button overlay on a skill-tree node letting the user
/// download that lesson for offline use (009-offline-caching-and-sync-ui,
/// story 001). Deliberately plain (not a new Highland Pulse component) --
/// this bolt prioritizes the underlying offline capability over visual
/// polish.
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
          icon: Icons.download_done,
          color: AppColors.primaryContainer,
        );
      case LessonDownloadStatus.downloading:
        return const _AffordanceBadge(
          icon: null,
          color: AppColors.secondaryContainer,
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case LessonDownloadStatus.failed:
        return _AffordanceBadge(
          icon: Icons.error_outline,
          color: AppColors.tertiaryBrand,
          onTap: onTap,
        );
      case LessonDownloadStatus.notDownloaded:
        return _AffordanceBadge(
          icon: Icons.download_outlined,
          color: AppColors.outlineVariant,
          onTap: onTap,
        );
    }
  }
}

class _AffordanceBadge extends StatelessWidget {
  const _AffordanceBadge({
    required this.icon,
    required this.color,
    this.onTap,
    this.child,
  });

  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: child ?? Icon(icon, size: 16, color: color),
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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.spaceSm),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.spaceXs),
          Expanded(
            child: Text(
              'Offline, showing saved progress',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off,
              size: 40,
              color: AppColors.tertiaryBrand,
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              "Couldn't load your skill tree",
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.space2xs),
            Text(
              'Check your connection and try again.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceMd),
            TactileButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
