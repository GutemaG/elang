import 'package:flutter/material.dart';

import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_status.dart';
import '../league_models.dart';

/// How last week's league went (023-weekly-leagues, story 008): moved up,
/// stayed or dropped, the place and XP, and any Amole earned. Laid out
/// with [SheetHero], the new tier's badge as the picture.
class LeagueResultSheet extends StatelessWidget {
  const LeagueResultSheet({super.key, required this.result});

  final LeagueResult result;

  static String title(LeagueResult r) {
    final up = r.tierAfter.index > r.tier.index;
    final down = r.tierAfter.index < r.tier.index;
    if (up) return 'You moved up to ${r.tierAfter.title}!';
    if (down) return 'You dropped to ${r.tierAfter.title}';
    return 'You stayed in ${r.tierAfter.title}';
  }

  static String body(LeagueResult r) {
    final rank = r.rank;
    final parts = <String>[
      if (rank != null)
        'You finished ${ordinal(rank)} of ${r.groupSize} with '
            '${r.weeklyXp} XP.'
      else
        'You had left the league before the week ended.',
      if (r.tierAfter.index < r.tier.index) 'Climb back this week!',
    ];
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return SheetHero(
      illustration: Icon(result.tierAfter.icon),
      illustrationSize: 96,
      tone: result.tierAfter.tone,
      title: title(result),
      body: body(result),
      content: result.rewardAmole > 0
          ? Center(
              child: CountBadge(
                label: '+${result.rewardAmole} Amole',
                icon: Icons.diamond,
                tone: result.tierAfter.tone,
              ),
            )
          : null,
      primaryAction: AppButton.primary(
        label: 'Continue',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// "1st", "2nd", "3rd", "4th", ..., "11th", "12th", "13th", "21st".
String ordinal(int n) {
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
