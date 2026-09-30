import 'package:flutter/material.dart';

import '../../../shared/models/stat_history.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_status.dart';

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _longMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The recent Amole entries, newest first (013-stat-pill-interactions,
/// bolt 061): why, when, and how much, earned in green and spent in the
/// error colour. Each entry is one phrase for a screen reader.
class AmoleHistoryList extends StatelessWidget {
  const AmoleHistoryList({super.key, required this.entries});

  final List<AmoleEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceMd),
        child: Text(
          'No Amole yet',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) Divider(height: 1, color: context.colors.outlineVariant),
          _Entry(entry: entries[i]),
        ],
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.entry});

  final AmoleEntry entry;

  @override
  Widget build(BuildContext context) {
    final amount = entry.amount;
    final when = entry.createdAt.toLocal();
    final earned = amount >= 0;
    final shown = earned
        ? '+${groupDigits(amount)}'
        : '−${groupDigits(-amount)}';
    return Semantics(
      label:
          '${entry.reason}, ${earned ? 'plus' : 'minus'} '
          '${groupDigits(amount.abs())} Amole, '
          '${when.day} ${_longMonths[when.month - 1]}',
      container: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceXs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.reason,
                    style: AppTypography.bodyMd.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                  Text(
                    '${when.day} ${_shortMonths[when.month - 1]}',
                    style: AppTypography.labelSm.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              shown,
              style: AppTypography.labelLg.copyWith(
                color: earned
                    ? context.colors.primaryContainer
                    : context.colors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
