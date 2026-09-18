import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pending_sync_entry.dart';
import 'connectivity_monitor.dart';
import 'lesson_api.dart';
import 'pending_sync_queue_store.dart';

/// The sync queue's current draining state, for the connectivity/sync
/// indicator (story 004).
enum SyncStatus { idle, syncing, failed }

/// Owns the pending-sync queue and drains it automatically on reconnect
/// (010-offline-caching-and-sync-ui, story 003).
///
/// The only way anything enqueues an offline completion is
/// [enqueueOfflineCompletion] -- callers never touch a [PendingSyncQueueStore]
/// directly, so queue mutation and the sync-triggering logic that reacts to
/// it stay in one place. A `ChangeNotifier` (same pattern as
/// `LessonPackDownloader`) so the dashboard's indicator can react live.
class SyncEngine extends ChangeNotifier {
  SyncEngine({
    required LessonApi lessonApi,
    required ConnectivityMonitor connectivityMonitor,
    PendingSyncQueueStore? queueStore,
    Duration baseRetryDelay = const Duration(seconds: 5),
    Duration maxRetryDelay = const Duration(seconds: 60),
  }) : _lessonApi = lessonApi,
       _connectivityMonitor = connectivityMonitor,
       _queueStore = queueStore ?? SqflitePendingSyncQueueStore(),
       _baseRetryDelay = baseRetryDelay,
       _maxRetryDelay = maxRetryDelay {
    _connectivitySubscription = connectivityMonitor.onConnectivityChanged
        .listen(_onConnectivityChanged);
    unawaited(_initializeIsOnline());
  }

  final LessonApi _lessonApi;
  final ConnectivityMonitor _connectivityMonitor;
  final PendingSyncQueueStore _queueStore;
  final Duration _baseRetryDelay;
  final Duration _maxRetryDelay;

  late final StreamSubscription<bool> _connectivitySubscription;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _isSyncing = false;

  bool _isOnline = true;
  int _pendingCount = 0;
  SyncStatus _status = SyncStatus.idle;
  DateTime? _oldestPendingCompletedAt;

  bool get isOnline => _isOnline;
  int get pendingCount => _pendingCount;
  SyncStatus get status => _status;

  /// How long the oldest still-queued entry has been waiting to sync, for
  /// FR-3's 30-day escalation. `null` when the queue is empty.
  Duration? get oldestPendingAge {
    final completedAt = _oldestPendingCompletedAt;
    if (completedAt == null) return null;
    return DateTime.now().toUtc().difference(completedAt);
  }

  Future<void> _initializeIsOnline() async {
    _isOnline = await _connectivityMonitor.isOnline();
    await _refreshPendingState();
  }

  /// Call once at app/dashboard start-up: loads the current queue depth and
  /// attempts a drain if already online -- covers entries left over from a
  /// previous session (the durability requirement in FR-3/NFR).
  Future<void> refresh() async {
    await _refreshPendingState();
    if (_isOnline) unawaited(syncNow());
  }

  /// Whether any still-pending entry belongs to [lessonId] -- used by the
  /// download-management screen (story 005) to warn before deleting a pack
  /// that has unsynced completions tied to it.
  Future<bool> hasPendingEntriesForLesson(String lessonId) async {
    final pending = await _queueStore.listPending();
    return pending.any((e) => e.lessonId == lessonId);
  }

  /// Enqueues [entry] and immediately attempts a sync if online. The only
  /// entry point for adding to the queue.
  Future<void> enqueueOfflineCompletion(PendingSyncEntry entry) async {
    await _queueStore.enqueue(entry);
    await _refreshPendingState();
    if (_isOnline) unawaited(syncNow());
  }

  /// Drains the queue strictly in order, one entry at a time -- never
  /// reordered, never parallel, since FR-3 requires completion-order
  /// syncing. Stops at the first failure (the rest stay queued) and
  /// schedules a capped-exponential-backoff retry.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    if (!_isOnline) return;
    _isSyncing = true;
    _retryTimer?.cancel();

    var succeededAny = false;
    try {
      while (true) {
        final pending = await _queueStore.listPending();
        if (pending.isEmpty) break;
        final entry = pending.first;
        try {
          await _lessonApi.completeLesson(
            lessonId: entry.lessonId,
            attemptId: entry.attemptId,
            correctCount: entry.correctCount,
            totalCount: entry.totalCount,
            timeSpent: entry.timeSpent,
            beansRemainingAtEnd: entry.beansRemainingAtEnd,
            clientCompletedAt: entry.clientCompletedAt,
            missedExerciseIds: entry.missedExerciseIds,
          );
          await _queueStore.remove(entry.attemptId);
          succeededAny = true;
        } catch (_) {
          _status = SyncStatus.failed;
          _scheduleRetry();
          return;
        }
      }
      _status = SyncStatus.idle;
      _retryAttempt = 0;
    } finally {
      _isSyncing = false;
      if (succeededAny || _status != SyncStatus.failed) {
        await _refreshPendingState();
      } else {
        await _refreshPendingState(notify: false);
        notifyListeners();
      }
    }
  }

  void _scheduleRetry() {
    final delayMs =
        (_baseRetryDelay.inMilliseconds * (1 << _retryAttempt)).clamp(
          _baseRetryDelay.inMilliseconds,
          _maxRetryDelay.inMilliseconds,
        );
    _retryAttempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_isOnline) unawaited(syncNow());
    });
  }

  void _onConnectivityChanged(bool online) {
    _isOnline = online;
    if (online) {
      _retryAttempt = 0;
      unawaited(syncNow());
    }
    notifyListeners();
  }

  Future<void> _refreshPendingState({bool notify = true}) async {
    final pending = await _queueStore.listPending();
    _pendingCount = pending.length;
    _oldestPendingCompletedAt = pending.isEmpty
        ? null
        : pending.first.clientCompletedAt;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
