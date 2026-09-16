// Smoke test for the app's entry point.
//
// Verifies BunaApp boots into the splash screen without crashing. Uses an
// in-memory fake for secure storage so the test doesn't depend on platform
// channels (flutter_secure_storage has no test-environment implementation).

import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_dependencies.dart';
import 'package:elang/features/lesson/lesson_dependencies.dart';
import 'package:elang/main.dart';
import 'package:elang/shared/services/fake_lesson_api.dart';

import 'helpers/fake_lesson_audio_player.dart';
import 'helpers/in_memory_secure_storage_service.dart';

void main() {
  testWidgets('BunaApp boots into the splash screen', (
    WidgetTester tester,
  ) async {
    final authDependencies = AuthDependencies(
      storage: InMemorySecureStorageService(),
    );
    await tester.pumpWidget(
      BunaApp(
        authDependencies: authDependencies,
        lessonDependencies: LessonDependencies(
          sessionRepository: authDependencies.sessionRepository,
          lessonApi: FakeLessonApi(latency: Duration.zero),
          audioPlayer: FakeLessonAudioPlayer(),
        ),
      ),
    );

    // First frame, before the session-check/animation resolves.
    await tester.pump();

    expect(find.text('Buna'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
