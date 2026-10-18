// When the server refuses the saved session (401 invalid_session), the
// dashboard says so and leads back to sign-in, instead of the "check your
// connection" error that no amount of retrying can fix.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
import 'package:elang/shared/services/lesson_api_exception.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

Widget _app(ControllableLessonApi api, SessionRepository session) {
  final connectivity = FakeConnectivityMonitor();
  final packStore = FakeLessonPackStore();
  return MaterialApp(
    routes: {
      '/': (_) => SkillTreeDashboardScreen(
        lessonApi: api,
        audioPlayer: FakeLessonAudioPlayer(),
        feedbackPlayer: FakeAnswerFeedbackPlayer(),
        connectivityMonitor: connectivity,
        lessonPackStore: packStore,
        lessonPackDownloader: LessonPackDownloader(
          lessonApi: api,
          packStore: packStore,
        ),
        syncEngine: SyncEngine(
          lessonApi: api,
          connectivityMonitor: FakeConnectivityMonitor(online: false),
          queueStore: FakePendingSyncQueueStore(),
        ),
        courseApi: FakeCourseApi(),
        sessionRepository: session,
        userPreferencesApi: HttpUserPreferencesApi(sessionRepository: session),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
      ),
      AuthRoutes.signIn: (_) => const Scaffold(body: Text('SIGN-IN SCREEN')),
    },
  );
}

ControllableLessonApi _api(Object error) => ControllableLessonApi()
  ..skillTreeError = error
  ..beansStatus = const BeansStatus(
    beans: 5,
    beansMax: 5,
    regenMinutesPerBean: 30,
    amoleBalance: 0,
    refillCostAmole: 350,
  )
  ..dueCount = 0;

Future<SessionRepository> _signedIn() async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: 'stale-token',
      expiresAt: DateTime.now().add(const Duration(days: 10)),
    ),
  );
  return repo;
}

void main() {
  testWidgets('a refused session asks to sign in again, and signs out', (
    tester,
  ) async {
    final session = await _signedIn();
    final api = _api(
      const LessonApiException('unknown', errorCode: 'invalid_session'),
    );

    await tester.pumpWidget(_app(api, session));
    await tester.pumpAndSettle();

    expect(find.text('Please sign in again'), findsOneWidget);
    expect(find.text("Couldn't load your skill tree"), findsNothing);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN-IN SCREEN'), findsOneWidget);
    expect((await session.getSessionState()).token, isNull);
  });

  testWidgets('a network failure still shows the retry error', (tester) async {
    final session = await _signedIn();
    final api = _api(const LessonApiException('socket closed'));

    await tester.pumpWidget(_app(api, session));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your skill tree"), findsOneWidget);
    expect(find.text('Please sign in again'), findsNothing);
    expect((await session.getSessionState()).token, 'stale-token');
  });
}
