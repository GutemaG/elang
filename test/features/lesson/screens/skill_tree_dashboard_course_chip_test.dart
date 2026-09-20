// Dashboard course badge tests (010 bolt 026, reworked by 011 bolt 029): the
// badge shows the active course from the skill tree and opens the course
// panel; "+ Course" reaches the catalog; a switch reloads the dashboard with
// the new course's tree; a failed switch keeps the current one; and nothing
// overflows at narrow widths.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/course_api.dart';
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

SkillTreeResponse _tree(Course course, String bannerTitle, String skillTitle) =>
    SkillTreeResponse(
      course: course,
      categories: [
        SkillCategory(id: 'cat', title: bannerTitle, subtitle: 'sub'),
      ],
      nodes: [
        SkillTreeNode(
          id: 'skill',
          lessonId: 'lesson',
          title: skillTitle,
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

Widget _dashboard(ControllableLessonApi api, CourseApi courseApi) {
  final connectivity = FakeConnectivityMonitor();
  final session = SessionRepository(storage: InMemorySecureStorageService());
  return MaterialApp(
    home: SkillTreeDashboardScreen(
      lessonApi: api,
      audioPlayer: FakeLessonAudioPlayer(),
      feedbackPlayer: FakeAnswerFeedbackPlayer(),
      connectivityMonitor: connectivity,
      lessonPackStore: FakeLessonPackStore(),
      lessonPackDownloader: LessonPackDownloader(
        lessonApi: api,
        packStore: FakeLessonPackStore(),
      ),
      syncEngine: SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: FakePendingSyncQueueStore(),
      ),
      courseApi: courseApi,
      sessionRepository: session,
      userPreferencesApi: HttpUserPreferencesApi(sessionRepository: session),
      soundPreferenceRepository: SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      ),
    ),
  );
}

FakeCourseApi _courseApi() =>
    FakeCourseApi(courses: [_amharic, _oromo], activeCourseId: 'c-en-am');

void main() {
  testWidgets('the badge shows the language of the active course', (
    tester,
  ) async {
    await tester.pumpWidget(
      _dashboard(
        _lessonApi(_tree(_amharic, 'Foundations', 'Greetings')),
        _courseApi(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amharic'), findsOneWidget);
  });

  testWidgets(
    'with no course in the tree (older backend) the badge reads Courses',
    (tester) async {
      final tree = SkillTreeResponse(
        categories: const [SkillCategory(id: 'c', title: 'T', subtitle: 's')],
        nodes: const [],
        streakCount: 0,
        beans: 5,
        beansMax: 5,
        totalXp: 0,
      );
      await tester.pumpWidget(_dashboard(_lessonApi(tree), _courseApi()));
      await tester.pumpAndSettle();

      expect(find.text('Courses'), findsOneWidget);
    },
  );

  testWidgets('tapping the badge opens the panel with the course rail', (
    tester,
  ) async {
    await tester.pumpWidget(
      _dashboard(
        _lessonApi(_tree(_amharic, 'Foundations', 'Greetings')),
        _courseApi(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Amharic'));
    await tester.pumpAndSettle();

    // Nothing is cached and nothing has progress, so the rail is the active
    // course alone (ADR-15); everything else lives behind "+ Course".
    expect(find.text('from English'), findsOneWidget);
    expect(find.text('Course'), findsOneWidget);
    expect(find.text('Course settings'), findsOneWidget);
    expect(find.text('Manage downloads'), findsOneWidget);
  });

  testWidgets('"+ Course" opens the catalog', (tester) async {
    await tester.pumpWidget(
      _dashboard(
        _lessonApi(_tree(_amharic, 'Foundations', 'Greetings')),
        _courseApi(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Amharic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Course'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a course'), findsOneWidget);
    expect(find.text('For English speakers'), findsOneWidget);
  });

  testWidgets('switching course reloads the dashboard with the new tree', (
    tester,
  ) async {
    final lessonApi = _lessonApi(_tree(_amharic, 'Foundations', 'Greetings'));
    final courseApi = _courseApi();
    await tester.pumpWidget(_dashboard(lessonApi, courseApi));
    await tester.pumpAndSettle();
    expect(find.text('Greetings'), findsOneWidget);

    // What the backend would now return for the newly active course.
    lessonApi.skillTree = _tree(_oromo, 'Nagaa', 'Akkam');
    await tester.tap(find.text('Amharic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Course'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('English to Afaan Oromo'));
    await tester.pumpAndSettle();

    expect(courseApi.switchCalls, ['c-en-om']);
    expect(find.text('Choose a course'), findsNothing);
    expect(find.text('Afaan Oromo'), findsOneWidget); // the badge
    expect(find.text('Akkam'), findsOneWidget);
    expect(find.text('Greetings'), findsNothing);
  });

  testWidgets('a failed switch keeps the current course and its dashboard', (
    tester,
  ) async {
    final courseApi = _courseApi()
      ..switchFailure = const CourseApiException('nope');
    await tester.pumpWidget(
      _dashboard(
        _lessonApi(_tree(_amharic, 'Foundations', 'Greetings')),
        courseApi,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Amharic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Course'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('English to Afaan Oromo'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't switch course. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Greetings'), findsOneWidget);
    expect(courseApi.activeCourseId, 'c-en-am');
  });

  for (final width in [360.0, 320.0]) {
    testWidgets(
      'the badge and header do not overflow at ${width}dp with large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const long = Course(
          id: 'c',
          learningLanguage: 'om',
          fromLanguage: 'am',
          title: 'Amharic to Afaan Oromo',
        );

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1600),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: _dashboard(
              _lessonApi(_tree(long, 'Foundations & Greetings', 'Greetings')),
              FakeCourseApi(courses: [long], activeCourseId: 'c'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
