// Download-management screen tests (010-offline-caching-and-sync-ui,
// story 005).
//
// Covers: an empty state when nothing's downloaded; downloaded packs list
// with title + approximate size; deleting a pack removes it and frees the
// store; deleting a pack with pending, not-yet-synced completions shows a
// distinct warning instead of the generic delete copy; canceling leaves
// the pack in place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/download_management_screen.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/pending_sync_entry.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

const _packA = LessonContent(
  lessonId: 'lesson-a',
  skillId: 'skill-a',
  title: 'Alphabet & Fidel',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    MultipleChoiceExercise(
      id: 'a-1',
      prompt: 'ሀ',
      promptTranslation: 'Which sound?',
      options: ['ha', 'le'],
      correctOptionIndex: 0,
    ),
  ],
);

Widget _wrapped({
  required FakeLessonPackStore packStore,
  required SyncEngine syncEngine,
}) {
  return MaterialApp(
    home: DownloadManagementScreen(
      lessonPackStore: packStore,
      syncEngine: syncEngine,
    ),
  );
}

SyncEngine _engine({bool online = true}) => SyncEngine(
  lessonApi: ControllableLessonApi(),
  connectivityMonitor: FakeConnectivityMonitor(online: online),
  queueStore: FakePendingSyncQueueStore(),
);

void main() {
  testWidgets('shows an empty state when nothing is downloaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapped(packStore: FakeLessonPackStore(), syncEngine: _engine()),
    );
    await tester.pumpAndSettle();

    expect(find.text('No downloaded lessons yet.'), findsOneWidget);
  });

  testWidgets('lists a downloaded pack with its title and approximate size', (
    tester,
  ) async {
    final packStore = FakeLessonPackStore()
      ..fakeSizeBytes = 2048
      ..save(_packA);
    await tester.pumpWidget(_wrapped(packStore: packStore, syncEngine: _engine()));
    await tester.pumpAndSettle();

    expect(find.text('Alphabet & Fidel'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
  });

  testWidgets(
    'deleting a pack with no pending sync shows the generic warning and removes it',
    (tester) async {
      final packStore = FakeLessonPackStore()..save(_packA);
      await tester.pumpWidget(
        _wrapped(packStore: packStore, syncEngine: _engine()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete "Alphabet & Fidel"?'), findsOneWidget);
      expect(
        find.textContaining("Your synced progress is not affected"),
        findsOneWidget,
      );
      expect(find.textContaining("hasn't synced yet"), findsNothing);

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(await packStore.isDownloaded('lesson-a'), isFalse);
      expect(find.text('No downloaded lessons yet.'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting a pack with a pending sync entry shows the pending-sync warning instead',
    (tester) async {
      final packStore = FakeLessonPackStore()..save(_packA);
      final engine = _engine(online: false);
      await engine.enqueueOfflineCompletion(
        PendingSyncEntry(
          attemptId: 'attempt-1',
          lessonId: 'lesson-a',
          correctCount: 1,
          totalCount: 1,
          timeSpent: const Duration(seconds: 5),
          beansRemainingAtEnd: 5,
          clientCompletedAt: DateTime.now().toUtc(),
        ),
      );
      await tester.pumpWidget(_wrapped(packStore: packStore, syncEngine: engine));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining("hasn't synced yet"), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Cancelled -- still there.
      expect(await packStore.isDownloaded('lesson-a'), isTrue);
      expect(find.text('Alphabet & Fidel'), findsOneWidget);
    },
  );

  // 010-multi-language-courses (bolt 027, story 003): each pack shows its
  // course, packs from two courses are both kept, and deleting one leaves the
  // other.
  testWidgets('shows each pack under its course, legacy packs as English to Amharic', (
    tester,
  ) async {
    const packB = LessonContent(
      lessonId: 'lesson-b',
      skillId: 'skill-b',
      title: 'Akkam',
      beansAtStart: 5,
      beansMax: 5,
      exercises: [],
    );
    final packStore = FakeLessonPackStore();
    await packStore.save(_packA); // downloaded before courses existed
    await packStore.save(
      packB,
      courseId: 'c-am-om',
      courseTitle: 'Amharic to Afaan Oromo',
    );
    await tester.pumpWidget(_wrapped(packStore: packStore, syncEngine: _engine()));
    await tester.pumpAndSettle();

    expect(find.text('English to Amharic'), findsOneWidget);
    expect(find.text('Amharic to Afaan Oromo'), findsOneWidget);
    expect(find.text('Alphabet & Fidel'), findsOneWidget);
    expect(find.text('Akkam'), findsOneWidget);

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
    await tester.pumpAndSettle();

    // Exactly one pack remains, and it is the other course's.
    expect(find.text('Delete'), findsOneWidget);
  });
}
