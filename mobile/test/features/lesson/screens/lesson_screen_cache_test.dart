// A lesson opened before starts from its on-device copy instead of waiting on
// the network: the copy is refreshed in the background, a copy saved under an
// older skill version is never played, and offline a copy with no audio is as
// good as a downloaded pack.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/course_cache_store.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

LessonContent _lesson(String prompt, {bool withAudio = false}) =>
    LessonContent(
      lessonId: 'l-1',
      skillId: 's-1',
      title: 'Greetings',
      beansAtStart: 5,
      beansMax: 5,
      exercises: [
        MultipleChoiceExercise(
          id: 'mc-1',
          prompt: prompt,
          promptTranslation: 'Which sound?',
          options: const ['ha', 'le'],
          correctOptionIndex: 0,
        ),
        if (withAudio)
          const ListeningExercise(
            id: 'li-1',
            audioUrl: 'https://example.com/a.mp3',
            instruction: 'Tap what you hear',
            options: ['ሰላም', 'ደህና'],
            correctOptionIndex: 0,
          ),
      ],
    );

final _v1 = DateTime.utc(2026, 9, 1);
final _v2 = DateTime.utc(2026, 9, 2);

/// Counts `startLesson` calls, and can hold them in flight forever -- so a
/// test can prove the screen never waited on one.
class _CountingLessonApi extends ControllableLessonApi {
  int startCalls = 0;
  bool hang = false;

  @override
  Future<LessonContent> startLesson(String lessonId) {
    startCalls++;
    if (hang) return Completer<LessonContent>().future;
    return super.startLesson(lessonId);
  }
}

Widget _screen(
  _CountingLessonApi api,
  CourseCacheStore cache, {
  bool online = true,
  DateTime? skillVersion,
  int? beansNow,
}) {
  final connectivity = FakeConnectivityMonitor(online: online);
  return MaterialApp(
    home: LessonScreen(
      lessonId: 'l-1',
      lessonApi: api,
      audioPlayer: FakeLessonAudioPlayer(),
      feedbackPlayer: FakeAnswerFeedbackPlayer(),
      connectivityMonitor: connectivity,
      lessonPackStore: FakeLessonPackStore(),
      syncEngine: SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: FakePendingSyncQueueStore(),
      ),
      lessonCache: cache,
      skillVersion: skillVersion,
      beansNow: beansNow,
    ),
  );
}

void main() {
  testWidgets('a cached copy opens without waiting on the network', (
    tester,
  ) async {
    final cache = InMemoryCourseCacheStore();
    await cache.saveLesson(_lesson('ሀ (saved)'), skillVersion: _v1);
    final api = _CountingLessonApi()..hang = true;

    await tester.pumpWidget(_screen(api, cache, skillVersion: _v1));
    await tester.pumpAndSettle();

    expect(find.text('ሀ (saved)'), findsOneWidget);
    expect(api.startCalls, 1); // the background refresh, still in flight
  });

  testWidgets('the background refresh replaces the copy for next time', (
    tester,
  ) async {
    final cache = InMemoryCourseCacheStore();
    await cache.saveLesson(_lesson('ሀ (saved)'), skillVersion: _v1);
    final api = _CountingLessonApi()..lessonContent = _lesson('ሀ (fresh)');

    await tester.pumpWidget(_screen(api, cache, skillVersion: _v1));
    await tester.pumpAndSettle();

    expect(find.text('ሀ (saved)'), findsOneWidget);
    final saved = await cache.loadLesson('l-1');
    expect(
      (saved!.content.exercises.first as MultipleChoiceExercise).prompt,
      'ሀ (fresh)',
    );
  });

  testWidgets('a copy saved under an older skill version is not played', (
    tester,
  ) async {
    final cache = InMemoryCourseCacheStore();
    await cache.saveLesson(_lesson('ሀ (old)'), skillVersion: _v1);
    final api = _CountingLessonApi()..lessonContent = _lesson('ሀ (edited)');

    await tester.pumpWidget(_screen(api, cache, skillVersion: _v2));
    await tester.pumpAndSettle();

    expect(find.text('ሀ (edited)'), findsOneWidget);
    expect(find.text('ሀ (old)'), findsNothing);
    expect((await cache.loadLesson('l-1'))!.skillVersion, _v2);
  });

  testWidgets('a lesson never opened is fetched, then kept', (tester) async {
    final cache = InMemoryCourseCacheStore();
    final api = _CountingLessonApi()..lessonContent = _lesson('ሀ');

    await tester.pumpWidget(_screen(api, cache, skillVersion: _v1));
    await tester.pumpAndSettle();

    expect(find.text('ሀ'), findsOneWidget);
    expect(await cache.loadLesson('l-1'), isNotNull);
  });

  testWidgets('offline, a copy with no audio plays like a pack', (
    tester,
  ) async {
    final cache = InMemoryCourseCacheStore();
    await cache.saveLesson(_lesson('ሀ (saved)'));
    final api = _CountingLessonApi();

    await tester.pumpWidget(_screen(api, cache, online: false));
    await tester.pumpAndSettle();

    expect(find.text('ሀ (saved)'), findsOneWidget);
    expect(api.startCalls, 0);
  });

  testWidgets('offline, a copy with audio still asks for a download', (
    tester,
  ) async {
    final cache = InMemoryCourseCacheStore();
    await cache.saveLesson(_lesson('ሀ (saved)', withAudio: true));

    await tester.pumpWidget(
      _screen(_CountingLessonApi(), cache, online: false),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Download this lesson while online to take it offline.'),
      findsOneWidget,
    );
  });
}
