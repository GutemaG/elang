// Backing out of a lesson part-way through asks first, in a bottom sheet:
// Keep learning stays, Leave goes back. Once the lesson is finished there is
// nothing to lose, so back is not intercepted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

const _lesson = LessonContent(
  lessonId: 'people:pronouns',
  skillId: 'skill:people',
  title: 'I, You, He, She',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    MultipleChoiceExercise(
      id: 'mc-1',
      prompt: 'እኔ',
      promptTranslation: 'Which word?',
      options: ['I', 'you'],
      correctOptionIndex: 0,
    ),
    MultipleChoiceExercise(
      id: 'mc-2',
      prompt: 'አንተ',
      promptTranslation: 'Which word?',
      options: ['I', 'you'],
      correctOptionIndex: 1,
    ),
  ],
);

/// A dashboard stand-in with a button that opens the lesson, so leaving the
/// lesson has somewhere to go back to.
Widget _app() {
  final connectivity = FakeConnectivityMonitor(online: false);
  final api = ControllableLessonApi()..lessonContent = _lesson;
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LessonScreen(
                  lessonId: _lesson.lessonId,
                  lessonApi: api,
                  audioPlayer: FakeLessonAudioPlayer(),
                  feedbackPlayer: FakeAnswerFeedbackPlayer(),
                  connectivityMonitor: connectivity,
                  lessonPackStore: FakeLessonPackStore()..save(_lesson),
                  syncEngine: SyncEngine(
                    lessonApi: api,
                    connectivityMonitor: connectivity,
                    queueStore: FakePendingSyncQueueStore(),
                  ),
                ),
              ),
            ),
            child: const Text('DASHBOARD'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openLesson(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.tap(find.text('DASHBOARD'));
  await tester.pumpAndSettle();
  expect(find.text('እኔ'), findsOneWidget);
}

void main() {
  testWidgets('the back gesture part-way through asks before leaving', (
    tester,
  ) async {
    await _openLesson(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Leave this lesson?'), findsOneWidget);
    expect(find.text('እኔ'), findsOneWidget); // still in the lesson
  });

  testWidgets('Keep learning closes the sheet and stays in the lesson', (
    tester,
  ) async {
    await _openLesson(tester);
    await tester.tap(find.byTooltip('Exit lesson'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep learning'));
    await tester.pumpAndSettle();

    expect(find.text('Leave this lesson?'), findsNothing);
    expect(find.text('እኔ'), findsOneWidget);
  });

  testWidgets('Leave goes back to where the lesson was opened from', (
    tester,
  ) async {
    await _openLesson(tester);
    await tester.tap(find.byTooltip('Exit lesson'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('እኔ'), findsNothing);
  });

  testWidgets('no caption above the question', (tester) async {
    await _openLesson(tester);

    expect(find.textContaining('I, You, He, She'), findsNothing);
    expect(find.textContaining('Lesson 1 of'), findsNothing);
  });
}
