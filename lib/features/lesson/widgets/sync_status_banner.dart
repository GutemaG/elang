import 'package:flutter/material.dart';

import '../../../shared/services/lesson_pack_downloader.dart';
import '../../../shared/services/lesson_pack_store.dart';
import '../../../shared/services/sync_engine.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_tone.dart';
import '../../../shared/widgets/app_card.dart';

/// Connectivity/sync status indicator (010-offline-caching-and-sync-ui,
/// story 004) -- shown only on the skill-tree dashboard, never on
/// [LessonScreen], so it can never interrupt an active exercise by
/// construction.
///
/// Purely presentational over state [SyncEngine] already tracks plus
/// whether any pack is downloaded (needed to distinguish "offline, lessons
/// available" from "offline, nothing downloaded" per FR-5). Each message is
/// the library's [InfoBanner] (018-mobile-design-system, bolt 047), toned by
/// how much it matters, with emphasis once the queue is 30+ days old.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    super.key,
    required this.syncEngine,
    required this.lessonPackStore,
    required this.lessonPackDownloader,
  });

  final SyncEngine syncEngine;
  final LessonPackStore lessonPackStore;
  final LessonPackDownloader lessonPackDownloader;

  static const _thirtyDays = Duration(days: 30);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([syncEngine, lessonPackDownloader]),
      builder: (context, _) {
        return FutureBuilder<List<String>>(
          future: lessonPackStore.listDownloadedLessonIds(),
          builder: (context, snapshot) {
            final hasDownloadedPacks = (snapshot.data ?? const []).isNotEmpty;
            final state = _stateFor(hasDownloadedPacks);
            // "Fully synced and online" is the steady state most of the
            // time -- shown minimally rather than as a loud banner, per
            // FR-5's "unobtrusively absent/minimal" allowance.
            if (state == _IndicatorState.onlineSynced) {
              return const SizedBox.shrink();
            }
            final escalated =
                (syncEngine.oldestPendingAge ?? Duration.zero) >= _thirtyDays;
            return _Banner(state: state, escalated: escalated);
          },
        );
      },
    );
  }

  _IndicatorState _stateFor(bool hasDownloadedPacks) {
    if (syncEngine.status == SyncStatus.syncing) {
      return _IndicatorState.syncing;
    }
    if (syncEngine.status == SyncStatus.failed) {
      return _IndicatorState.syncFailedRetrying;
    }
    if (!syncEngine.isOnline) {
      return hasDownloadedPacks
          ? _IndicatorState.offlinePacksAvailable
          : _IndicatorState.offlineNothingDownloaded;
    }
    if (syncEngine.pendingCount > 0) {
      return _IndicatorState.syncing;
    }
    return _IndicatorState.onlineSynced;
  }
}

enum _IndicatorState {
  onlineSynced,
  offlinePacksAvailable,
  offlineNothingDownloaded,
  syncing,
  syncFailedRetrying,
}

class _Banner extends StatelessWidget {
  const _Banner({required this.state, required this.escalated});

  final _IndicatorState state;
  final bool escalated;

  @override
  Widget build(BuildContext context) {
    final (icon, label, tone) = switch (state) {
      _IndicatorState.onlineSynced => (
        Icons.cloud_done,
        'Synced',
        AppTone.primary,
      ),
      _IndicatorState.offlinePacksAvailable => (
        Icons.cloud_off,
        'Offline -- downloaded lessons available',
        AppTone.neutral,
      ),
      _IndicatorState.offlineNothingDownloaded => (
        Icons.cloud_off,
        'Offline -- nothing downloaded',
        AppTone.tertiary,
      ),
      _IndicatorState.syncing => (
        Icons.sync,
        'Syncing your offline progress...',
        AppTone.primary,
      ),
      _IndicatorState.syncFailedRetrying => (
        Icons.sync_problem,
        'Sync failed -- retrying...',
        AppTone.tertiary,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
      child: InfoBanner(
        icon: icon,
        tone: escalated ? AppTone.tertiary : tone,
        emphasis: escalated,
        message: escalated
            ? '$label (unsynced for 30+ days -- please reconnect soon)'
            : label,
      ),
    );
  }
}
