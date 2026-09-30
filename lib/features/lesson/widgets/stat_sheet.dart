import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/beans_status.dart';
import '../../../shared/models/stat_history.dart';
import '../../../shared/services/lesson_api_exception.dart';
import '../../../shared/theme/app_theme_context.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_status.dart';
import 'amole_history.dart';
import 'bean_timer_card.dart';
import 'streak_calendar.dart';

/// Opens the stats sheet on [initial]'s tab (013-stat-pill-interactions,
/// bolt 060). A tap outside, a drag down or "Close" closes it.
///
/// [onBeansChanged] hears every change to the beans the sheet makes -- a
/// bean arriving while it is open, or a refill -- so the dashboard's pill
/// changes with it.
///
/// [loadStreak] and [loadAmole] fetch the streak calendar's days and the
/// recent Amole entries (bolt 061), each the first time its tab shows.
Future<void> showStatSheet(
  BuildContext context, {
  required StatKind initial,
  required int streakCount,
  required int totalXp,
  required BeansStatus beans,
  required bool offline,
  required Future<RefillResult> Function() refill,
  required ValueChanged<BeansStatus> onBeansChanged,
  required StreakLoader loadStreak,
  required AmoleLoader loadAmole,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => StatSheet(
      initial: initial,
      streakCount: streakCount,
      totalXp: totalXp,
      beans: beans,
      offline: offline,
      refill: refill,
      onBeansChanged: onBeansChanged,
      loadStreak: loadStreak,
      loadAmole: loadAmole,
    ),
  );
}

typedef StreakLoader = Future<StreakHistory> Function({
  required DateTime from,
  required DateTime to,
});
typedef AmoleLoader = Future<List<AmoleEntry>> Function({int limit});

/// One sheet for all four counters. Its tabs are the counters themselves,
/// full size, so a tap that landed on the neighbouring counter in the
/// dashboard's crowded header is put right with one more tap.
class StatSheet extends StatefulWidget {
  const StatSheet({
    super.key,
    required this.initial,
    required this.streakCount,
    required this.totalXp,
    required this.beans,
    required this.offline,
    required this.refill,
    required this.onBeansChanged,
    required this.loadStreak,
    required this.loadAmole,
    this.now = DateTime.now,
  });

  final StatKind initial;
  final int streakCount;
  final int totalXp;
  final BeansStatus beans;

  /// The dashboard is its saved copy: a refill cannot be sent.
  final bool offline;
  final Future<RefillResult> Function() refill;
  final ValueChanged<BeansStatus> onBeansChanged;
  final StreakLoader loadStreak;
  final AmoleLoader loadAmole;

  /// The clock, for tests.
  final DateTime Function() now;

  /// A tab's tap height.
  static const double tabHeight = 48;

  @override
  State<StatSheet> createState() => _StatSheetState();
}

class _StatSheetState extends State<StatSheet> {
  late StatKind _tab = widget.initial;
  late BeansStatus _beans;
  late DateTime _now;
  Timer? _ticker;
  bool _refilling = false;
  String? _refillError;

  /// Each fetched the first time its tab shows, and kept while the sheet
  /// is open; never on the saved (offline) dashboard.
  final _streak = _Load<StreakHistory>();
  final _amole = _Load<List<AmoleEntry>>();

  @override
  void initState() {
    super.initState();
    _now = widget.now();
    _beans = widget.beans.at(_now);
    // A bean that came while the dashboard sat still; told after this
    // frame, since the dashboard cannot rebuild while the sheet builds.
    if (_beans.beans != widget.beans.beans) {
      final caught = _beans;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onBeansChanged(caught),
      );
    }
    _syncTicker();
    _loadForTab();
  }

  /// Starts the tab's fetch if it has none yet.
  void _loadForTab() {
    if (widget.offline) return;
    switch (_tab) {
      case StatKind.streak:
        final today = utcDay(_now);
        _start(
          _streak,
          () => widget.loadStreak(
            from: StreakCalendar.firstDayShown(today),
            to: today,
          ),
        );
      case StatKind.amole:
        _start(_amole, () => widget.loadAmole(limit: 20));
      case StatKind.beans || StatKind.xp:
        break;
    }
  }

  void _start<T>(_Load<T> load, Future<T> Function() fetch) {
    if (load.loading || load.data != null) return;
    load
      ..loading = true
      ..error = null;
    fetch().then(
      (data) {
        if (!mounted) return;
        setState(() {
          load
            ..loading = false
            ..data = data;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          load
            ..loading = false
            ..error = error;
        });
      },
    );
  }

  void _retry<T>(_Load<T> load) {
    setState(() {
      load.error = null;
      _loadForTab();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Brings the beans up to [_now], telling the dashboard when a bean came.
  void _catchUp() {
    final before = _beans.beans;
    _beans = _beans.at(_now);
    if (_beans.beans != before) widget.onBeansChanged(_beans);
  }

  /// Ticks once a second while the beans tab is counting down, and not at
  /// all otherwise.
  void _syncTicker() {
    final counting =
        _tab == StatKind.beans && !_beans.isFull && _beans.nextBeanAt != null;
    if (counting && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _now = widget.now();
          _catchUp();
          _syncTicker();
        });
      });
    } else if (!counting) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _choose(StatKind kind) {
    setState(() {
      _tab = kind;
      _now = widget.now();
      _catchUp();
      _syncTicker();
      _loadForTab();
    });
  }

  Future<void> _refill() async {
    setState(() {
      _refilling = true;
      _refillError = null;
    });
    String? error;
    try {
      final result = await widget.refill();
      if (!mounted) return;
      switch (result) {
        case RefillSuccess():
          _beans = _beans.refilled(result);
          widget.onBeansChanged(_beans);
          // The list would be missing this refill; fetched again when shown.
          if (!_amole.loading) _amole.data = null;
        case RefillFailure():
          error = 'Not enough Amole for a refill.';
      }
    } on LessonApiException {
      error = "Couldn't refill. Check your connection and try again.";
    }
    if (!mounted) return;
    setState(() {
      _refilling = false;
      _refillError = error;
      _syncTicker();
    });
  }

  @override
  Widget build(BuildContext context) {
    final close = AppButton.text(
      label: 'Close',
      onPressed: () => Navigator.of(context).pop(),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.spaceXs,
          children: [
            _tabFor(StatKind.streak, widget.streakCount),
            _tabFor(StatKind.beans, _beans.beans, max: _beans.beansMax),
            _tabFor(StatKind.xp, widget.totalXp),
            _tabFor(StatKind.amole, _beans.amoleBalance),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceSm),
        switch (_tab) {
          StatKind.beans => _beansTab(close),
          StatKind.streak => _streakTab(close),
          StatKind.xp => _StatExplainer(
            icon: Icons.bolt,
            tone: AppTone.secondary,
            title: '${groupDigits(widget.totalXp)} XP',
            body:
                'You earn XP for every answer you get right in lessons '
                'and Practice.',
            close: close,
          ),
          StatKind.amole => _amoleTab(close),
        },
      ],
    );
  }

  Widget _streakTab(Widget close) {
    final count = widget.streakCount;
    final history = _streak.data;
    final longest = history?.longestStreak;
    return _TabBody(
      icon: Icons.local_fire_department,
      tone: AppTone.secondary,
      title: count == 1 ? '1 day streak' : '$count day streak',
      subtitle: longest == null
          ? 'A day counts when you finish a lesson.'
          : 'Longest: $longest ${longest == 1 ? 'day' : 'days'}',
      close: close,
      child: _loaded(
        _streak,
        what: 'calendar',
        onRetry: () => _retry(_streak),
        builder: (history) =>
            StreakCalendar(history: history, today: utcDay(_now)),
      ),
    );
  }

  Widget _amoleTab(Widget close) {
    return _TabBody(
      icon: Icons.diamond,
      tone: AppTone.primary,
      title: '${groupDigits(_beans.amoleBalance)} Amole',
      subtitle:
          'Earned by lessons, perfect lessons, streak milestones and '
          'Practice. Spent on bean refills.',
      close: close,
      child: _loaded(
        _amole,
        what: 'list',
        onRetry: () => _retry(_amole),
        builder: (entries) => AmoleHistoryList(entries: entries),
      ),
    );
  }

  /// A tab's fetched part: offline, shown, failed or still coming.
  Widget _loaded<T>(
    _Load<T> load, {
    required String what,
    required VoidCallback onRetry,
    required Widget Function(T data) builder,
  }) {
    final data = load.data;
    if (widget.offline) {
      return _Note(
        icon: Icons.cloud_off,
        text: 'The $what needs a connection. Connect to see it.',
      );
    }
    if (data != null) return builder(data);
    if (load.error != null) {
      return ErrorState(
        title: "Couldn't load the $what",
        message: 'Check your connection and try again.',
        onRetry: onRetry,
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.spaceLg),
      child: Center(child: AppSpinner()),
    );
  }

  Widget _tabFor(StatKind kind, int value, {int? max}) => StatPill(
    key: ValueKey('stat-sheet-tab-${kind.name}'),
    kind: kind,
    value: value,
    max: max,
    selected: _tab == kind,
    tapHeight: StatSheet.tabHeight,
    onPressed: () => _choose(kind),
  );

  Widget _beansTab(Widget close) {
    final beans = _beans;
    final badge = CountBadge(
      label: '${beans.beans} / ${beans.beansMax}',
      icon: Icons.local_cafe,
      tone: AppTone.tertiary,
    );
    if (beans.isFull) {
      final every = beans.regenMinutesPerBean;
      return SheetHero(
        illustration: const Icon(Icons.local_cafe_outlined),
        illustrationBadge: badge,
        illustrationSize: _StatExplainer.illustrationSize,
        tone: AppTone.tertiary,
        title: 'Your beans are full',
        body: every > 0
            ? 'Each wrong answer in a lesson uses a bean. They come back '
                  'on their own, one every $every '
                  '${every == 1 ? 'minute' : 'minutes'}.'
            : 'Each wrong answer in a lesson uses a bean. They come back '
                  'on their own over time.',
        textAction: close,
      );
    }

    final String label;
    if (widget.offline) {
      label = 'Refill needs a connection';
    } else if (beans.canAffordRefill) {
      label = 'Refill with Amole';
    } else {
      label = 'Not enough Amole';
    }
    final canRefill = !widget.offline && beans.canAffordRefill;
    final error = _refillError;
    return SheetHero(
      illustration: const Icon(Icons.local_cafe_outlined),
      illustrationBadge: badge,
      illustrationSize: _StatExplainer.illustrationSize,
      tone: AppTone.tertiary,
      title: 'Beans',
      body:
          'Each wrong answer in a lesson uses a bean. They come back on '
          'their own, or you can refill them now with Amole.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // An old offline copy has no timing to count down from.
          if (beans.nextBeanAt != null) BeanTimerCard(status: beans, now: _now),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.spaceXs),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: context.colors.error),
            ),
          ],
        ],
      ),
      primaryAction: AppButton.accent(
        label: label,
        onPressed: canRefill ? _refill : null,
        loading: _refilling,
        leading: const Icon(Icons.bolt),
        badge: beans.refillCostAmole > 0
            ? AppButtonBadge(
                label: '${beans.refillCostAmole} Amole',
                icon: Icons.diamond,
              )
            : null,
      ),
      textAction: close,
    );
  }
}

/// A counter's short explanation: the XP tab.
class _StatExplainer extends StatelessWidget {
  const _StatExplainer({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.close,
  });

  final IconData icon;
  final AppTone tone;
  final String title;
  final String body;
  final Widget close;

  /// Smaller than a standalone sheet's, so the tabs and the body fit a
  /// small phone without scrolling.
  static const double illustrationSize = 88;

  @override
  Widget build(BuildContext context) => SheetHero(
    illustration: Icon(icon),
    illustrationSize: illustrationSize,
    tone: tone,
    title: title,
    body: body,
    textAction: close,
  );
}

/// A fetch the sheet makes once per opening.
class _Load<T> {
  T? data;
  Object? error;
  bool loading = false;
}

/// The streak and Amole tabs: a compact header over their fetched part,
/// so a calendar fits a small phone without the big picture.
class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.close,
    required this.child,
  });

  final IconData icon;
  final AppTone tone;
  final String title;
  final String subtitle;
  final Widget close;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconBadge(icon: icon, tone: tone),
            const SizedBox(width: AppSpacing.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTypography.headlineSm.copyWith(
                        color: context.tone(tone).ink,
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceSm),
        child,
        const SizedBox(height: AppSpacing.spaceSm),
        Center(child: close),
      ],
    );
  }
}

/// A quiet line with an icon, for what cannot be shown offline.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceMd),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.spaceXs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySm.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
