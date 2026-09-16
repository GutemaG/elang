import 'package:flutter/material.dart';

import '../../../shared/models/skill_tree.dart';
import '../../../shared/services/lesson_api.dart';
import '../../../shared/services/lesson_audio_player.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/tactile_button.dart';
import '../widgets/lesson_hud.dart';
import '../widgets/skill_path_node.dart';
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
  });

  final LessonApi lessonApi;
  final LessonAudioPlayer audioPlayer;

  @override
  State<SkillTreeDashboardScreen> createState() =>
      _SkillTreeDashboardScreenState();
}

class _SkillTreeDashboardScreenState extends State<SkillTreeDashboardScreen> {
  late Future<SkillTreeResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.lessonApi.getSkillTree();
  }

  void _reload() {
    setState(() {
      _future = widget.lessonApi.getSkillTree();
    });
  }

  Future<void> _onNodeTap(SkillTreeNode node) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          lessonId: node.lessonId,
          lessonApi: widget.lessonApi,
          audioPlayer: widget.audioPlayer,
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
        child: FutureBuilder<SkillTreeResponse>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(onRetry: _reload);
            }
            final tree = snapshot.data!;
            return _DashboardContent(tree: tree, onNodeTap: _onNodeTap);
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.tree, required this.onNodeTap});

  final SkillTreeResponse tree;
  final ValueChanged<SkillTreeNode> onNodeTap;

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
                      child: SkillPathNode(
                        node: tree.nodes[i],
                        onTap: tree.nodes[i].state == SkillNodeState.locked
                            ? null
                            : () => onNodeTap(tree.nodes[i]),
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
