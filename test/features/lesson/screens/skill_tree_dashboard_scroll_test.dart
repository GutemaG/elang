// Dashboard scroll shell (011-dashboard-ui-polish, bolt 028).
//
// Covers: the header stays put at every scroll position and owns the stats;
// each category's banner pins beneath it and is displaced by the next; a
// single-category course keeps its banner pinned; a course shorter than the
// viewport is still draggable and settles back; and a course change returns to
// the top while a reload from a lesson does not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/features/lesson/widgets/category_banner.dart';
import 'package:elang/features/lesson/widgets/dashboard_header.dart';
import 'package:elang/features/lesson/widgets/lesson_hud.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
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

const _foundations = SkillCategory(
  id: 'c1',
  title: 'Foundations & Greetings',
  subtitle: 'the first steps',
);
const _family = SkillCategory(
  id: 'c2',
  title: 'Family & People',
  subtitle: 'who is who',
);

SkillTreeNode _node(String id, String category) => SkillTreeNode(
  id: id,
  lessonId: 'lesson-$id',
  title: 'Skill $id',
  subtitle: '',
  state: SkillNodeState.active,
  categoryId: category,
);

SkillTreeResponse _tree({
  Course? course,
  required List<SkillCategory> categories,
  required List<SkillTreeNode> nodes,
}) => SkillTreeResponse(
  course: course ?? _amharic,
  categories: categories,
  nodes: nodes,
  streakCount: 7,
  beans: 5,
  beansMax: 5,
  totalXp: 120,
);

/// A course tall enough that its content scrolls in the test viewport.
SkillTreeResponse _tallTree({
  Course? course,
  List<SkillCategory> categories = const [_foundations, _family],
  String prefix = '',
}) => _tree(
  course: course,
  categories: categories,
  nodes: [
    for (final category in categories)
      for (int i = 0; i < 5; i++) _node('$prefix${category.id}-$i', category.id),
  ],
);

ControllableLessonApi _lessonApi(SkillTreeResponse tree) =>
    ControllableLessonApi()
      ..skillTree = tree
      ..beansStatus = _beans
      ..dueCount = 0;

Widget _dashboard(ControllableLessonApi api, [CourseApi? courseApi]) {
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
      courseApi: courseApi ?? FakeCourseApi(),
      sessionRepository: session,
      userPreferencesApi: HttpUserPreferencesApi(sessionRepository: session),
      soundPreferenceRepository: SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      ),
    ),
  );
}

void _viewport(WidgetTester tester, {double width = 400, double height = 640}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder get _scrollView => find.byType(CustomScrollView);

double _offset(WidgetTester tester) =>
    tester.widget<CustomScrollView>(_scrollView).controller!.offset;

Future<void> _scrollBy(WidgetTester tester, double dy) async {
  await tester.drag(_scrollView, Offset(0, dy));
  await tester.pumpAndSettle();
}

double _headerBottom(WidgetTester tester) =>
    tester.getBottomLeft(find.byType(DashboardHeader)).dy;

Finder _banner(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(CategoryBanner));

void main() {
  testWidgets('the header is still there after scrolling to the bottom', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_dashboard(_lessonApi(_tallTree())));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(DashboardHeader)).dy, 0);

    await _scrollBy(tester, -4000);

    expect(_offset(tester), greaterThan(0));
    expect(find.byType(DashboardHeader), findsOneWidget);
    expect(tester.getTopLeft(find.byType(DashboardHeader)).dy, 0);
    // The stats scrolled with the content before this bolt; now they cannot.
    expect(find.text('120'), findsOneWidget); // XP
    expect(find.text('500'), findsOneWidget); // Amole
  });

  testWidgets('the stats live in the header, not in the scroll body', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_dashboard(_lessonApi(_tallTree())));
    await tester.pumpAndSettle();

    expect(find.byType(LessonHud), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DashboardHeader),
        matching: find.byType(LessonHud),
      ),
      findsOneWidget,
    );
  });

  testWidgets("a category's banner pins beneath the header while its nodes "
      'scroll past', (tester) async {
    _viewport(tester);
    await tester.pumpWidget(
      _dashboard(_lessonApi(_tallTree(categories: const [_foundations]))),
    );
    await tester.pumpAndSettle();

    // It starts where it falls, below the Practice card.
    expect(
      tester.getTopLeft(_banner('Foundations & Greetings')).dy,
      greaterThan(_headerBottom(tester)),
    );

    await _scrollBy(tester, -400);

    expect(
      tester.getTopLeft(_banner('Foundations & Greetings')).dy,
      closeTo(_headerBottom(tester), 1),
    );
  });

  testWidgets("the next category's banner takes the previous one's place", (
    tester,
  ) async {
    _viewport(tester);
    // The second category is long, so scrolling into it really does push the
    // first category's banner off rather than merely stacking the two.
    final tree = _tree(
      categories: const [_foundations, _family],
      nodes: [
        for (int i = 0; i < 3; i++) _node('c1-$i', 'c1'),
        for (int i = 0; i < 14; i++) _node('c2-$i', 'c2'),
      ],
    );
    await tester.pumpWidget(_dashboard(_lessonApi(tree)));
    await tester.pumpAndSettle();

    await _scrollBy(tester, -4000); // deep into the second category

    final second = _banner('Family & People');
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(second).dy, closeTo(_headerBottom(tester), 1));
    // The first category's banner has been pushed out of the way entirely.
    expect(_banner('Foundations & Greetings'), findsNothing);
  });

  testWidgets('a course with one category keeps its banner pinned throughout', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(
      _dashboard(_lessonApi(_tallTree(categories: const [_foundations]))),
    );
    await tester.pumpAndSettle();

    await _scrollBy(tester, -4000);

    expect(
      tester.getTopLeft(_banner('Foundations & Greetings')).dy,
      closeTo(_headerBottom(tester), 1),
    );
  });

  testWidgets('a course shorter than the viewport still drags and settles back', (
    tester,
  ) async {
    _viewport(tester, height: 1600);
    await tester.pumpWidget(
      _dashboard(
        _lessonApi(
          _tree(
            categories: const [_foundations],
            nodes: [_node('a', 'c1')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(_scrollView));
    await gesture.moveBy(const Offset(0, 160));
    await tester.pump();

    // Overscrolled: the page responded even though there is nothing to scroll.
    expect(_offset(tester), lessThan(0));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(_offset(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing course returns the learner to the top', (tester) async {
    _viewport(tester);
    final lessonApi = _lessonApi(_tallTree());
    final courseApi = FakeCourseApi(
      courses: const [_amharic, _oromo],
      activeCourseId: 'c-en-am',
    );
    await tester.pumpWidget(_dashboard(lessonApi, courseApi));
    await tester.pumpAndSettle();

    await _scrollBy(tester, -1200);
    expect(_offset(tester), greaterThan(0));

    lessonApi.skillTree = _tallTree(course: _oromo, prefix: 'om-');
    await tester.tap(find.text('Amharic'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('English to Afaan Oromo'));
    await tester.pumpAndSettle();

    expect(courseApi.switchCalls, ['c-en-om']);
    expect(_offset(tester), 0);
  });

  testWidgets('coming back from a lesson keeps the scroll position', (
    tester,
  ) async {
    _viewport(tester);
    final api = _lessonApi(_tallTree())
      ..lessonContent = const LessonContent(
        lessonId: 'lesson-c2-4',
        skillId: 'skill',
        title: 'Skill c2-4',
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
      );
    await tester.pumpWidget(_dashboard(api));
    await tester.pumpAndSettle();

    await _scrollBy(tester, -1200);
    await tester.ensureVisible(find.text('Skill c2-4'));
    await tester.pumpAndSettle();
    final before = _offset(tester);
    expect(before, greaterThan(0));

    await tester.tap(find.text('Skill c2-4'));
    await tester.pumpAndSettle();
    expect(find.text('ሀ'), findsOneWidget); // in the lesson

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    // The dashboard reloaded, but the learner is still where they were --
    // only a course change is a reason to jump to the top.
    expect(find.text('Skill c2-4'), findsOneWidget);
    expect(_offset(tester), closeTo(before, 1));
  });
}
