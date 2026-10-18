// Reduced motion on real screens (018-mobile-design-system, bolt 049,
// story 005, NFR-2). The library skips movement when the system asks for
// less motion; these check that the screens pass that on: a held button
// does not sink and a wrong answer does not shake. Each check also runs
// with motion on, to prove it measures real movement.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/screens/onboarding_carousel_screen.dart';
import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/tactile_pressable.dart';

import '../helpers/controllable_lesson_api.dart';
import '../helpers/fake_answer_feedback_player.dart';
import '../helpers/fake_connectivity_monitor.dart';
import '../helpers/fake_lesson_audio_player.dart';
import '../helpers/fake_lesson_pack_store.dart';
import '../helpers/fake_pending_sync_queue_store.dart';

Widget _app(Widget home, {required bool reduced}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: home,
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    builder: (_) => Scaffold(body: Text('ROUTE ${settings.name}')),
  ),
);

Widget _lesson(Exercise exercise) {
  final api = ControllableLessonApi()
    ..lessonContent = LessonContent(
      lessonId: 'lesson-motion',
      skillId: 'skill-motion',
      title: 'Motion',
      beansAtStart: 5,
      beansMax: 5,
      exercises: [exercise],
    );
  final connectivity = FakeConnectivityMonitor();
  return LessonScreen(
    lessonId: 'lesson-motion',
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
  );
}

const _mc = MultipleChoiceExercise(
  id: 'mc',
  prompt: 'ቡና',
  promptTranslation: 'What does this word mean?',
  options: ['Coffee', 'Tea', 'Water'],
  correctOptionIndex: 0,
);

const _sentence = SentenceConstructionExercise(
  id: 'sc',
  promptTranslation: "Translate: 'I want coffee'",
  wordBank: ['ቡና', 'እፈልጋለሁ', 'ሻይ', 'እኔ'],
  correctSentence: ['እኔ', 'ቡና', 'እፈልጋለሁ'],
);

Finder _tile(String label) =>
    find.byWidgetPredicate((w) => w is AnswerTile && w.label == label);

/// How far the pressable face inside [of] has sunk.
double _sink(WidgetTester tester, Finder of) {
  final pressable = find
      .descendant(of: of, matching: find.byType(TactilePressable))
      .first;
  final transform = tester.widget<Transform>(
    find.descendant(of: pressable, matching: find.byType(Transform)).first,
  );
  return transform.transform.getTranslation().y;
}

/// Holds a press on [of] past the tap-down delay and through the press
/// animation, and returns how far its face sank.
Future<double> _heldSink(WidgetTester tester, Finder of) async {
  final gesture = await tester.startGesture(tester.getCenter(of));
  await tester.pump(const Duration(milliseconds: 150)); // tap-down delay
  await tester.pump(const Duration(milliseconds: 100)); // press-in
  final sink = _sink(tester, of);
  await gesture.cancel();
  await tester.pumpAndSettle();
  return sink;
}

/// The furthest the tile [label] moves sideways while it is graded wrong.
Future<double> _shakeWhenWrong(WidgetTester tester, String label) async {
  await tester.tap(_tile(label));
  await tester.pump();
  var furthest = 0.0;
  for (var i = 0; i < 12; i++) {
    await tester.pump(AppMotion.shake ~/ 10);
    final transform = tester.widget<Transform>(
      find.descendant(of: _tile(label), matching: find.byType(Transform)).first,
    );
    final x = transform.transform.getTranslation().x.abs();
    if (x > furthest) furthest = x;
  }
  await tester.pumpAndSettle();
  return furthest;
}

void main() {
  for (final reduced in const [true, false]) {
    final motion = reduced ? 'with reduced motion' : 'with motion on';

    group(motion, () {
      testWidgets('onboarding: a held Continue '
          '${reduced ? 'stays put' : 'sinks'}', (tester) async {
        await tester.pumpWidget(
          _app(const OnboardingCarouselScreen(), reduced: reduced),
        );
        await tester.pumpAndSettle();

        final sink = await _heldSink(
          tester,
          find.widgetWithText(AppButton, 'Continue'),
        );
        expect(sink, reduced ? 0 : greaterThan(0));
      });

      testWidgets('a lesson: a held Check '
          '${reduced ? 'stays put' : 'sinks'}', (tester) async {
        await tester.pumpWidget(_app(_lesson(_sentence), reduced: reduced));
        await tester.pumpAndSettle();
        await tester.tap(_tile('እኔ').last);
        await tester.pumpAndSettle();

        final sink = await _heldSink(
          tester,
          find.widgetWithText(AppButton, 'Check'),
        );
        expect(sink, reduced ? 0 : greaterThan(0));
      });

      testWidgets('a lesson: a held answer '
          '${reduced ? 'stays put' : 'sinks'}', (tester) async {
        await tester.pumpWidget(_app(_lesson(_mc), reduced: reduced));
        await tester.pumpAndSettle();

        final sink = await _heldSink(tester, _tile('Tea'));
        expect(sink, reduced ? 0 : greaterThan(0));
      });

      testWidgets('a lesson: a wrong answer '
          '${reduced ? 'does not shake' : 'shakes'}', (tester) async {
        await tester.pumpWidget(_app(_lesson(_mc), reduced: reduced));
        await tester.pumpAndSettle();

        final furthest = await _shakeWhenWrong(tester, 'Tea');
        expect(furthest, reduced ? 0 : greaterThan(0));
      });
    });
  }
}
