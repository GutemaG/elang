// The course panel on the dashboard (011-dashboard-ui-polish, bolt 029,
// stories 003 and 004): the badge opens and closes it, tapping outside closes
// it, a course the learner has opened is one tap away on the rail, tapping the
// active course changes nothing, and the two entries open their screens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/course_cache_store.dart';
import 'package:elang/shared/services/fake_course_api.dart';
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

const _beans = BeansStatus(
  beans: 5,
  beansMax: 5,
  regenMinutesPerBean: 30,
  amoleBalance: 500,
  refillCostAmole: 350,
);

const _amharic = Course(
  id: 'c-en-am',
  learningLanguage: 'am',
  fromLanguage: 'en',
  title: 'English to Amharic',
);
const _oromo = Course(
  id: 'c-en-om',
  learningLanguage: 'om',
  fromLanguage: 'en',
  title: 'English to Afaan Oromo',
);

SkillTreeResponse _tree(Course course, String skill) => SkillTreeResponse(
  course: course,
  categories: const [
    SkillCategory(id: 'cat', title: 'Foundations', subtitle: 'sub'),
  ],
  nodes: [
    SkillTreeNode(
      id: 'skill',
      lessonId: 'lesson-${course.id}',
      title: skill,
      subtitle: '',
      state: SkillNodeState.active,
      categoryId: 'cat',
    ),
  ],
  streakCount: 1,
  beans: 5,
  beansMax: 5,
  totalXp: 10,
);

ControllableLessonApi _lessonApi(SkillTreeResponse tree) =>
    ControllableLessonApi()
      ..skillTree = tree
      ..beansStatus = _beans
      ..dueCount = 0;

class _Rig {
  _Rig({required this.lessonApi, required this.courseApi, required this.cache});

  final ControllableLessonApi lessonApi;
  final FakeCourseApi courseApi;
  final CourseCacheStore cache;

  Widget build() {
    final connectivity = FakeConnectivityMonitor();
    final session = SessionRepository(storage: InMemorySecureStorageService());
    return MaterialApp(
      home: SkillTreeDashboardScreen(
        lessonApi: lessonApi,
        audioPlayer: FakeLessonAudioPlayer(),
        feedbackPlayer: FakeAnswerFeedbackPlayer(),
        connectivityMonitor: connectivity,
        lessonPackStore: FakeLessonPackStore(),
        lessonPackDownloader: LessonPackDownloader(
          lessonApi: lessonApi,
          packStore: FakeLessonPackStore(),
        ),
        syncEngine: SyncEngine(
          lessonApi: lessonApi,
          connectivityMonitor: connectivity,
          queueStore: FakePendingSyncQueueStore(),
        ),
        courseApi: courseApi,
        courseCache: cache,
        sessionRepository: session,
        userPreferencesApi: HttpUserPreferencesApi(sessionRepository: session),
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
      ),
    );
  }
}

/// A dashboard on Amharic. With [bothOpened] the learner has also opened the
/// Afaan Oromo course, so it is on the rail (ADR-15).
Future<_Rig> _rig(WidgetTester tester, {bool bothOpened = false}) async {
  final cache = InMemoryCourseCacheStore();
  if (bothOpened) {
    await cache.saveDashboard(
      'c-en-om',
      _tree(_oromo, 'Akkam'),
      amoleBalance: 500,
    );
  }
  final rig = _Rig(
    lessonApi: _lessonApi(_tree(_amharic, 'Greetings')),
    courseApi: FakeCourseApi(
      courses: const [_amharic, _oromo],
      activeCourseId: 'c-en-am',
    ),
    cache: cache,
  );
  await tester.pumpWidget(rig.build());
  await tester.pumpAndSettle();
  return rig;
}

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.text('Amharic'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the badge opens the panel and closes it again', (tester) async {
    await _rig(tester);

    expect(find.text('Course settings'), findsNothing);

    await _openPanel(tester);
    expect(find.text('Course settings'), findsOneWidget);

    await tester.tap(find.text('Amharic').first);
    await tester.pumpAndSettle();
    expect(find.text('Course settings'), findsNothing);
  });

  testWidgets('tapping below the panel closes it', (tester) async {
    await _rig(tester);
    await _openPanel(tester);

    // Everything under the panel is a scrim that dismisses it.
    await tester.tap(find.byKey(const ValueKey('course-panel-scrim')));
    await tester.pumpAndSettle();

    expect(find.text('Course settings'), findsNothing);
  });

  testWidgets('the panel is not built before it is first opened', (
    tester,
  ) async {
    final rig = await _rig(tester);

    // A learner who never opens it never pays for a course-list fetch.
    expect(rig.courseApi.courseListCalls, 0);

    await _openPanel(tester);
    expect(rig.courseApi.courseListCalls, 1);
  });

  testWidgets('a course the learner has opened is one tap away on the rail', (
    tester,
  ) async {
    final rig = await _rig(tester, bothOpened: true);
    rig.lessonApi.skillTree = _tree(_oromo, 'Akkam');

    await _openPanel(tester);
    await tester.tap(find.text('Afaan Oromo'));
    await tester.pumpAndSettle();

    expect(rig.courseApi.switchCalls, ['c-en-om']);
    expect(find.text('Akkam'), findsOneWidget);
    expect(find.text('Greetings'), findsNothing);
    // The panel closed and the badge followed the switch.
    expect(find.text('Course settings'), findsNothing);
    expect(find.text('Afaan Oromo'), findsOneWidget);
  });

  testWidgets('tapping the course already active just closes the panel', (
    tester,
  ) async {
    final rig = await _rig(tester, bothOpened: true);

    await _openPanel(tester);
    await tester.tap(find.text('Amharic').last);
    await tester.pumpAndSettle();

    expect(rig.courseApi.switchCalls, isEmpty);
    expect(find.text('Course settings'), findsNothing);
    expect(find.text('Greetings'), findsOneWidget);
  });

  testWidgets('Manage downloads opens the downloads screen', (tester) async {
    await _rig(tester);
    await _openPanel(tester);

    await tester.tap(find.text('Manage downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Manage Downloads'), findsOneWidget);
  });

  testWidgets('Course settings opens the settings screen', (tester) async {
    await _rig(tester);
    await _openPanel(tester);

    await tester.tap(find.text('Course settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });
}
