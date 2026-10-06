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
import '../../../shared/services/media_cache.dart';
import '../../../shared/services/reminders/reminder_service.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/services/user_preferences_api.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/path_popover.dart';
import '../../auth/auth_routes.dart';
import '../../courses/course_badge.dart';
import '../../courses/course_panel.dart';
import '../../courses/course_picker.dart';
import '../../courses/course_rail_source.dart';
import '../../feedback/feedback_api.dart';
import '../../league/league_api.dart';
import '../../league/league_dependencies.dart';
import '../../league/league_models.dart';
import '../../league/screens/league_screen.dart';
import '../../league/widgets/league_result_sheet.dart';
import '../../league/widgets/league_widgets.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/category_banner.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/lesson_hud.dart';
import '../widgets/pinned_header_sliver.dart';
import '../widgets/skill_path_node.dart';
import '../widgets/stat_sheet.dart';
import '../widgets/sync_status_banner.dart';
import 'download_management_screen.dart';
import 'lesson_screen.dart';
import '../../../shared/l10n/app_language.dart';

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
    this.mediaCache,
    this.reminders,
    this.league,
    this.linksInBar = false,
    this.onOpenLeague,
    this.onCourse,
    this.reloads,
  });

  final LessonApi lessonApi;

  /// Settings, Downloads and the league live in the home screen's bottom
  /// bar, so the course panel leaves them out.
  final bool linksInBar;

  /// Opens the league somewhere else (the bar's League tab) instead of
  /// pushing its screen.
  final VoidCallback? onOpenLeague;

  /// Told the course shown, whenever it changes: the bar shows a Sounds
  /// tab only for a language that has a chart.
  final ValueChanged<Course?>? onCourse;

  /// Each notification reloads the dashboard from the top, as after a
  /// course change made elsewhere (in the Settings tab).
  final Listenable? reloads;

  /// Per-course offline copy of the dashboard (010-multi-language-courses,
  /// story 003). When set, every successful load is saved, and a failed load
  /// falls back to the active course's saved copy. `null` disables caching.
  final CourseCacheStore? courseCache;

  /// Clips and pictures kept on the device (bolt 057), handed to each
  /// lesson; the next lesson's are fetched ahead from here. `null` fetches
  /// nothing ahead.
  final MediaCache? mediaCache;

  /// Kept in step with each load's streak and practised day, so the 8 pm
  /// reminder skips a day already done (021-daily-reminder); `null` keeps
  /// no reminders.
  final ReminderService? reminders;

  /// The weekly league (023-weekly-leagues); `null` hides its entry.
  final LeagueDependencies? league;

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

  _DashboardData withBeans(BeansStatus beans) => _DashboardData(
    tree: tree,
    beansStatus: beans,
    dueCount: dueCount,
    fromCache: fromCache,
  );
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

  /// Beans changed by the stats sheet -- a bean that came, or a refill --
  /// shown over the loaded data until the next load brings the server's
  /// (013-stat-pill-interactions, bolt 060).
  BeansStatus? _sheetBeans;

  _DashboardData _withSheetBeans(_DashboardData data) {
    final beans = _sheetBeans;
    return beans == null ? data : data.withBeans(beans);
  }

  GlobalKey _dividerKey(int index) =>
      _dividerKeys.putIfAbsent(index, GlobalKey.new);

  /// The learner's league for the card (023-weekly-leagues, story 009);
  /// `null` shows no card.
  CurrentLeague? _league;

  /// Loads the league apart from the tree, so it never holds up or breaks
  /// the dashboard: the saved copy first, then a fresh one (saved in turn),
  /// which may carry last week's result to show. Offline, the saved copy
  /// stays.
  Future<void> _loadLeague() async {
    final league = widget.league;
    if (league == null) return;
    if (_league == null) {
      final saved = await league.store.read();
      if (saved != null && mounted && _league == null) {
        setState(() => _league = saved.league);
      }
    }
    try {
      final fresh = await league.api.current();
      unawaited(league.store.save(fresh, DateTime.now()));
      if (!mounted) return;
      setState(() => _league = fresh);
      await league.showResultOnce(context, fresh);
    } on LeagueApiException {
      // Offline: whatever is showing stays.
    }
  }

  @override
  void initState() {
    super.initState();
    _pendingSeen = widget.syncEngine.pendingCount;
    widget.syncEngine.addListener(_onSyncChanged);
    widget.reloads?.addListener(_reloadFromTop);
    _future = _load();
    unawaited(_loadLeague());
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
    widget.reloads?.removeListener(_reloadFromTop);
    _scrollController.dispose();
    super.dispose();
  }

  void _reloadFromTop() {
    if (!mounted) return;
    _railFuture = null;
    _reload(scrollToTop: true);
  }

  /// The id of the course last passed to [SkillTreeDashboardScreen.onCourse];
  /// a placeholder until the first, so even "no course" is passed once.
  Object? _reportedCourse = const Object();

  void _reportCourse(Course? course) {
    final onCourse = widget.onCourse;
    if (onCourse == null || _reportedCourse == course?.id) return;
    _reportedCourse = course?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onCourse(course);
    });
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
      _sheetBeans = null;
      unawaited(
        widget.reminders?.refresh(
          streakCount: data.tree.streakCount,
          practisedToday: data.tree.practisedToday,
        ),
      );
      unawaited(widget.reminders?.askOnFirstLaunch());
      widget.lessonPackDownloader.currentCourse = data.tree.course;
      unawaited(_saveToCache(data));
      unawaited(_prefetchLessons(data.tree));
      _lastData = data;
      return data;
    } on LessonApiException catch (e) {
      // A backend answer (e.g. an expired session) is not "offline".
      if (e.errorCode != null) rethrow;
      if (cached == null) rethrow;
      // The saved copy's practised day may be another day's, so only its
      // streak is passed on.
      unawaited(
        widget.reminders?.refresh(streakCount: cached.tree.streakCount),
      );
      unawaited(widget.reminders?.askOnFirstLaunch());
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
      final stops = [
        for (final category in tree.categories) ...tree.stopsIn(category),
      ];
      final open = [
        ...stops.where((s) => s.state == SkillNodeState.active),
        ...stops.where((s) => s.state == SkillNodeState.completed),
      ];
      var fetched = 0;
      for (final stop in open) {
        if (fetched >= _prefetchPerLoad || !mounted) break;
        final version = stop.skill.contentVersion;
        final cached = await cache.loadLesson(stop.lessonId);
        if (cached != null && cached.isFreshFor(version)) continue;
        fetched++;
        try {
          final content = await widget.lessonApi.startLesson(stop.lessonId);
          await cache.saveLesson(content, skillVersion: version);
        } on Object {
          // Offline or refused: this lesson just fetches when tapped.
        }
      }
      if (open.isNotEmpty && mounted) {
        await _warmMediaOf(open.first.lessonId, cache);
      }
    } on Object {
      // A prefetch is an optimisation; nothing depends on it finishing.
    } finally {
      _prefetching = false;
    }
  }

  /// Fetches [lessonId]'s clips and pictures ahead, from its saved copy, so
  /// its first sound plays at once when tapped (bolt 057). Only the next
  /// lesson: a few hundred KB, fine on mobile data too (the user's choice).
  Future<void> _warmMediaOf(String lessonId, CourseCacheStore cache) async {
    final media = widget.mediaCache;
    if (media == null) return;
    final copy = await cache.loadLesson(lessonId);
    if (copy != null) media.warm(lessonMediaOf(copy.content));
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
        beansStatus: data.beansStatus,
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
      // The saved beans, brought up to now: they came back while the app
      // was closed just as they do on the server.
      final saved = cached.beansStatus?.at(DateTime.now());
      return _DashboardData(
        tree: tree,
        beansStatus:
            saved ??
            BeansStatus(
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

  Future<void> _openLeague(LeagueDependencies league) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LeagueScreen(
          api: league.api,
          store: league.store,
          accountSettingsApi: league.accountSettingsApi,
          onLeague: league.showResultOnce,
        ),
      ),
    );
    if (mounted) unawaited(_loadLeague());
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          accountSettingsApi: widget.league?.accountSettingsApi,
          sessionApi: SessionApi(),
          userPreferencesApi: widget.userPreferencesApi,
          soundPreferenceRepository: widget.soundPreferenceRepository,
          sessionRepository: widget.sessionRepository,
          courseApi: widget.courseApi,
          reminders: widget.reminders,
          feedbackApi: HttpFeedbackApi(
            sessionRepository: widget.sessionRepository,
          ),
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
    await widget.reminders?.signedOut();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AuthRoutes.signIn, (route) => false);
  }

  /// The stats sheet on [kind]'s tab (013-stat-pill-interactions).
  void _openStats(StatKind kind, _DashboardData data) {
    unawaited(
      showStatSheet(
        context,
        initial: kind,
        streakCount: data.tree.streakCount,
        totalXp: data.tree.totalXp,
        beans: data.beansStatus,
        offline: data.fromCache,
        refill: widget.lessonApi.refillBeansWithAmole,
        onBeansChanged: (beans) {
          if (mounted) setState(() => _sheetBeans = beans);
        },
        loadStreak: widget.lessonApi.getStreakHistory,
        loadAmole: widget.lessonApi.getAmoleHistory,
      ),
    );
  }

  /// [scrollToTop] belongs to a course change: the new course's tree has
  /// nothing to do with where the learner was. A reload after a lesson keeps
  /// its position, so the learner comes back to the node they just finished.
  void _reload({bool scrollToTop = false}) {
    setState(() {
      _future = _load();
    });
    unawaited(_loadLeague());
    if (scrollToTop) _section = 0;
    if (scrollToTop && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// A tapped bubble opens its popover (the path shows no titles, so that
  /// is where the lesson is named); its button starts the bubble's lesson.
  /// A completed skill's popover says a review earns and spends nothing; a
  /// locked one only says how to unlock it.
  Future<void> _onStopTap(PathStop stop, Rect anchor) async {
    final start = await showStopPopover(
      context,
      stop: stop,
      anchor: anchor,
      footer: stop.state == SkillNodeState.locked
          ? null
          : _DownloadNote(
              lessonId: stop.lessonId,
              downloader: widget.lessonPackDownloader,
            ),
    );
    if (start != true || !mounted) return;
    final node = stop.skill;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          lessonId: stop.lessonId,
          lessonApi: widget.lessonApi,
          audioPlayer: widget.audioPlayer,
          feedbackPlayer: widget.feedbackPlayer,
          connectivityMonitor: widget.connectivityMonitor,
          lessonPackStore: widget.lessonPackStore,
          syncEngine: widget.syncEngine,
          lessonCache: widget.courseCache,
          mediaCache: widget.mediaCache,
          skillVersion: node.contentVersion,
          beansNow: (_sheetBeans ?? _lastData?.beansStatus)?.beans,
          isReview: stop.isReview,
          // A lesson bubble is simply a lesson: no "Lesson N of M".
          skillProgress: stop.isLesson
              ? null
              : SkillLessonProgress.forNode(node),
          reminders: widget.reminders,
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
      title: context.l10n.practice,
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
          mediaCache: widget.mediaCache,
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
  Widget _dashboard(BuildContext context, _DashboardData loaded) {
    final data = _withSheetBeans(loaded);
    _reportCourse(data.tree.course);
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
                    tooltip: context.l10n.jumpToCurrentLesson,
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
            child: ColoredBox(color: context.colors.scrim),
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
                onSettings: widget.linksInBar
                    ? null
                    : () {
                        _closePanel();
                        _openSettings();
                      },
                onDownloads: widget.linksInBar
                    ? null
                    : () {
                        _closePanel();
                        _openDownloadManagement();
                      },
                onLeague: switch (widget.league) {
                  _ when widget.linksInBar => null,
                  final league? => () {
                    _closePanel();
                    _openLeague(league);
                  },
                  null => null,
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
    final stopsBySection = [
      for (final category in categories) tree.stopsIn(category),
    ];
    final active = stopsBySection
        .expand((stops) => stops)
        .where((s) => s.state == SkillNodeState.active)
        .firstOrNull;
    final activeSection = active == null
        ? -1
        : categories.indexWhere((c) => c.id == active.skill.categoryId);
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
                  beans: data.beansStatus.beans,
                  beansMax: data.beansStatus.beansMax,
                  totalXp: tree.totalXp,
                  amoleBalance: data.beansStatus.amoleBalance,
                  onOpen: (kind) => _openStats(kind, data),
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
                  color: context.colors.surface,
                  child: AnimatedSwitcher(
                    duration: AppMotion.reduced(context)
                        ? Duration.zero
                        : AppMotion.feedback,
                    child: CategoryBanner(
                      key: ValueKey('section-header-$section'),
                      category: categories[section],
                      colorIndex: section,
                      completed: stopsBySection[section]
                          .where((s) => s.state == SkillNodeState.completed)
                          .length,
                      total: stopsBySection[section].length,
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
            // 023-weekly-leagues, story 009: none when switched off.
            if ((widget.league, _league) case (final league?, final current?)
                when current.status != LeagueStatus.hidden)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.marginMobile,
                  0,
                  AppSpacing.marginMobile,
                  AppSpacing.spaceSm,
                ),
                sliver: SliverToBoxAdapter(
                  child: LeagueCard(
                    league: current,
                    onTap: widget.onOpenLeague ?? () => _openLeague(league),
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
                  stops: stopsBySection[i],
                  onStopTap: _onStopTap,
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
      // At the end of the path a short last section can never scroll up
      // under the header; once its divider is on screen, it is current. A
      // path that does not scroll at all keeps naming the first section.
      if (position.maxScrollExtent > 0 &&
          offset >= position.maxScrollExtent - 0.5 &&
          line - offset < position.viewportDimension &&
          index > section) {
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

/// One category's path: a bubble per lesson, each skill's first under its
/// label (026-lesson-path-nodes), or a bubble per skill for a tree without
/// lessons. The zig-zag offset restarts at the top of every category and
/// runs on across its skills; the section's divider is a sliver above
/// this, not part of it (011-dashboard-ui-polish, story 002;
/// 020-dashboard-section-header).
class _CategoryNodes extends StatelessWidget {
  const _CategoryNodes({
    required this.stops,
    required this.onStopTap,
    required this.activeNodeKey,
    this.activeNodeId,
  });

  final List<PathStop> stops;

  /// A bubble and where it is on screen, for its popover to point at.
  final void Function(PathStop stop, Rect anchor) onStopTap;

  /// The learner's current bubble in this section, if it is here; it gets
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
          for (int i = 0; i < stops.length; i++) ...[
            if (stops[i].isLesson && stops[i].isFirstOfSkill)
              PathSkillLabel(skill: stops[i].skill),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceMd),
              child: Align(
                alignment: _lateralOffset(i),
                child: Builder(
                  builder: (nodeContext) => SkillPathNode(
                    key: stops[i].id == activeNodeId ? activeNodeKey : null,
                    stop: stops[i],
                    onTap: () => onStopTap(stops[i], _rectOf(nodeContext)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Rect _rectOf(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// A gentle center/right/center/left wave so the path reads as a
  /// serpentine trail (`DESIGN.md`'s node-offset-lateral) rather than a
  /// flat vertical list, without needing a fixed-height custom-paint path.
  static Alignment _lateralOffset(int index) => switch (index % 4) {
    0 => Alignment.center,
    1 => const Alignment(0.45, 0),
    2 => Alignment.center,
    _ => const Alignment(-0.45, 0),
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
        final l = context.l10n;
        final subtitle = offline
            ? l.practiceOffline
            : dueCount > 0
            ? l.wordsToReview(dueCount)
            : l.allCaughtUp;
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
                        l.practice,
                        style: AppTypography.headlineSm.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(
                    Icons.chevron_right,
                    color: context.colors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The learner's league on the dashboard (023-weekly-leagues, story 009):
/// the tier with the place and the week's XP, or an invitation to join
/// before the first XP of the week. Opens the league screen.
class LeagueCard extends StatelessWidget {
  const LeagueCard({super.key, required this.league, required this.onTap});

  final CurrentLeague league;
  final VoidCallback onTap;

  static const cardKey = ValueKey('dashboard-league-card');

  @override
  Widget build(BuildContext context) {
    final me = league.members.where((m) => m.isMe).firstOrNull;
    final joined = league.status == LeagueStatus.joined && me != null;
    final l = context.l10n;
    final tier = league.tier.titleIn(l);
    final title = joined ? tier : l.joinThisWeeksLeague;
    final subtitle = joined
        ? l.leaguePlace(ordinal(me.rank, l), league.members.length, me.weeklyXp)
        : l.earnXpToJoin(tier);
    return AppCard(
      key: cardKey,
      onTap: onTap,
      child: Row(
        children: [
          TierBadge(tier: league.tier, size: IconBadge.defaultSize),
          const SizedBox(width: AppSpacing.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.headlineSm.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// The download line at the foot of a skill's popover
/// (009-offline-caching-and-sync-ui, story 001): download the lesson for
/// offline use, its progress, a retry, or that it is already saved. It
/// follows the download live while the popover is open.
class _DownloadNote extends StatelessWidget {
  const _DownloadNote({required this.lessonId, required this.downloader});

  final String lessonId;
  final LessonPackDownloader downloader;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: downloader,
      builder: (context, _) {
        void download() => downloader.downloadLesson(lessonId);
        return switch (downloader.statusFor(lessonId)) {
          LessonDownloadStatus.downloaded => PathPopoverNote(
            icon: Icons.download_done,
            label: context.l10n.downloadedOffline,
          ),
          LessonDownloadStatus.downloading => PathPopoverNote(
            icon: Icons.downloading,
            label: context.l10n.downloading,
            busy: true,
          ),
          LessonDownloadStatus.failed => PathPopoverNote(
            icon: Icons.error_outline,
            label: context.l10n.downloadFailed,
            onTap: download,
          ),
          LessonDownloadStatus.notDownloaded => PathPopoverNote(
            icon: Icons.download_outlined,
            label: context.l10n.downloadForOffline,
            onTap: download,
          ),
        };
      },
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
      child: InfoBanner(
        icon: Icons.cloud_off_outlined,
        tone: AppTone.neutral,
        message: context.l10n.offlineSavedProgress,
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
      title: context.l10n.signInAgainTitle,
      message: context.l10n.signInAgainMessage,
      action: AppButton.primary(
        label: context.l10n.signIn,
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
      title: context.l10n.skillTreeLoadFailed,
      message: context.l10n.checkConnection,
      onRetry: onRetry,
      retryLabel: context.l10n.retry,
    );
  }
}
