// Dashboard offline behaviour per course (010-multi-language-courses, bolt 027,
// story 003): every online load is saved for its course; offline the active
// course's saved copy is shown with a note; switching offline works only for a
// cached course; a choice made offline reaches the server on the next online
// load; and course A's tree is never shown for course B.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/caching_course_api.dart';
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/course_cache_store.dart';
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

const _offline = LessonApiException('Network request failed');
const _offlineCourse = CourseApiException('Network request failed');

SkillTreeResponse _tree(Course course, String skillTitle) => SkillTreeResponse(
  course: course,
  categories: const [SkillCategory(id: 'cat', title: 'Banner', subtitle: 's')],
  nodes: [
    SkillTreeNode(
      id: 'skill-${course.id}',
      lessonId: 'lesson-${course.id}',
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
      ..dueCount = 2;

class _Rig {
  _Rig({required this.lessonApi, required this.courseApi, required this.cache});

  final ControllableLessonApi lessonApi;
  final CourseApi courseApi;
  final CourseCacheStore cache;
  final packStore = FakeLessonPackStore();
  late final downloader = LessonPackDownloader(
    lessonApi: lessonApi,
    packStore: packStore,
  );

  Widget build() {
    final connectivity = FakeConnectivityMonitor();
    final session = SessionRepository(storage: InMemorySecureStorageService());
    return MaterialApp(
      home: SkillTreeDashboardScreen(
        lessonApi: lessonApi,
        audioPlayer: FakeLessonAudioPlayer(),
        feedbackPlayer: FakeAnswerFeedbackPlayer(),
        connectivityMonitor: connectivity,
        lessonPackStore: packStore,
        lessonPackDownloader: downloader,
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

/// A device that has seen both courses online, then went offline.
Future<_Rig> _offlineRig(
  WidgetTester tester, {
  bool bothCached = true,
  String active = 'c-en-am',
}) async {
  final cache = InMemoryCourseCacheStore();
  final inner = FakeCourseApi(courses: [_amharic, _oromo]);
  final courseApi = CachingCourseApi(inner: inner, cache: cache);
  await courseApi.getCourses();
  await cache.saveDashboard(
    'c-en-am',
    _tree(_amharic, 'Greetings'),
    amoleBalance: 500,
  );
  if (bothCached) {
    await cache.saveDashboard(
      'c-en-om',
      _tree(_oromo, 'Akkam'),
      amoleBalance: 500,
    );
  }
  await cache.setActiveCourseId(active);
  inner.failWith = _offlineCourse;
  final lessonApi = _lessonApi(_tree(_amharic, 'unused'))
    ..skillTreeError = _offline;
  final rig = _Rig(lessonApi: lessonApi, courseApi: courseApi, cache: cache);
  await tester.pumpWidget(rig.build());
  await tester.pumpAndSettle();
  return rig;
}

void main() {
  testWidgets('an online load saves the course for offline use', (
    tester,
  ) async {
    final cache = InMemoryCourseCacheStore();
    final rig = _Rig(
      lessonApi: _lessonApi(_tree(_amharic, 'Greetings')),
      courseApi: FakeCourseApi(courses: [_amharic, _oromo]),
      cache: cache,
    );

    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    final saved = await cache.loadDashboard('c-en-am');
    expect(saved?.tree.nodes.single.title, 'Greetings');
    expect(saved?.amoleBalance, 500);
    expect(await cache.activeCourseId(), 'c-en-am');
    expect(find.text('Offline, showing saved progress'), findsNothing);
  });

  testWidgets('offline, the active course opens from its saved copy', (
    tester,
  ) async {
    await _offlineRig(tester);

    expect(find.text('Greetings'), findsOneWidget);
    expect(find.text('Offline, showing saved progress'), findsOneWidget);
    expect(find.text('Amharic'), findsOneWidget); // the chip
    expect(find.text("Couldn't load your skill tree"), findsNothing);
  });

  testWidgets('course A tree is never shown while course B is active', (
    tester,
  ) async {
    await _offlineRig(tester, active: 'c-en-om');

    expect(find.text('Akkam'), findsOneWidget);
    expect(find.text('Greetings'), findsNothing);
    expect(find.text('Afaan Oromo'), findsOneWidget);
  });

  testWidgets('offline with nothing saved keeps the existing error state', (
    tester,
  ) async {
    final cache = InMemoryCourseCacheStore();
    final rig = _Rig(
      lessonApi: _lessonApi(_tree(_amharic, 'x'))..skillTreeError = _offline,
      courseApi: FakeCourseApi(courses: [_amharic, _oromo]),
      cache: cache,
    );

    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your skill tree"), findsOneWidget);
  });

  testWidgets('a backend error is not mistaken for being offline', (
    tester,
  ) async {
    final cache = InMemoryCourseCacheStore();
    await cache.saveDashboard(
      'c-en-am',
      _tree(_amharic, 'Greetings'),
      amoleBalance: 1,
    );
    await cache.setActiveCourseId('c-en-am');
    final rig = _Rig(
      lessonApi: _lessonApi(_tree(_amharic, 'x'))
        ..skillTreeError = const LessonApiException(
          'expired',
          errorCode: 'invalid_token',
        ),
      courseApi: FakeCourseApi(courses: [_amharic, _oromo]),
      cache: cache,
    );

    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your skill tree"), findsOneWidget);
    expect(find.text('Greetings'), findsNothing);
  });

  testWidgets('offline, switching to a saved course opens it from its copy', (
    tester,
  ) async {
    final rig = await _offlineRig(tester);

    await tester.tap(find.text('Amharic'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('English to Afaan Oromo'));
    await tester.pumpAndSettle();

    expect(find.text('Akkam'), findsOneWidget);
    expect(find.text('Greetings'), findsNothing);
    expect(find.text('Afaan Oromo'), findsOneWidget);
    expect(await rig.cache.pendingSwitchCourseId(), 'c-en-om');
  });

  testWidgets('offline, a course never saved cannot be opened', (tester) async {
    final rig = await _offlineRig(tester, bothCached: false);

    await tester.tap(find.text('Amharic'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('English to Afaan Oromo'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Connect to the internet to open this course for the first time.',
      ),
      findsOneWidget,
    );
    expect(find.text('Greetings'), findsOneWidget);
    expect(await rig.cache.activeCourseId(), 'c-en-am');
    expect(await rig.cache.pendingSwitchCourseId(), isNull);
  });

  testWidgets('back online, an offline choice is sent before loading', (
    tester,
  ) async {
    final cache = InMemoryCourseCacheStore();
    final inner = FakeCourseApi(courses: [_amharic, _oromo]);
    final courseApi = CachingCourseApi(inner: inner, cache: cache);
    await courseApi.getCourses();
    await cache.saveDashboard(
      'c-en-om',
      _tree(_oromo, 'Akkam'),
      amoleBalance: 500,
    );
    inner.failWith = _offlineCourse;
    await courseApi.switchCourse('c-en-om'); // chosen offline
    inner.failWith = null;
    inner.switchCalls.clear();

    final rig = _Rig(
      lessonApi: _lessonApi(_tree(_oromo, 'Akkam (live)')),
      courseApi: courseApi,
      cache: cache,
    );
    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    expect(inner.switchCalls, ['c-en-om']);
    expect(inner.activeCourseId, 'c-en-om');
    expect(await cache.pendingSwitchCourseId(), isNull);
    expect(find.text('Akkam (live)'), findsOneWidget);
    expect(find.text('Offline, showing saved progress'), findsNothing);
  });

  testWidgets('a pack downloaded now is filed under the shown course', (
    tester,
  ) async {
    final rig = _Rig(
      lessonApi: _lessonApi(_tree(_oromo, 'Akkam'))
        ..lessonContent = const LessonContent(
          lessonId: 'lesson-c-en-om',
          skillId: 'skill-c-en-om',
          title: 'Akkam',
          exercises: [],
          beansAtStart: 5,
          beansMax: 5,
        ),
      courseApi: FakeCourseApi(courses: [_amharic, _oromo]),
      cache: InMemoryCourseCacheStore(),
    );
    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    await rig.downloader.downloadLesson('lesson-c-en-om');

    expect(rig.packStore.courseIdOf('lesson-c-en-om'), 'c-en-om');
  });

  for (final width in [360.0, 320.0]) {
    testWidgets('the offline note does not overflow at ${width}dp', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cache = InMemoryCourseCacheStore();
      final inner = FakeCourseApi(courses: [_amharic, _oromo]);
      final courseApi = CachingCourseApi(inner: inner, cache: cache);
      await courseApi.getCourses();
      await cache.saveDashboard(
        'c-en-am',
        _tree(_amharic, 'Greetings'),
        amoleBalance: 1,
      );
      final rig = _Rig(
        lessonApi: _lessonApi(_tree(_amharic, 'x'))..skillTreeError = _offline,
        courseApi: courseApi,
        cache: cache,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1600),
            textScaler: const TextScaler.linear(1.3),
          ),
          child: rig.build(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline, showing saved progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
