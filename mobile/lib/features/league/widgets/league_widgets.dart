import 'package:flutter/material.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_status.dart';
import '../league_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../shared/l10n/app_language.dart';

/// A tier's icon in its tone (023-weekly-leagues).
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier, this.size = 56});

  final LeagueTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.tierLeague(tier.titleIn(context.l10n)),
      child: ExcludeSemantics(
        child: IconBadge(icon: tier.icon, tone: tier.tone, size: size),
      ),
    );
  }
}

/// A member's initial on their colour (the index the backend sends).
class LeagueAvatar extends StatelessWidget {
  const LeagueAvatar({super.key, required this.member, this.size = 40});

  final LeagueMember member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colours = leagueAvatarColours(context.colors);
    final pair = colours[member.avatarColour % colours.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: pair.face, shape: BoxShape.circle),
      child: Text(
        member.initial,
        style: AppTypography.labelLg.copyWith(color: pair.letter),
      ),
    );
  }
}

/// One place in the ranking: the place, the avatar, the name ("You" added
/// for the learner), the Amole the top three would earn, and the week's XP.
/// The learner's own row is drawn in the primary tone.
class LeagueRow extends StatelessWidget {
  const LeagueRow({super.key, required this.member, this.reward = 0});

  final LeagueMember member;

  /// Amole for this place if the week ended now; 0 shows nothing.
  final int reward;

  static const double _trailingMax = 132;

  @override
  Widget build(BuildContext context) {
    final me = member.isMe;
    final tone = context.tone(AppTone.primary);
    final ink = me ? tone.ink : context.colors.onSurface;
    final l = context.l10n;
    final name = me ? l.memberYou(member.name) : member.name;
    return Semantics(
      container: true,
      label:
          l.memberRowLabel(member.rank, name, member.weeklyXp) +
          (reward > 0 ? l.memberRowReward(reward) : ''),
      excludeSemantics: true,
      child: Container(
        color: me ? tone.surface : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceMd,
          vertical: AppSpacing.spaceSm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: AppSpacing.spaceLg,
              child: Text(
                '${member.rank}',
                textAlign: TextAlign.center,
                style: AppTypography.labelLg.copyWith(
                  color: me ? tone.ink : context.colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.spaceSm),
            LeagueAvatar(member: member),
            const SizedBox(width: AppSpacing.spaceSm),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.forText(
                  AppTypography.bodyMd.copyWith(
                    color: ink,
                    fontWeight: me ? FontWeight.w700 : FontWeight.w500,
                  ),
                  name,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.spaceXs),
            // The reward and the XP never take more than about half the
            // row: on a narrow phone with large text they shrink, so the
            // name always keeps some room.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _trailingMax),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reward > 0) ...[
                      CountBadge(
                        label: '+$reward',
                        icon: Icons.diamond,
                        tone: AppTone.secondary,
                      ),
                      const SizedBox(width: AppSpacing.spaceXs),
                    ],
                    Text(
                      l.xpAmount('${member.weeklyXp}'),
                      style: AppTypography.labelMd.copyWith(color: ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The line between the move-up places and the rest, or the rest and the
/// move-down places: an arrow and a label between two hairlines.
class LeagueZoneDivider extends StatelessWidget {
  const LeagueZoneDivider({super.key, required this.up});

  final bool up;

  static const upKey = ValueKey('league-zone-up');
  static const downKey = ValueKey('league-zone-down');

  @override
  Widget build(BuildContext context) {
    final tone = context.tone(up ? AppTone.primary : AppTone.tertiary);
    final line = Expanded(
      child: SizedBox(height: 1, child: ColoredBox(color: tone.border)),
    );
    final label = up ? context.l10n.movingUp : context.l10n.movingDown;
    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceMd,
          vertical: AppSpacing.space2xs,
        ),
        child: Row(
          children: [
            line,
            const SizedBox(width: AppSpacing.spaceXs),
            Icon(
              up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: tone.ink,
            ),
            const SizedBox(width: AppSpacing.space2xs),
            Text(label, style: AppTypography.labelSm.copyWith(color: tone.ink)),
            const SizedBox(width: AppSpacing.spaceXs),
            line,
          ],
        ),
      ),
    );
  }
}

/// "3 days left", "5 hours left", or "Ends soon" in the last hour.
/// In [l] (English by default).
String leagueTimeLeft(DateTime endsAt, DateTime now, [AppLocalizations? l]) {
  l ??= AppLocalizationsEn();
  final left = endsAt.difference(now);
  if (left.inHours >= 24) return l.daysLeft(left.inDays);
  if (left.inHours >= 1) return l.hoursLeft(left.inHours);
  return l.endsSoon;
}

/// "Top 2 move up · bottom 1 moves down", leaving out a part that is 0.
/// In [l] (English by default).
String? leagueZoneSummary(int promote, int demote, [AppLocalizations? l]) {
  l ??= AppLocalizationsEn();
  final parts = [
    if (promote > 0) l.zoneTop(promote),
    if (demote > 0)
      promote > 0 ? l.zoneBottomAfter(demote) : l.zoneBottom(demote),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// "updated just now", "updated 5 min ago", "updated 2 h ago",
/// "updated 3 days ago".
/// In [l] (English by default).
String leagueUpdatedAgo(DateTime savedAt, DateTime now, [AppLocalizations? l]) {
  l ??= AppLocalizationsEn();
  final ago = now.difference(savedAt);
  if (ago.inMinutes < 1) return l.updatedJustNow;
  if (ago.inHours < 1) return l.updatedMinutesAgo(ago.inMinutes);
  if (ago.inDays < 1) return l.updatedHoursAgo(ago.inHours);
  return l.updatedDaysAgo(ago.inDays);
}
