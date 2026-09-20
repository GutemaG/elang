// Dashboard grouping by course category (009-course-categories, bolt 023).
//
// Covers: N categories render N banners in order with correct "x/y
// Completed" counts; each category's skills sit under its own banner; an
// empty category does not crash; existing node behaviours (locked not
// tappable, download badge on unlocked nodes) hold in every category; and
// nothing overflows at narrow widths with long titles and large text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/features/lesson/widgets/category_banner.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/skill_tree.dart';
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

SkillTreeNode _node(String id, String category, SkillNodeState state) =>
    SkillTreeNode(
      id: id,
      lessonId: 'lesson-$id',
      title: 'Skill $id',
      subtitle: '',
      state: state,
      categoryId: category,
      crownLevel: state == SkillNodeState.completed ? 1 : 0,
    );

SkillTreeResponse _tree({
  required List<SkillCategory> categories,
  required List<SkillTreeNode> nodes,
}) => SkillTreeResponse(
  categories: categories,
  nodes: nodes,
  streakCount: 999,
  beans: 5,
  beansMax: 5,
  totalXp: 123456,
);

Widget _dashboard(ControllableLessonApi api) {
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
      courseApi: FakeCourseApi(),
      sessionRepository: session,
      userPreferencesApi: HttpUserPreferencesApi(sessionRepository: session),
      soundPreferenceRepository: SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      ),
    ),
  );
}

ControllableLessonApi _api(SkillTreeResponse tree) => ControllableLessonApi()
  ..skillTree = tree
  ..beansStatus = _beans
  ..dueCount = 0;

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _foundations = SkillCategory(
  id: 'c1',
  title: 'Foundations & Greetings',
  subtitle: 'ሰላምታ',
);
const _family = SkillCategory(
  id: 'c2',
  title: 'Family & People',
  subtitle: 'ቤተሰብ',
);
const _numbers = SkillCategory(
  id: 'c3',
  title: 'Numbers & Time',
  subtitle: 'ቁጥር',
);

void main() {
  testWidgets('N categories render N banners in order with their own counts', (
    tester,
  ) async {
    final api = _api(
      _tree(
        categories: [_foundations, _family, _numbers],
        nodes: [
          _node('a', 'c1', SkillNodeState.completed),
          _node('b', 'c1', SkillNodeState.completed),
          _node('c', 'c2', SkillNodeState.completed),
          _node('d', 'c2', SkillNodeState.active),
          _node('e', 'c3', SkillNodeState.active),
          _node('f', 'c3', SkillNodeState.locked),
        ],
      ),
    );
    _size(tester, const Size(400, 4000));

    await tester.pumpWidget(_dashboard(api));
    await tester.pumpAndSettle();

    expect(find.text('Foundations & Greetings'), findsOneWidget);
    expect(find.text('Family & People'), findsOneWidget);
    expect(find.text('Numbers & Time'), findsOneWidget);
    expect(find.text('ቤተሰብ'), findsOneWidget);
    expect(find.text('2/2 Completed'), findsOneWidget);
    expect(find.text('1/2 Completed'), findsOneWidget);
    expect(find.text('0/2 Completed'), findsOneWidget);

    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Foundations & Greetings'), lessThan(y('Skill a')));
    expect(y('Skill b'), lessThan(y('Family & People')));
    expect(y('Skill d'), lessThan(y('Numbers & Time')));
    expect(y('Numbers & Time'), lessThan(y('Skill e')));
  });

  testWidgets('the zig-zag restarts at the top of every category', (
    tester,
  ) async {
    final api = _api(
      _tree(
        categories: [_foundations, _family],
        nodes: [
          _node('a', 'c1', SkillNodeState.active),
          _node('b', 'c1', SkillNodeState.locked),
          _node('c', 'c1', SkillNodeState.locked),
          _node('d', 'c1', SkillNodeState.locked),
          _node('e', 'c2', SkillNodeState.active),
          _node('f', 'c2', SkillNodeState.locked),
        ],
      ),
    );
    _size(tester, const Size(400, 4000));

    await tester.pumpWidget(_dashboard(api));
    await tester.pumpAndSettle();

    // Overall, e is the 5th node (would be right-aligned); as the first
    // node of its category it must sit centred like a, and f to its right.
    final centreA = tester.getCenter(find.text('Skill a')).dx;
    final centreE = tester.getCenter(find.text('Skill e')).dx;
    final centreF = tester.getCenter(find.text('Skill f')).dx;
    expect(centreE, closeTo(centreA, 1));
    expect(centreF, greaterThan(centreE));
  });

  testWidgets('a category with no skills renders 0/0 without crashing', (
    tester,
  ) async {
    final api = _api(
      _tree(
        categories: [_foundations, _family],
        nodes: [_node('a', 'c1', SkillNodeState.active)],
      ),
    );

    await tester.pumpWidget(_dashboard(api));
    await tester.pumpAndSettle();

    expect(find.text('Family & People'), findsOneWidget);
    expect(find.text('0/0 Completed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'locked nodes stay untappable and unlocked nodes in later categories '
    'get a download badge',
    (tester) async {
      final api = _api(
        _tree(
          categories: [_foundations, _family],
          nodes: [
            _node('a', 'c1', SkillNodeState.completed),
            _node('b', 'c2', SkillNodeState.active),
            _node('c', 'c2', SkillNodeState.locked),
          ],
        ),
      );
      _size(tester, const Size(400, 4000));

      await tester.pumpWidget(_dashboard(api));
      await tester.pumpAndSettle();

      // Completed and active nodes have a badge; the locked one does not.
      expect(find.byIcon(Icons.download_outlined), findsNWidgets(2));
      await tester.tap(find.text('Skill c'));
      await tester.pumpAndSettle();
      expect(find.text('Skill c'), findsOneWidget); // still on the dashboard
    },
  );

  for (final width in [360.0, 320.0]) {
    testWidgets(
      'long category titles and large text do not overflow at ${width}dp',
      (tester) async {
        const long = SkillCategory(
          id: 'c1',
          title: 'Colors, Body & Health and other very long category names',
          subtitle: 'ቀለሞች፣ አካል እና ጤና እና ሌሎች በጣም ረጅም የምድብ ስሞች እዚህ ይገኛሉ',
        );
        final api = _api(
          _tree(
            categories: [long, _family],
            nodes: [
              _node('a', 'c1', SkillNodeState.completed),
              _node('b', 'c1', SkillNodeState.active),
              _node('c', 'c2', SkillNodeState.active),
            ],
          ),
        );
        _size(tester, Size(width, 2400));

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 2400),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: _dashboard(api),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('consecutive categories take different banner colours', (
    tester,
  ) async {
    final api = _api(
      _tree(
        categories: [_foundations, _family, _numbers],
        nodes: [
          _node('a', 'c1', SkillNodeState.active),
          _node('b', 'c2', SkillNodeState.active),
          _node('c', 'c3', SkillNodeState.active),
        ],
      ),
    );
    _size(tester, const Size(400, 4000));

    await tester.pumpWidget(_dashboard(api));
    await tester.pumpAndSettle();

    Color background(String title) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.ancestor(
                of: find.text(title),
                matching: find.byType(CategoryBanner),
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      return ((container.decoration! as BoxDecoration).color)!;
    }

    final colours = {
      background('Foundations & Greetings'),
      background('Family & People'),
      background('Numbers & Time'),
    };
    expect(colours, hasLength(3));
  });

  // The pinned banner reserves its height before it lays out, so an awkward
  // text scale is where it breaks: 1.15x and 1.3x both produce line heights
  // that the layout rounds up. This overflowed by a pixel on device.
  for (final scale in [1.0, 1.15, 1.3, 1.5]) {
    for (final width in [360.0, 320.0]) {
      testWidgets(
        'the pinned banner fits its reserved height at ${scale}x on ${width}dp',
        (tester) async {
          final api = _api(
            _tree(
              categories: [_foundations, _family, _numbers],
              nodes: [
                _node('a', 'c1', SkillNodeState.completed),
                _node('b', 'c2', SkillNodeState.active),
                _node('c', 'c3', SkillNodeState.locked),
              ],
            ),
          );
          _size(tester, Size(width, 2400));

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 2400),
                textScaler: TextScaler.linear(scale),
              ),
              child: _dashboard(api),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

}
