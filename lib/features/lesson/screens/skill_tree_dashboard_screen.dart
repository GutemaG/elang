import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/models/lesson_content.dart';
import '../../../shared/models/skill_tree.dart';
import '../../../shared/services/answer_feedback_player.dart';
import '../../../shared/services/connectivity_monitor.dart';
import '../../../shared/services/lesson_api.dart';
import '../../../shared/services/lesson_audio_player.dart';
import '../../../shared/services/lesson_pack_downloader.dart';
import '../../../shared/services/lesson_pack_store.dart';
import '../../../shared/services/session_api.dart';
import '../../../shared/services/session_repository.dart';
import '../../../shared/services/sound_preference_repository.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/services/user_preferences_api.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/lesson_hud.dart';
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
    required this.sessionRepository,
    required this.userPreferencesApi,
    required this.soundPreferenceRepository,
  });

  final LessonApi lessonApi;
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
  });

  final SkillTreeResponse tree;
  final BeansStatus beansStatus;
  final int dueCount;
}

class _SkillTreeDashboardScreenState extends State<SkillTreeDashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // So a previously-downloaded pack shows as downloaded immediately,
    // without the user re-tapping the download affordance.
    unawaited(widget.lessonPackDownloader.refreshDownloadedStatuses());
    // Drains any entries queued from a previous session -- the "survives
    // app restart" durability requirement (010-offline-caching-and-
    // sync-ui, story 003).
    unawaited(widget.syncEngine.refresh());
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      widget.lessonApi.getSkillTree(),
      widget.lessonApi.getBeansStatus(),
      widget.lessonApi.getDueCount(),
    ]);
    return _DashboardData(
      tree: results[0] as SkillTreeResponse,
      beansStatus: results[1] as BeansStatus,
      dueCount: results[2] as int,
    );
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
        ),
      ),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
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
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(onRetry: _reload);
            }
            final tree = snapshot.data!.tree;
            final beansStatus = snapshot.data!.beansStatus;
            final dueCount = snapshot.data!.dueCount;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.marginMobile,
                    AppSpacing.spaceSm,
                    AppSpacing.marginMobile,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SyncStatusBanner(
                          syncEngine: widget.syncEngine,
                          lessonPackStore: widget.lessonPackStore,
                          lessonPackDownloader: widget.lessonPackDownloader,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.folder_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                        tooltip: 'Manage Downloads',
                        onPressed: _openDownloadManagement,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                        tooltip: 'Settings',
                        onPressed: _openSettings,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _DashboardContent(
                    tree: tree,
                    amoleBalance: beansStatus.amoleBalance,
                    dueCount: dueCount,
                    syncEngine: widget.syncEngine,
                    onNodeTap: _onNodeTap,
                    onPracticeTap: _openPractice,
                    downloader: widget.lessonPackDownloader,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.tree,
    required this.amoleBalance,
    required this.dueCount,
    required this.syncEngine,
    required this.onNodeTap,
    required this.onPracticeTap,
    required this.downloader,
  });

  final SkillTreeResponse tree;
  final int amoleBalance;
  final int dueCount;
  final SyncEngine syncEngine;
  final ValueChanged<SkillTreeNode> onNodeTap;
  final VoidCallback onPracticeTap;
  final LessonPackDownloader downloader;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
            vertical: AppSpacing.spaceSm,
          ),
          sliver: SliverToBoxAdapter(
            child: LessonHud(
              streakCount: tree.streakCount,
              beans: tree.beans,
              beansMax: tree.beansMax,
              totalXp: tree.totalXp,
              amoleBalance: amoleBalance,
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
              dueCount: dueCount,
              syncEngine: syncEngine,
              onTap: onPracticeTap,
            ),
          ),
        ),
        for (final category in tree.categories)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.spaceSm,
            ),
            sliver: SliverToBoxAdapter(
              child: _CategorySection(
                category: category,
                nodes: tree.nodesIn(category),
                onNodeTap: onNodeTap,
                downloader: downloader,
              ),
            ),
          ),
      ],
    );
  }
}

/// One category: its banner followed by its own skill path. The zig-zag
/// offset restarts at the top of every category.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.nodes,
    required this.onNodeTap,
    required this.downloader,
  });

  final SkillCategory category;
  final List<SkillTreeNode> nodes;
  final ValueChanged<SkillTreeNode> onNodeTap;
  final LessonPackDownloader downloader;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CategoryBanner(category: category, nodes: nodes),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceMd),
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
        ),
      ],
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

class _CategoryBanner extends StatelessWidget {
  const _CategoryBanner({required this.category, required this.nodes});

  final SkillCategory category;
  final List<SkillTreeNode> nodes;

  int get _completed =>
      nodes.where((n) => n.state == SkillNodeState.completed).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.base),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(color: AppColors.cardBevelDefault, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      category.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              Text(
                '$_completed/${nodes.length} Completed',
                maxLines: 1,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: LinearProgressIndicator(
              value: nodes.isEmpty ? 0 : _completed / nodes.length,
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainer,
              valueColor: const AlwaysStoppedAnimation(
                AppColors.primaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
