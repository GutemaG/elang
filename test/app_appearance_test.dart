// The app draws in the learner's Appearance choice from the first frame,
// and System follows the phone while the app is open
// (022-light-and-dark-themes, bolt 070, story 006).

import 'package:elang/features/auth/auth_dependencies.dart';
import 'package:elang/features/lesson/lesson_dependencies.dart';
import 'package:elang/features/settings/settings_dependencies.dart';
import 'package:elang/main.dart';
import 'package:elang/shared/services/fake_lesson_api.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/theme/appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_answer_feedback_player.dart';
import 'helpers/fake_lesson_audio_player.dart';
import 'helpers/in_memory_secure_storage_service.dart';
import 'helpers/test_appearance.dart';

Widget _app(AppearanceController appearance) {
  final auth = AuthDependencies(storage: InMemorySecureStorageService());
  final sound = SoundPreferenceRepository(storage: auth.storage);
  return BunaApp(
    appearance: appearance,
    authDependencies: auth,
    lessonDependencies: LessonDependencies(
      sessionRepository: auth.sessionRepository,
      soundPreferenceRepository: sound,
      lessonApi: FakeLessonApi(latency: Duration.zero),
      audioPlayer: FakeLessonAudioPlayer(),
      feedbackPlayer: FakeAnswerFeedbackPlayer(),
    ),
    settingsDependencies: SettingsDependencies(
      sessionRepository: auth.sessionRepository,
      soundPreferenceRepository: sound,
    ),
  );
}

void main() {
  Brightness splash(WidgetTester tester) =>
      Theme.of(tester.element(find.text('Get Started'))).brightness;

  testWidgets('Light on a dark phone is light from the first frame', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_app(testAppearance(mode: ThemeMode.light)));
    await tester.pump();

    expect(splash(tester), Brightness.light);
  });

  testWidgets('Dark on a light phone is dark from the first frame', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_app(testAppearance(mode: ThemeMode.dark)));
    await tester.pump();

    expect(splash(tester), Brightness.dark);
  });

  testWidgets('System follows the phone, even while the app is open', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_app(testAppearance()));
    await tester.pump();
    expect(splash(tester), Brightness.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(splash(tester), Brightness.dark);
  });

  testWidgets('a new choice redraws the app at once', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final appearance = testAppearance();

    await tester.pumpWidget(_app(appearance));
    await tester.pump();
    await appearance.choose(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(splash(tester), Brightness.dark);
  });
}
