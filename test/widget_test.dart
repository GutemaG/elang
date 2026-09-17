// Smoke test for the app's entry point.
//
// Verifies BunaApp boots into the splash screen without crashing. Uses an
// in-memory fake for secure storage so the test doesn't depend on platform
// channels (flutter_secure_storage has no test-environment implementation).

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_dependencies.dart';
import 'package:elang/features/lesson/lesson_dependencies.dart';
import 'package:elang/features/settings/settings_dependencies.dart';
import 'package:elang/main.dart';
import 'package:elang/shared/services/fake_lesson_api.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';

import 'helpers/fake_answer_feedback_player.dart';
import 'helpers/fake_lesson_audio_player.dart';
import 'helpers/in_memory_secure_storage_service.dart';

void main() {
  testWidgets('BunaApp boots into the splash screen', (
    WidgetTester tester,
  ) async {
    final authDependencies = AuthDependencies(
      storage: InMemorySecureStorageService(),
    );
    final soundPreferenceRepository = SoundPreferenceRepository(
      storage: authDependencies.storage,
    );
    await tester.pumpWidget(
      BunaApp(
        authDependencies: authDependencies,
        lessonDependencies: LessonDependencies(
          sessionRepository: authDependencies.sessionRepository,
          soundPreferenceRepository: soundPreferenceRepository,
          lessonApi: FakeLessonApi(latency: Duration.zero),
          audioPlayer: FakeLessonAudioPlayer(),
          feedbackPlayer: FakeAnswerFeedbackPlayer(),
        ),
        settingsDependencies: SettingsDependencies(
          sessionRepository: authDependencies.sessionRepository,
          soundPreferenceRepository: soundPreferenceRepository,
        ),
      ),
    );

    // First frame, before the session-check/animation resolves.
    await tester.pump();

    expect(find.text('Buna'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
