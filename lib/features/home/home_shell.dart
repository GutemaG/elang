import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/l10n/app_language.dart';
import '../../shared/models/course.dart';
import '../../shared/services/answer_feedback_player.dart';
import '../../shared/services/connectivity_monitor.dart';
import '../../shared/services/course_api.dart';
import '../../shared/services/course_cache_store.dart';
import '../../shared/services/lesson_api.dart';
import '../../shared/services/lesson_audio_player.dart';
import '../../shared/services/lesson_pack_downloader.dart';
import '../../shared/services/lesson_pack_store.dart';
import '../../shared/services/media_cache.dart';
import '../../shared/services/reminders/reminder_service.dart';
import '../../shared/services/session_api.dart';
import '../../shared/services/session_repository.dart';
import '../../shared/services/sound_preference_repository.dart';
import '../../shared/services/sync_engine.dart';
import '../../shared/services/user_preferences_api.dart';
import '../../shared/widgets/app_tab_bar.dart';
import '../feedback/feedback_api.dart';
import '../league/league_dependencies.dart';
import '../league/screens/league_screen.dart';
import '../lesson/screens/download_management_screen.dart';
import '../lesson/screens/skill_tree_dashboard_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../sounds/sound_charts.dart';
import '../sounds/sound_player.dart';
import '../sounds/sounds_screen.dart';

/// The places in the bottom bar, in order.
enum HomeTab { learn, sounds, league, downloads, settings }

/// The signed-in app: the learning path and the bottom bar that reaches
/// Sounds, the weekly league, downloads and settings.
///
/// The bar replaces the links that were in the course panel, so the header
/// keeps all four counters. Each tab is built the first time it is opened
/// and then kept, so coming back to the path returns to the same place. A
/// lesson opens over everything, bar included.
///
/// Sounds shows only for a course whose language has a chart on, and
/// League only when the league is on.
class HomeShell extends StatefulWidget {
  const HomeShell({
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
    required this.soundCharts,
    this.soundPlayer,
    this.courseCache,
    this.mediaCache,
    this.reminders,
    this.league,
    this.sessionApi,
    this.feedbackApi,
  });

  final LessonApi lessonApi;
  final LessonAudioPlayer audioPlayer;
  final AnswerFeedbackPlayer feedbackPlayer;
  final ConnectivityMonitor connectivityMonitor;
  final LessonPackStore lessonPackStore;
  final LessonPackDownloader lessonPackDownloader;
  final SyncEngine syncEngine;
  final CourseApi courseApi;
  final SessionRepository sessionRepository;
  final UserPreferencesApi userPreferencesApi;
  final SoundPreferenceRepository soundPreferenceRepository;
  final CourseCacheStore? courseCache;
  final MediaCache? mediaCache;
  final ReminderService? reminders;
  final LeagueDependencies? league;

  /// Which languages have a Sounds chart, and the charts.
  final SoundCharts soundCharts;

  /// Plays the Sounds tab's letters; one on `audioplayers` by default.
  final SoundPlayer? soundPlayer;

  /// Settings' session and feedback clients; the real ones by default.
  final SessionApi? sessionApi;
  final FeedbackApi? feedbackApi;

  static ValueKey<String> tabKey(HomeTab tab) =>
      ValueKey('home-tab-${tab.name}');

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  HomeTab _tab = HomeTab.learn;
  final Set<HomeTab> _opened = {HomeTab.learn};
  Course? _course;

  /// Reloads the path after a course change in Settings.
  final ValueNotifier<int> _reloads = ValueNotifier(0);

  /// League and Downloads are built again on each visit, so they show
  /// what changed since (new XP, a finished download).
  int _leagueVisit = 0;
  int _downloadsVisit = 0;

  late final SoundPlayer _player =
      widget.soundPlayer ?? AudioplayersSoundPlayer(cache: widget.mediaCache);
  late final SessionApi _sessionApi = widget.sessionApi ?? SessionApi();
  late final FeedbackApi _feedbackApi =
      widget.feedbackApi ??
      HttpFeedbackApi(sessionRepository: widget.sessionRepository);

  @override
  void initState() {
    super.initState();
    widget.soundCharts.addListener(_chartsChanged);
    unawaited(widget.soundCharts.load());
  }

  @override
  void dispose() {
    widget.soundCharts.removeListener(_chartsChanged);
    _reloads.dispose();
    if (widget.soundPlayer == null) unawaited(_player.dispose());
    super.dispose();
  }

  void _chartsChanged() {
    if (mounted) setState(() {});
  }

  List<HomeTab> get _tabs => [
    HomeTab.learn,
    if (widget.soundCharts.has(_course?.learningLanguage)) HomeTab.sounds,
    if (widget.league != null) HomeTab.league,
    HomeTab.downloads,
    HomeTab.settings,
  ];

  void _select(HomeTab tab) {
    if (tab != HomeTab.sounds) unawaited(_player.stop());
    setState(() {
      if (tab == HomeTab.league) _leagueVisit++;
      if (tab == HomeTab.downloads) _downloadsVisit++;
      _tab = tab;
      _opened.add(tab);
    });
  }

  void _onCourse(Course? course) {
    if (course?.id == _course?.id) return;
    setState(() => _course = course);
    // A course just opened may have a chart the saved list does not know.
    unawaited(widget.soundCharts.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final current = tabs.contains(_tab) ? _tab : HomeTab.learn;
    return PopScope(
      // Back from another tab goes to the path first, as in other apps.
      canPop: current == HomeTab.learn,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(HomeTab.learn);
      },
      child: AppTabFrame(
        body: IndexedStack(
          index: tabs.indexOf(current),
          children: [
            for (final tab in tabs)
              KeyedSubtree(
                key: ValueKey(tab),
                child: _opened.contains(tab) || tab == current
                    ? _page(tab)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        bar: AppTabBar(
          tabs: [for (final tab in tabs) _tabOf(context, tab)],
          current: tabs.indexOf(current),
          onSelect: (i) => _select(tabs[i]),
        ),
      ),
    );
  }

  AppTab _tabOf(BuildContext context, HomeTab tab) {
    final l = context.l10n;
    final key = HomeShell.tabKey(tab);
    return switch (tab) {
      HomeTab.learn => AppTab(
        key: key,
        label: l.tabLearn,
        icon: Icons.home_rounded,
      ),
      HomeTab.sounds => AppTab(
        key: key,
        label: l.tabSounds,
        glyph: _soundsGlyph(),
      ),
      HomeTab.league => AppTab(
        key: key,
        label: l.tabLeague,
        icon: Icons.emoji_events_rounded,
      ),
      HomeTab.downloads => AppTab(
        key: key,
        label: l.tabDownloads,
        icon: Icons.download_for_offline_rounded,
      ),
      HomeTab.settings => AppTab(
        key: key,
        label: l.tabSettings,
        icon: Icons.settings_rounded,
      ),
    };
  }

  String _soundsGlyph() {
    final icon =
        widget.soundCharts.summaryOf(_course?.learningLanguage)?.icon ?? '';
    return icon.isEmpty ? 'Aa' : icon;
  }

  Widget _page(HomeTab tab) {
    final league = widget.league;
    return switch (tab) {
      HomeTab.learn => SkillTreeDashboardScreen(
        lessonApi: widget.lessonApi,
        audioPlayer: widget.audioPlayer,
        feedbackPlayer: widget.feedbackPlayer,
        connectivityMonitor: widget.connectivityMonitor,
        lessonPackStore: widget.lessonPackStore,
        lessonPackDownloader: widget.lessonPackDownloader,
        syncEngine: widget.syncEngine,
        courseApi: widget.courseApi,
        courseCache: widget.courseCache,
        mediaCache: widget.mediaCache,
        reminders: widget.reminders,
        sessionRepository: widget.sessionRepository,
        userPreferencesApi: widget.userPreferencesApi,
        soundPreferenceRepository: widget.soundPreferenceRepository,
        league: league,
        linksInBar: true,
        onOpenLeague: () => _select(HomeTab.league),
        onCourse: _onCourse,
        reloads: _reloads,
      ),
      HomeTab.sounds => SoundsScreen(
        charts: widget.soundCharts,
        language: _course?.learningLanguage ?? '',
        player: _player,
      ),
      HomeTab.league => LeagueScreen(
        key: ValueKey('league-$_leagueVisit'),
        api: league!.api,
        store: league.store,
        accountSettingsApi: league.accountSettingsApi,
        onLeague: league.showResultOnce,
        onStartLesson: () => _select(HomeTab.learn),
      ),
      HomeTab.downloads => DownloadManagementScreen(
        key: ValueKey('downloads-$_downloadsVisit'),
        lessonPackStore: widget.lessonPackStore,
        syncEngine: widget.syncEngine,
      ),
      HomeTab.settings => SettingsScreen(
        accountSettingsApi: league?.accountSettingsApi,
        sessionApi: _sessionApi,
        userPreferencesApi: widget.userPreferencesApi,
        soundPreferenceRepository: widget.soundPreferenceRepository,
        sessionRepository: widget.sessionRepository,
        courseApi: widget.courseApi,
        reminders: widget.reminders,
        feedbackApi: _feedbackApi,
        onCourseChanged: (_) => _reloads.value++,
      ),
    };
  }
}
