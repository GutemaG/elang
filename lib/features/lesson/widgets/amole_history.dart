import 'package:flutter/material.dart';

import '../../../shared/models/stat_history.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_status.dart';
import '../../../shared/l10n/app_language.dart';

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
          context.l10n.noAmoleYet,
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
    final l = context.l10n;
    final reason = entry.reasonIn(l);
    return Semantics(
      label: l.amoleEntryLabel(
        reason,
        earned ? l.plus : l.minus,
        groupDigits(amount.abs()),
        l.dayMonth(when.day, l.monthName(when.month)),
      ),
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
                    reason,
                    style: AppTypography.bodyMd.copyWith(
                      color: context.colors.onSurface,
                    ),
                  ),
                  Text(
                    l.dayMonth(when.day, l.monthShort(when.month)),
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
                    ? context.colors.primaryAccent
                    : context.colors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
