// SyncEngine tests (010-offline-caching-and-sync-ui, story 003).
//
// Covers: an offline-queued entry doesn't sync until online; enqueuing
// while online syncs immediately; multiple entries drain strictly in
// completion order; a failure stops draining (leaves the rest queued) and
// schedules a capped-exponential-backoff retry that eventually succeeds;
// reconnecting triggers an automatic drain; `refresh()` drains entries left
// over from a previous session; `oldestPendingAge`/
// `hasPendingEntriesForLesson` reflect queue state correctly.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/pending_sync_entry.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../helpers/controllable_lesson_api.dart';
import '../../helpers/fake_connectivity_monitor.dart';
import '../../helpers/fake_pending_sync_queue_store.dart';

PendingSyncEntry _entry(
  String attemptId, {
  String lessonId = 'lesson-a',
  List<String> missedExerciseIds = const [],
}) {
  return PendingSyncEntry(
    attemptId: attemptId,
    lessonId: lessonId,
    correctCount: 2,
    totalCount: 2,
    timeSpent: const Duration(seconds: 10),
    beansRemainingAtEnd: 4,
    clientCompletedAt: DateTime.now().toUtc(),
    missedExerciseIds: missedExerciseIds,
  );
}

ControllableLessonApi _apiWithCompletionResult() {
  return ControllableLessonApi()
    ..completionResult = const LessonCompletionResult(
      xpEarned: 10,
      dailyXpTotal: 10,
      dailyXpTarget: 30,
      streakCount: 1,
      streakIncreasedToday: true,
      accuracyPercent: 100,
      correctCount: 2,
      totalCount: 2,
      timeSpent: Duration(seconds: 10),
    );
}

void main() {
  test('an offline-queued entry does not sync until online', () async {
    final api = _apiWithCompletionResult();
    final engine = SyncEngine(
      lessonApi: api,
      connectivityMonitor: FakeConnectivityMonitor(online: false),
      queueStore: FakePendingSyncQueueStore(),
    );

    await engine.enqueueOfflineCompletion(_entry('a1'));
    await Future<void>.delayed(Duration.zero);

    expect(api.completeLessonCalls, isEmpty);
    expect(engine.pendingCount, 1);
  });

  test('enqueuing while online syncs immediately and empties the queue', () async {
    final api = _apiWithCompletionResult();
    final engine = SyncEngine(
      lessonApi: api,
      connectivityMonitor: FakeConnectivityMonitor(online: true),
      queueStore: FakePendingSyncQueueStore(),
    );

    await engine.enqueueOfflineCompletion(_entry('a1'));
    await Future<void>.delayed(Duration.zero);

    expect(api.completeLessonCalls, hasLength(1));
    expect(api.completeLessonCalls.single.attemptId, 'a1');
    expect(engine.pendingCount, 0);
    expect(engine.status, SyncStatus.idle);
  });

  test(
    'replays a queued entry\'s missedExerciseIds unchanged (bolt 019, ADR-10)',
    () async {
      final api = _apiWithCompletionResult();
      final engine = SyncEngine(
        lessonApi: api,
        connectivityMonitor: FakeConnectivityMonitor(online: true),
        queueStore: FakePendingSyncQueueStore(),
      );

      await engine.enqueueOfflineCompletion(
        _entry('a1', missedExerciseIds: ['ex-1', 'ex-2']),
      );
      await Future<void>.delayed(Duration.zero);

      expect(api.completeLessonCalls.single.missedExerciseIds, ['ex-1', 'ex-2']);
    },
  );

  test('multiple queued entries drain strictly in completion order', () async {
    final api = _apiWithCompletionResult();
    final connectivity = FakeConnectivityMonitor(online: false);
    final engine = SyncEngine(
      lessonApi: api,
      connectivityMonitor: connectivity,
      queueStore: FakePendingSyncQueueStore(),
    );

    await engine.enqueueOfflineCompletion(_entry('a1'));
    await engine.enqueueOfflineCompletion(_entry('a2'));
    await engine.enqueueOfflineCompletion(_entry('a3'));
    expect(api.completeLessonCalls, isEmpty);

    // Reconnect -- should drain a1, a2, a3 in that exact order.
    connectivity.setOnline(true);
    await Future<void>.delayed(Duration.zero);

    expect(
      api.completeLessonCalls.map((c) => c.attemptId).toList(),
      ['a1', 'a2', 'a3'],
    );
    expect(engine.pendingCount, 0);
  });

  test(
    'a failure stops draining, leaves the rest queued, and retries with backoff until it succeeds',
    () async {
      final api = _apiWithCompletionResult()
        ..completeLessonError = Exception('server error');
      final connectivity = FakeConnectivityMonitor(online: false);
      final engine = SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: FakePendingSyncQueueStore(),
        baseRetryDelay: const Duration(milliseconds: 10),
        maxRetryDelay: const Duration(milliseconds: 40),
      );

      await engine.enqueueOfflineCompletion(_entry('a1'));
      await engine.enqueueOfflineCompletion(_entry('a2'));

      connectivity.setOnline(true);
      await Future<void>.delayed(Duration.zero);

      // First attempt (a1) failed -- nothing removed, status failed.
      expect(engine.status, SyncStatus.failed);
      expect(engine.pendingCount, 2);
      expect(api.completeLessonCalls, hasLength(1));

      // Clear the failure and let the scheduled retry fire.
      api.completeLessonError = null;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(engine.status, SyncStatus.idle);
      expect(engine.pendingCount, 0);
      expect(
        api.completeLessonCalls.map((c) => c.attemptId).toList(),
        ['a1', 'a1', 'a2'],
      );
    },
  );

  test('refresh() drains entries left over from a previous session', () async {
    final api = _apiWithCompletionResult();
    final queueStore = FakePendingSyncQueueStore();
    await queueStore.enqueue(_entry('leftover-1'));
    await queueStore.enqueue(_entry('leftover-2'));

    final engine = SyncEngine(
      lessonApi: api,
      connectivityMonitor: FakeConnectivityMonitor(online: true),
      queueStore: queueStore,
    );

    await engine.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(engine.pendingCount, 0);
    expect(
      api.completeLessonCalls.map((c) => c.attemptId).toList(),
      ['leftover-1', 'leftover-2'],
    );
  });

  test('oldestPendingAge reflects the head-of-queue entry, null when empty', () async {
    final engine = SyncEngine(
      lessonApi: _apiWithCompletionResult(),
      connectivityMonitor: FakeConnectivityMonitor(online: false),
      queueStore: FakePendingSyncQueueStore(),
    );

    expect(engine.oldestPendingAge, isNull);

    final old = DateTime.now().toUtc().subtract(const Duration(days: 31));
    await engine.enqueueOfflineCompletion(
      PendingSyncEntry(
        attemptId: 'old-1',
        lessonId: 'lesson-a',
        correctCount: 1,
        totalCount: 1,
        timeSpent: const Duration(seconds: 5),
        beansRemainingAtEnd: 5,
        clientCompletedAt: old,
      ),
    );

    expect(engine.oldestPendingAge! >= const Duration(days: 31), isTrue);
  });

  test(
    'a failure partway through a drain (not on the first entry) leaves only the failed-and-later entries queued, and resumes correctly with no duplication',
    () async {
      final api = _apiWithCompletionResult()
        ..completeLessonFailingAttemptIds = {'b2'};
      final connectivity = FakeConnectivityMonitor(online: false);
      final engine = SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: FakePendingSyncQueueStore(),
      );

      await engine.enqueueOfflineCompletion(_entry('b1'));
      await engine.enqueueOfflineCompletion(_entry('b2'));
      await engine.enqueueOfflineCompletion(_entry('b3'));

      // Connectivity "drops" partway through the drain, manifesting as
      // b2's call failing (b1 already succeeded; b3 never attempted since
      // the drain stops at the first failure).
      connectivity.setOnline(true);
      await Future<void>.delayed(Duration.zero);

      expect(engine.pendingCount, 2); // b2, b3 -- b1 already synced
      expect(
        api.completeLessonCalls.map((c) => c.attemptId).toList(),
        ['b1', 'b2'],
      );

      // "Reconnect" -- b2 and then b3 sync, in order, with no duplicate
      // send for b1 and no entry skipped.
      api.completeLessonFailingAttemptIds = {};
      await engine.syncNow();
      await Future<void>.delayed(Duration.zero);

      expect(engine.pendingCount, 0);
      expect(
        api.completeLessonCalls.map((c) => c.attemptId).toList(),
        ['b1', 'b2', 'b2', 'b3'],
      );
    },
  );

  test(
    'rapid connectivity flapping does not cause overlapping sync attempts for the same entry',
    () async {
      final api = _apiWithCompletionResult();
      final connectivity = FakeConnectivityMonitor(online: false);
      final engine = SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: FakePendingSyncQueueStore(),
      );

      final completer = Completer<void>();
      api.completeLessonGate = completer.future;

      await engine.enqueueOfflineCompletion(_entry('a1'));
      connectivity.setOnline(true);
      await Future<void>.delayed(Duration.zero);

      // The first attempt is now in flight (blocked on the gate). Flap
      // connectivity rapidly while it's still pending.
      connectivity.setOnline(false);
      connectivity.setOnline(true);
      connectivity.setOnline(false);
      connectivity.setOnline(true);
      await Future<void>.delayed(Duration.zero);

      // Still only one attempt in flight -- the `_isSyncing` guard
      // prevented the flapping from spawning overlapping drains.
      expect(api.completeLessonCalls, hasLength(1));

      completer.complete();
      await Future<void>.delayed(Duration.zero);

      expect(api.completeLessonCalls, hasLength(1));
      expect(engine.pendingCount, 0);
    },
  );

  test('an entry unsynced for 30+ days still syncs normally, never silently dropped', () async {
    final api = _apiWithCompletionResult();
    final connectivity = FakeConnectivityMonitor(online: false);
    final engine = SyncEngine(
      lessonApi: api,
      connectivityMonitor: connectivity,
      queueStore: FakePendingSyncQueueStore(),
    );

    await engine.enqueueOfflineCompletion(
      PendingSyncEntry(
        attemptId: 'ancient',
        lessonId: 'lesson-a',
        correctCount: 1,
        totalCount: 1,
        timeSpent: const Duration(seconds: 5),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc().subtract(
          const Duration(days: 40),
        ),
      ),
    );

    connectivity.setOnline(true);
    await Future<void>.delayed(Duration.zero);

    expect(api.completeLessonCalls.map((c) => c.attemptId), ['ancient']);
    expect(engine.pendingCount, 0);
  });

  test('hasPendingEntriesForLesson reflects queue contents by lessonId', () async {
    final engine = SyncEngine(
      lessonApi: _apiWithCompletionResult(),
      connectivityMonitor: FakeConnectivityMonitor(online: false),
      queueStore: FakePendingSyncQueueStore(),
    );

    expect(await engine.hasPendingEntriesForLesson('lesson-a'), isFalse);

    await engine.enqueueOfflineCompletion(_entry('a1', lessonId: 'lesson-a'));

    expect(await engine.hasPendingEntriesForLesson('lesson-a'), isTrue);
    expect(await engine.hasPendingEntriesForLesson('lesson-b'), isFalse);
  });
}
