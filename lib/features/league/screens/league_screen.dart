import 'package:flutter/material.dart';

import '../../../shared/settings/account_settings_api.dart';
import '../../../shared/settings/known_settings.dart';
import '../../../shared/settings/remote_settings_controller.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_page.dart';
import '../../../shared/widgets/app_status.dart';
import '../league_api.dart';
import '../league_controller.dart';
import '../league_models.dart';
import '../league_store.dart';
import '../widgets/league_widgets.dart';

/// The weekly league (023-weekly-leagues, stories 006 and 007): the
/// learner's tier, the time left and their group ranked by this week's XP,
/// with the move-up and move-down places marked.
///
/// It shows the copy saved on the phone at once and then a fresh one;
/// offline it keeps the saved copy, marked with its age, and with nothing
/// saved it says so rather than showing an error. The first time it shows
/// a ranking, a note says that others see the learner's first name, with
/// the "Show me in leagues" switch in it.
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({
    super.key,
    required this.api,
    required this.store,
    required this.accountSettingsApi,
    this.clock,
    this.onLeague,
  });

  final LeagueApi api;
  final LeagueStore store;
  final AccountSettingsApi accountSettingsApi;
  final DateTime Function()? clock;

  /// Called with each freshly fetched league, so the last-week result can
  /// be shown (`LeagueDependencies.showResultOnce`).
  final void Function(BuildContext context, CurrentLeague league)? onLeague;

  static const noticeKey = ValueKey('league-notice');
  static const offlineKey = ValueKey('league-offline');

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  late final LeagueController _controller = LeagueController(
    api: widget.api,
    store: widget.store,
    clock: widget.clock,
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    final league = _controller.league;
    if (_controller.state == LeagueLoadState.ready && league != null) {
      widget.onLeague?.call(context, league);
    }
  }

  /// Turns "Show me in leagues" on or off, then reloads the league.
  Future<void> _setShowInLeagues(bool show) async {
    final settings = RemoteSettingsScope.maybeOf(context);
    setState(() => _saving = true);
    try {
      if (settings != null) {
        await settings.updateAccount({
          AccountSettings.showInLeagues.key: show,
        }, widget.accountSettingsApi);
      } else {
        await widget.accountSettingsApi.update({
          AccountSettings.showInLeagues.key: show,
        });
      }
      if (!show) await _controller.dismissNotice();
      await _controller.refresh();
    } on AccountSettingsException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save. Check your connection."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      topBar: AppTopBar(
        leading: AppIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: 'Weekly league',
      ),
      scrollable: false,
      padded: false,
      body: _body(),
    );
  }

  Widget _body() {
    final league = _controller.league;
    if (league == null) {
      return switch (_controller.state) {
        LeagueLoadState.unavailable => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            child: ErrorState(
              icon: Icons.wifi_off,
              title: 'Connect to see your league',
              message: 'Your league shows here once you are online.',
              onRetry: _controller.refresh,
              retryLabel: 'Retry',
            ),
          ),
        ),
        _ => const Center(child: LoadingState()),
      };
    }
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile,
          AppSpacing.spaceXs,
          AppSpacing.marginMobile,
          AppSpacing.spaceLg,
        ),
        children: [
          if (_controller.state == LeagueLoadState.saved &&
              _controller.savedAt != null) ...[
            InfoBanner(
              key: LeagueScreen.offlineKey,
              icon: Icons.cloud_off,
              tone: AppTone.neutral,
              message:
                  'Offline · '
                  '${leagueUpdatedAgo(_controller.savedAt!, _controller.now())}',
            ),
            const SizedBox(height: AppSpacing.spaceSm),
          ],
          _Header(league: league, now: _controller.now()),
          const SizedBox(height: AppSpacing.spaceMd),
          ..._content(league),
        ],
      ),
    );
  }

  List<Widget> _content(CurrentLeague league) {
    switch (league.status) {
      case LeagueStatus.notJoined:
        return [
          EmptyState(
            icon: Icons.emoji_events,
            title: 'Earn XP this week to join',
            message:
                'Your first lesson or practice this week puts you in a '
                'group of up to 30 learners in your league.',
            action: AppButton.primary(
              label: 'Start a lesson',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ];
      case LeagueStatus.hidden:
        return [
          EmptyState(
            icon: Icons.visibility_off,
            tone: AppTone.neutral,
            title: "You're not in a league",
            message:
                '"Show me in leagues" is off, so nobody sees your name '
                'and you are not ranked.',
            action: AppButton.primary(
              label: 'Show me in leagues',
              loading: _saving,
              onPressed: _saving ? null : () => _setShowInLeagues(true),
            ),
          ),
        ];
      case LeagueStatus.joined:
        return [
          if (_controller.showNotice) ...[
            _NameNotice(
              saving: _saving,
              onGotIt: _controller.dismissNotice,
              onHide: () => _setShowInLeagues(false),
            ),
            const SizedBox(height: AppSpacing.spaceMd),
          ],
          _Ranking(league: league),
        ];
    }
  }
}

/// The tier, the time left, and who moves.
class _Header extends StatelessWidget {
  const _Header({required this.league, required this.now});

  final CurrentLeague league;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final zones = league.status == LeagueStatus.joined
        ? leagueZoneSummary(league.promoteCount, league.demoteCount)
        : null;
    return AppCard(
      child: Row(
        children: [
          TierBadge(tier: league.tier),
          const SizedBox(width: AppSpacing.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${league.tier.title} league',
                  style: AppTypography.headlineSm.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2xs),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.space2xs),
                    Flexible(
                      child: Text(
                        leagueTimeLeft(league.weekEndsAt, now),
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (zones != null)
                  Text(
                    zones,
                    style: AppTypography.bodySm.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The group in rank order, with "Moving up" after the last place that
/// moves up and "Moving down" before the first that moves down.
class _Ranking extends StatelessWidget {
  const _Ranking({required this.league});

  final CurrentLeague league;

  @override
  Widget build(BuildContext context) {
    final members = league.members;
    final firstDown = members.length - league.demoteCount;
    final rows = <Widget>[];
    for (var i = 0; i < members.length; i++) {
      if (league.demoteCount > 0 && i == firstDown && i > 0) {
        rows.add(
          const LeagueZoneDivider(key: LeagueZoneDivider.downKey, up: false),
        );
      }
      rows.add(
        LeagueRow(
          member: members[i],
          reward: league.rewardFor(members[i].rank),
        ),
      );
      if (league.promoteCount > 0 &&
          i == league.promoteCount - 1 &&
          i < members.length - 1) {
        rows.add(
          const LeagueZoneDivider(key: LeagueZoneDivider.upKey, up: true),
        );
      }
    }
    return AppCard(
      padding: AppCardPadding.none,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceXs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

/// Shown once: others in the group see the learner's first name, and the
/// switch to stay out.
class _NameNotice extends StatelessWidget {
  const _NameNotice({
    required this.saving,
    required this.onGotIt,
    required this.onHide,
  });

  final bool saving;
  final VoidCallback onGotIt;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: LeagueScreen.noticeKey,
      tone: AppTone.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Others in your league see your first name',
            style: AppTypography.labelLg.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.space2xs),
          Text(
            'You can stay out of leagues at any time in Settings.',
            style: AppTypography.bodySm.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          Wrap(
            spacing: AppSpacing.spaceXs,
            runSpacing: AppSpacing.spaceXs,
            alignment: WrapAlignment.end,
            children: [
              AppButton.text(
                label: 'Stay out',
                onPressed: saving ? null : onHide,
              ),
              AppButton.secondary(
                label: 'Got it',
                expand: false,
                size: AppButtonSize.compact,
                onPressed: onGotIt,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
