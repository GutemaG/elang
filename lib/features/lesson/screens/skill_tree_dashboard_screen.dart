import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
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
  const _DashboardData({required this.tree, required this.beansStatus});

  final SkillTreeResponse tree;
  final BeansStatus beansStatus;
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
    ]);
    return _DashboardData(
      tree: results[0] as SkillTreeResponse,
      beansStatus: results[1] as BeansStatus,
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
                    onNodeTap: _onNodeTap,
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
    required this.onNodeTap,
    required this.downloader,
  });

  final SkillTreeResponse tree;
  final int amoleBalance;
  final ValueChanged<SkillTreeNode> onNodeTap;
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
          ),
          sliver: SliverToBoxAdapter(child: _UnitBanner(tree: tree)),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
            vertical: AppSpacing.spaceLg,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                for (int i = 0; i < tree.nodes.length; i++)
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
                            node: tree.nodes[i],
                            onTap:
                                tree.nodes[i].state == SkillNodeState.locked
                                ? null
                                : () => onNodeTap(tree.nodes[i]),
                          ),
                          if (tree.nodes[i].state != SkillNodeState.locked)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: _DownloadAffordance(
                                lessonId: tree.nodes[i].lessonId,
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

class _UnitBanner extends StatelessWidget {
  const _UnitBanner({required this.tree});

  final SkillTreeResponse tree;

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
                      tree.unitTitle,
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      tree.unitSubtitle,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${tree.completedCount}/${tree.nodes.length} Completed',
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
              value: tree.nodes.isEmpty
                  ? 0
                  : tree.completedCount / tree.nodes.length,
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
        return _iconFor(status, onTap: () => downloader.downloadLesson(lessonId));
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
  const _AffordanceBadge({required this.icon, required this.color, this.onTap, this.child});

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
            const Icon(Icons.wifi_off, size: 40, color: AppColors.tertiaryBrand),
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
