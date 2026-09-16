// Splash screen tests.
//
// Covers acceptance criteria: the splash screen shows the Buna wordmark and
// "Get Started" CTA, and — the routing decision — sends a user with no/an
// invalid session to the onboarding carousel while a user with a valid
// session goes straight to home, without ever rendering onboarding.
//
// The two routing-decision tests use `BunaApp` + the real route table
// (`AuthRoutes.build`) rather than `SplashScreen` in isolation, because the
// thing under test *is* which named route gets pushed — that only means
// anything against the real route table.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_dependencies.dart';
import 'package:elang/features/auth/auth_flow_controller.dart';
import 'package:elang/features/auth/screens/splash_screen.dart';
import 'package:elang/features/lesson/lesson_dependencies.dart';
import 'package:elang/main.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_lesson_api.dart';
import 'package:elang/shared/services/session_repository.dart';

import '../../helpers/fake_lesson_audio_player.dart';
import '../../helpers/in_memory_secure_storage_service.dart';

LessonDependencies _lessonDeps() => LessonDependencies(
  // Unused (a fake `lessonApi` is supplied below), but required by the
  // constructor -- only `HttpLessonApi`'s default would ever read it.
  sessionRepository: SessionRepository(storage: InMemorySecureStorageService()),
  lessonApi: FakeLessonApi(latency: Duration.zero),
  audioPlayer: FakeLessonAudioPlayer(),
);

/// Advances past the splash screen's ~1.4s "brewing" animation so the
/// navigation that's gated on both the animation *and* the session-check
/// completing actually fires.
Future<void> _finishSplashAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  // The navigation call happens inside that frame's animation-status
  // callback, which only schedules the destination route's build for the
  // *next* frame — and the default MaterialPageRoute transition then needs
  // its own frames to finish animating in.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the Buna wordmark and Get Started CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          authFlowController: AuthFlowController(
            sessionRepository:
                AuthDependencies(
                  storage: InMemorySecureStorageService(),
                ).sessionRepository,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Buna'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets(
    'routes to the onboarding carousel when no session exists',
    (tester) async {
      final deps = AuthDependencies(storage: InMemorySecureStorageService());

      await tester.pumpWidget(
        BunaApp(authDependencies: deps, lessonDependencies: _lessonDeps()),
      );
      await _finishSplashAnimation(tester);

      // Onboarding carousel content, not the dashboard.
      expect(find.text('Bite-Sized Amharic'), findsOneWidget);
      expect(find.text('Unit 1: Foundations & Greetings'), findsNothing);
    },
  );

  testWidgets(
    'routes to the onboarding carousel when the stored session is expired',
    (tester) async {
      final storage = InMemorySecureStorageService();
      final deps = AuthDependencies(storage: storage);
      // Pre-populate an expired session — must be treated as "no session".
      await deps.sessionRepository.saveSession(
        SessionState(
          token: 'stale-token',
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      await tester.pumpWidget(
        BunaApp(authDependencies: deps, lessonDependencies: _lessonDeps()),
      );
      await _finishSplashAnimation(tester);

      expect(find.text('Bite-Sized Amharic'), findsOneWidget);
      expect(find.text('Unit 1: Foundations & Greetings'), findsNothing);
    },
  );

  testWidgets(
    'routes straight to home when a valid session exists, skipping onboarding',
    (tester) async {
      final storage = InMemorySecureStorageService();
      final deps = AuthDependencies(storage: storage);
      await deps.sessionRepository.saveSession(
        SessionState(
          token: 'valid-token',
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      );

      await tester.pumpWidget(
        BunaApp(authDependencies: deps, lessonDependencies: _lessonDeps()),
      );
      await _finishSplashAnimation(tester);

      expect(find.text('Unit 1: Foundations & Greetings'), findsOneWidget);
      expect(find.text('Bite-Sized Amharic'), findsNothing);
    },
  );
}
