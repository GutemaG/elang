// Skill-tree dashboard screen tests (story 001).
//
// Covers: locked/active/completed nodes render distinctly with a
// crown-level badge on completed nodes; locked nodes aren't tappable;
// tapping an active node starts a lesson; a fetch failure shows inline
// error + retry; and (009-offline-caching-and-sync-ui, story 001) the
// download affordance shows a previously-downloaded pack as downloaded on
// load, and downloads an un-downloaded lesson on tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/answer_feedback_player.dart';
import 'package:elang/shared/services/fake_lesson_api.dart';
import 'package:elang/shared/services/lesson_api.dart';
import 'package:elang/shared/services/lesson_audio_player.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
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

// The dashboard only threads these through to build `SettingsScreen` on
// tap -- no test here opens Settings, so a real-but-unused
// `HttpUserPreferencesApi` and in-memory-backed repositories are enough.
// Bolt 018-amole-ui: the dashboard now also fetches beans-status (for the
// Amole HUD pill) alongside the skill tree -- `ControllableLessonApi`'s
// `getBeansStatus` null-checks its field, so every dashboard test using it
// must set this, not just the skill-tree-focused ones.
const _fixtureBeansStatus = BeansStatus(
  beans: 5,
  beansMax: 5,
  regenMinutesPerBean: 30,
  amoleBalance: 500,
  refillCostAmole: 350,
);

SessionRepository _settingsSessionRepository() =>
    SessionRepository(storage: InMemorySecureStorageService());
SoundPreferenceRepository _settingsSoundPreferenceRepository() =>
    SoundPreferenceRepository(storage: InMemorySecureStorageService());

Widget _wrapped({
  required LessonApi lessonApi,
  required LessonAudioPlayer audioPlayer,
  AnswerFeedbackPlayer? feedbackPlayer,
}) {
  final sessionRepository = _settingsSessionRepository();
  return MaterialApp(
    home: SkillTreeDashboardScreen(
      lessonApi: lessonApi,
      audioPlayer: audioPlayer,
      feedbackPlayer: feedbackPlayer ?? FakeAnswerFeedbackPlayer(),
      connectivityMonitor: FakeConnectivityMonitor(),
      lessonPackStore: FakeLessonPackStore(),
      lessonPackDownloader: LessonPackDownloader(
        lessonApi: lessonApi,
        packStore: FakeLessonPackStore(),
      ),
      syncEngine: SyncEngine(
        lessonApi: lessonApi,
        connectivityMonitor: FakeConnectivityMonitor(),
        queueStore: FakePendingSyncQueueStore(),
      ),
      sessionRepository: sessionRepository,
      userPreferencesApi: HttpUserPreferencesApi(sessionRepository: sessionRepository),
      soundPreferenceRepository: _settingsSoundPreferenceRepository(),
    ),
  );
}

void main() {
  testWidgets(
    'shows the Amole balance from beans-status next to streak/beans/XP',
    (tester) async {
      final api = ControllableLessonApi()
        ..skillTree = const SkillTreeResponse(
          unitTitle: 'Unit 1',
          unitSubtitle: 'sub',
          nodes: [
            SkillTreeNode(
              id: 'skill-a',
              lessonId: 'lesson-a',
              title: 'Skill A',
              subtitle: 'a',
              state: SkillNodeState.active,
            ),
          ],
          streakCount: 1,
          beans: 5,
          beansMax: 5,
          totalXp: 0,
        )
        ..beansStatus = _fixtureBeansStatus; // amoleBalance: 500

      await tester.pumpWidget(
        _wrapped(lessonApi: api, audioPlayer: FakeLessonAudioPlayer()),
      );
      await tester.pumpAndSettle();

      expect(find.text('500'), findsOneWidget);
      expect(find.byIcon(Icons.paid), findsOneWidget);
    },
  );

  testWidgets(
    'a zero Amole balance is shown as 0, not hidden',
    (tester) async {
      final api = ControllableLessonApi()
        ..skillTree = const SkillTreeResponse(
          unitTitle: 'Unit 1',
          unitSubtitle: 'sub',
          nodes: [
            SkillTreeNode(
              id: 'skill-a',
              lessonId: 'lesson-a',
              title: 'Skill A',
              subtitle: 'a',
              state: SkillNodeState.active,
            ),
          ],
          streakCount: 1,
          beans: 5,
          beansMax: 5,
          totalXp: 20,
        )
        ..beansStatus = const BeansStatus(
          beans: 5,
          beansMax: 5,
          regenMinutesPerBean: 30,
          amoleBalance: 0,
          refillCostAmole: 350,
        );

      await tester.pumpWidget(
        _wrapped(lessonApi: api, audioPlayer: FakeLessonAudioPlayer()),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
    },
  );

  testWidgets(
    'the Amole balance reflects a change after the dashboard reloads',
    (tester) async {
      final api = ControllableLessonApi()
        ..skillTree = const SkillTreeResponse(
          unitTitle: 'Unit 1',
          unitSubtitle: 'sub',
          nodes: [
            SkillTreeNode(
              id: 'skill-a',
              lessonId: 'lesson-a',
              title: 'Skill A',
              subtitle: 'a',
              state: SkillNodeState.active,
            ),
          ],
          streakCount: 1,
          beans: 5,
          beansMax: 5,
          totalXp: 0,
        )
        ..lessonContent = const LessonContent(
          lessonId: 'lesson-a',
          skillId: 'skill-a',
          title: 'Skill A',
          beansAtStart: 5,
          beansMax: 5,
          exercises: [
            MultipleChoiceExercise(
              id: 'ex-1',
              prompt: 'ሀ',
              promptTranslation: 'sound?',
              options: ['ha', 'le'],
              correctOptionIndex: 0,
            ),
          ],
        )
        ..completionResult = const LessonCompletionResult(
          xpEarned: 5,
          dailyXpTotal: 5,
          dailyXpTarget: 30,
          streakCount: 2,
          streakIncreasedToday: true,
          accuracyPercent: 100,
          correctCount: 1,
          totalCount: 1,
          timeSpent: Duration(seconds: 5),
        )
        ..beansStatus = const BeansStatus(
          beans: 5,
          beansMax: 5,
          regenMinutesPerBean: 30,
          amoleBalance: 100,
          refillCostAmole: 350,
        );

      await tester.pumpWidget(
        _wrapped(lessonApi: api, audioPlayer: FakeLessonAudioPlayer()),
      );
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);

      // Simulate the backend having awarded Amole for the completion
      // that's about to happen -- the next dashboard reload should pick
      // up this new value with no other wiring.
      api.beansStatus = const BeansStatus(
        beans: 5,
        beansMax: 5,
        regenMinutesPerBean: 30,
        amoleBalance: 120,
        refillCostAmole: 350,
      );

      await tester.tap(find.text('Skill A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ha'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('120'), findsOneWidget);
    },
  );

  testWidgets(
    'renders locked/active/completed nodes with crown badges, matching seed data',
    (tester) async {
      await tester.pumpWidget(
        _wrapped(
          lessonApi: FakeLessonApi(latency: Duration.zero),
          audioPlayer: FakeLessonAudioPlayer(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alphabet & Fidel'), findsOneWidget);
      expect(find.text('Basic Greetings'), findsOneWidget);
      expect(find.text('Coffee & Hospitality'), findsOneWidget);
      expect(find.text('Family & Introductions'), findsOneWidget);

      // Crown-level badges on the two completed nodes from seed data.
      expect(find.text('Lv 3'), findsOneWidget);
      expect(find.text('Lv 2'), findsOneWidget);

      // Locked node shows the lock affordance.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    },
  );

  testWidgets('tapping a locked node does nothing (not interactive)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapped(
        lessonApi: FakeLessonApi(latency: Duration.zero),
        audioPlayer: FakeLessonAudioPlayer(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Family & Introductions'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // Still on the dashboard — no lesson screen was pushed.
    expect(find.text('Family & Introductions'), findsOneWidget);
    expect(find.text('Check'), findsNothing);
  });

  testWidgets('tapping the active node starts its lesson', (tester) async {
    await tester.pumpWidget(
      _wrapped(
        lessonApi: FakeLessonApi(latency: Duration.zero),
        audioPlayer: FakeLessonAudioPlayer(),
      ),
    );
    await tester.pumpAndSettle();

    // The sync-status banner + manage-downloads button added above the
    // node list (010-offline-caching-and-sync-ui) push lower nodes far
    // enough down that they can sit outside the test window's fixed
    // viewport -- scroll this one into view before tapping it.
    await tester.ensureVisible(find.text('Coffee & Hospitality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee & Hospitality'));
    await tester.pumpAndSettle();

    // The active node's lesson content's first exercise is now showing.
    expect(find.text('ቡና'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
  });

  testWidgets('a fetch failure shows inline error + retry, then recovers', (
    tester,
  ) async {
    final api = ControllableLessonApi()
      ..skillTreeError = Exception('boom')
      ..beansStatus = _fixtureBeansStatus;
    await tester.pumpWidget(
      _wrapped(lessonApi: api, audioPlayer: FakeLessonAudioPlayer()),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your skill tree"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    api.skillTreeError = null;
    api.skillTree = const SkillTreeResponse(
      unitTitle: 'Unit 1: Foundations & Greetings',
      unitSubtitle: 'ሰላምታ',
      nodes: [
        SkillTreeNode(
          id: 'skill-a',
          lessonId: 'lesson-a',
          title: 'Skill A',
          subtitle: 'a',
          state: SkillNodeState.active,
        ),
      ],
      streakCount: 1,
      beans: 5,
      beansMax: 5,
      totalXp: 0,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your skill tree"), findsNothing);
    expect(find.text('Skill A'), findsOneWidget);
  });

  testWidgets(
    'returning from a completed lesson reloads the dashboard with updated node state',
    (tester) async {
      final api = ControllableLessonApi()
        ..skillTree = const SkillTreeResponse(
          unitTitle: 'Unit 1',
          unitSubtitle: 'sub',
          nodes: [
            SkillTreeNode(
              id: 'skill-a',
              lessonId: 'lesson-a',
              title: 'Skill A',
              subtitle: 'a',
              state: SkillNodeState.active,
            ),
          ],
          streakCount: 1,
          beans: 5,
          beansMax: 5,
          totalXp: 0,
        )
        ..beansStatus = _fixtureBeansStatus
        ..lessonContent = const LessonContent(
          lessonId: 'lesson-a',
          skillId: 'skill-a',
          title: 'Skill A',
          beansAtStart: 5,
          beansMax: 5,
          exercises: [
            MultipleChoiceExercise(
              id: 'ex-1',
              prompt: 'ሀ',
              promptTranslation: 'sound?',
              options: ['ha', 'le'],
              correctOptionIndex: 0,
            ),
          ],
        )
        ..completionResult = const LessonCompletionResult(
          xpEarned: 5,
          dailyXpTotal: 5,
          dailyXpTarget: 30,
          streakCount: 2,
          streakIncreasedToday: true,
          accuracyPercent: 100,
          correctCount: 1,
          totalCount: 1,
          timeSpent: Duration(seconds: 5),
        );

      await tester.pumpWidget(
        _wrapped(lessonApi: api, audioPlayer: FakeLessonAudioPlayer()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skill A'));
      await tester.pumpAndSettle();

      // Answer correctly and finish the (single-exercise) lesson.
      await tester.tap(find.text('ha'));
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Lesson-complete screen shown.
      expect(find.text('Lesson Complete!'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Back on the dashboard, and it re-fetched (getSkillTree called
      // again on return).
      expect(find.text('Skill A'), findsOneWidget);
    },
  );

  testWidgets(
    'a previously-downloaded lesson shows the downloaded icon as soon as the dashboard loads',
    (tester) async {
      final api = FakeLessonApi(latency: Duration.zero);
      // Built directly (not via `api.startLesson`) -- that call's artificial
      // `Future.delayed` only resolves once something drives the fake test
      // clock, which doesn't happen until the first `pump`, so awaiting it
      // before `pumpWidget` would deadlock the test.
      final packStore = FakeLessonPackStore()
        ..save(
          const LessonContent(
            lessonId: 'lesson-alphabet',
            skillId: 'skill-alphabet',
            title: 'Alphabet & Fidel',
            beansAtStart: 5,
            beansMax: 5,
            exercises: [
              MultipleChoiceExercise(
                id: 'alphabet-1',
                prompt: 'ሀ',
                promptTranslation: 'Which sound?',
                options: ['ha', 'le'],
                correctOptionIndex: 0,
              ),
            ],
          ),
        );
      final downloader = LessonPackDownloader(lessonApi: api, packStore: packStore);

      final sessionRepository = _settingsSessionRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillTreeDashboardScreen(
            lessonApi: api,
            audioPlayer: FakeLessonAudioPlayer(),
            feedbackPlayer: FakeAnswerFeedbackPlayer(),
            connectivityMonitor: FakeConnectivityMonitor(),
            lessonPackStore: packStore,
            lessonPackDownloader: downloader,
            syncEngine: SyncEngine(
              lessonApi: api,
              connectivityMonitor: FakeConnectivityMonitor(),
              queueStore: FakePendingSyncQueueStore(),
            ),
            sessionRepository: sessionRepository,
            userPreferencesApi: HttpUserPreferencesApi(sessionRepository: sessionRepository),
            soundPreferenceRepository: _settingsSoundPreferenceRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Alphabet's already downloaded; greetings and coffee aren't.
      expect(find.byIcon(Icons.download_done), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNWidgets(2));
    },
  );

  testWidgets(
    'tapping the download affordance on an un-downloaded lesson downloads it',
    (tester) async {
      final api = FakeLessonApi(latency: Duration.zero);
      final packStore = FakeLessonPackStore();
      final downloader = LessonPackDownloader(lessonApi: api, packStore: packStore);
      final sessionRepository = _settingsSessionRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: SkillTreeDashboardScreen(
            lessonApi: api,
            audioPlayer: FakeLessonAudioPlayer(),
            feedbackPlayer: FakeAnswerFeedbackPlayer(),
            connectivityMonitor: FakeConnectivityMonitor(),
            lessonPackStore: packStore,
            lessonPackDownloader: downloader,
            syncEngine: SyncEngine(
              lessonApi: api,
              connectivityMonitor: FakeConnectivityMonitor(),
              queueStore: FakePendingSyncQueueStore(),
            ),
            sessionRepository: sessionRepository,
            userPreferencesApi: HttpUserPreferencesApi(sessionRepository: sessionRepository),
            soundPreferenceRepository: _settingsSoundPreferenceRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.download_outlined), findsNWidgets(3));

      // First node in seed order is the audio-free "Alphabet & Fidel"
      // node -- tapping avoids exercising the audio-download path here,
      // which is covered separately in lesson_pack_downloader_test.dart.
      await tester.tap(find.byIcon(Icons.download_outlined).first);
      await tester.pumpAndSettle();

      expect(await packStore.listDownloadedLessonIds(), ['lesson-alphabet']);
      expect(find.byIcon(Icons.download_done), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNWidgets(2));
    },
  );
}
