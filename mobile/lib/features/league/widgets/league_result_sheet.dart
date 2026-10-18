import 'package:flutter/material.dart';

import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_status.dart';
import '../league_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../shared/l10n/app_language.dart';

/// How last week's league went (023-weekly-leagues, story 008): moved up,
/// stayed or dropped, the place and XP, and any Amole earned. Laid out
/// with [SheetHero], the new tier's badge as the picture.
class LeagueResultSheet extends StatelessWidget {
  const LeagueResultSheet({super.key, required this.result});

  final LeagueResult result;

  /// The headline, in [l] (English by default).
  static String title(LeagueResult r, [AppLocalizations? l]) {
    l ??= AppLocalizationsEn();
    final tier = r.tierAfter.titleIn(l);
    final up = r.tierAfter.index > r.tier.index;
    final down = r.tierAfter.index < r.tier.index;
    if (up) return l.movedUpTo(tier);
    if (down) return l.droppedTo(tier);
    return l.stayedIn(tier);
  }

  /// The place and XP, in [l] (English by default).
  static String body(LeagueResult r, [AppLocalizations? l]) {
    l ??= AppLocalizationsEn();
    final rank = r.rank;
    final parts = <String>[
      if (rank != null)
        l.finishedPlace(ordinal(rank, l), r.groupSize, r.weeklyXp)
      else
        l.leftBeforeEnd,
      if (r.tierAfter.index < r.tier.index) l.climbBack,
    ];
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return SheetHero(
      illustration: Icon(result.tierAfter.icon),
      illustrationSize: 96,
      tone: result.tierAfter.tone,
      title: title(result, context.l10n),
      body: body(result, context.l10n),
      content: result.rewardAmole > 0
          ? Center(
              child: CountBadge(
                label: context.l10n.amoleAmount('+${result.rewardAmole}'),
                icon: Icons.diamond,
                tone: result.tierAfter.tone,
              ),
            )
          : null,
      primaryAction: AppButton.primary(
        label: context.l10n.continueButton,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// "1st", "2nd", "3rd", "4th", ..., "11th", "12th", "13th", "21st".
///
/// In [l]'s language when it is not English: "2ኛ", "2ffaa".
String ordinal(int n, [AppLocalizations? l]) {
  if (l != null && l.localeName != 'en') return l.ordinal(n);
  final lastTwo = n % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// Shows [result]; resolves when the sheet is closed, however.
Future<void> showLeagueResultSheet(BuildContext context, LeagueResult result) =>
    showAppSheet<void>(
      context: context,
      builder: (_) => LeagueResultSheet(result: result),
    );
