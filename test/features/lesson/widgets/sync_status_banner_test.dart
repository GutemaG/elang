// SyncStatusBanner tests (010-offline-caching-and-sync-ui, story 004).
//
// Covers: online + fully synced renders nothing (unobtrusive, per FR-5);
// offline distinguishes "packs available" from "nothing downloaded";
// a failed sync shows a distinguishable "retrying" state; a 30+ day-old
// queue escalates to a more visible warning.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/widgets/sync_status_banner.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/pending_sync_entry.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

const _pack = LessonContent(
  lessonId: 'lesson-a',
  skillId: 'skill-a',
  title: 'Alphabet & Fidel',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [],
);

Widget _wrapped({
  required SyncEngine syncEngine,
  required FakeLessonPackStore packStore,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SyncStatusBanner(
        syncEngine: syncEngine,
        lessonPackStore: packStore,
        lessonPackDownloader: LessonPackDownloader(
          lessonApi: ControllableLessonApi(),
          packStore: packStore,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('online with nothing pending renders nothing (unobtrusive)', (
    tester,
  ) async {
    final engine = SyncEngine(
      lessonApi: ControllableLessonApi(),
      connectivityMonitor: FakeConnectivityMonitor(online: true),
      queueStore: FakePendingSyncQueueStore(),
    );
    await tester.pumpWidget(
      _wrapped(syncEngine: engine, packStore: FakeLessonPackStore()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SyncStatusBanner), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });

  testWidgets('offline with a downloaded pack shows "lessons available"', (
    tester,
  ) async {
    final engine = SyncEngine(
      lessonApi: ControllableLessonApi(),
      connectivityMonitor: FakeConnectivityMonitor(online: false),
      queueStore: FakePendingSyncQueueStore(),
    );
    final packStore = FakeLessonPackStore()..save(_pack);
    await tester.pumpWidget(_wrapped(syncEngine: engine, packStore: packStore));
    await tester.pumpAndSettle();

    expect(
      find.text('Offline -- downloaded lessons available'),
      findsOneWidget,
    );
  });

  testWidgets('offline with nothing downloaded shows "nothing downloaded"', (
    tester,
  ) async {
    final engine = SyncEngine(
      lessonApi: ControllableLessonApi(),
      connectivityMonitor: FakeConnectivityMonitor(online: false),
      queueStore: FakePendingSyncQueueStore(),
    );
    await tester.pumpWidget(
      _wrapped(syncEngine: engine, packStore: FakeLessonPackStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline -- nothing downloaded'), findsOneWidget);
  });

  testWidgets('an actively-draining sync shows the "syncing" state', (
    tester,
  ) async {
    final api = ControllableLessonApi()
      ..completionResult = const LessonCompletionResult(
        xpEarned: 5,
        dailyXpTotal: 5,
        dailyXpTarget: 30,
        streakCount: 1,
        streakIncreasedToday: true,
        accuracyPercent: 100,
        correctCount: 1,
        totalCount: 1,
        timeSpent: Duration(seconds: 5),
      );
    final completer = Completer<void>();
    api.completeLessonGate = completer.future;
    final engine = SyncEngine(
      lessonApi: api,
      connectivityMonitor: FakeConnectivityMonitor(online: true),
      queueStore: FakePendingSyncQueueStore(),
    );
    await engine.enqueueOfflineCompletion(
      PendingSyncEntry(
        attemptId: 'a1',
        lessonId: 'lesson-a',
        correctCount: 1,
        totalCount: 1,
        timeSpent: const Duration(seconds: 5),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc(),
      ),
    );

    await tester.pumpWidget(
      _wrapped(syncEngine: engine, packStore: FakeLessonPackStore()),
    );
    await tester.pump();

    // The call is in flight (blocked on the gate) -- the drain is
    // actively running.
    expect(find.text('Syncing your offline progress...'), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a sync failure shows a distinguishable "retrying" state', (
    tester,
  ) async {
    final api = ControllableLessonApi()
      ..completeLessonError = Exception('down');
    final engine = SyncEngine(
      lessonApi: api,
      connectivityMonitor: FakeConnectivityMonitor(online: true),
      queueStore: FakePendingSyncQueueStore(),
      baseRetryDelay: const Duration(seconds: 30),
    );
    await engine.enqueueOfflineCompletion(
      PendingSyncEntry(
        attemptId: 'a1',
        lessonId: 'lesson-a',
        correctCount: 1,
        totalCount: 1,
        timeSpent: const Duration(seconds: 5),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc(),
      ),
    );

    await tester.pumpWidget(
      _wrapped(syncEngine: engine, packStore: FakeLessonPackStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync failed -- retrying...'), findsOneWidget);
    engine.dispose();
  });

  testWidgets('a queue unsynced for 30+ days escalates the warning copy', (
    tester,
  ) async {
    final engine = SyncEngine(
      lessonApi: ControllableLessonApi(),
      connectivityMonitor: FakeConnectivityMonitor(online: false),
      queueStore: FakePendingSyncQueueStore(),
    );
    await engine.enqueueOfflineCompletion(
      PendingSyncEntry(
        attemptId: 'old-1',
        lessonId: 'lesson-a',
        correctCount: 1,
        totalCount: 1,
        timeSpent: const Duration(seconds: 5),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc().subtract(
          const Duration(days: 31),
        ),
      ),
    );

    await tester.pumpWidget(
      _wrapped(syncEngine: engine, packStore: FakeLessonPackStore()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('unsynced for 30+ days'), findsOneWidget);
  });
}
