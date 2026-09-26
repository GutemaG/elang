// The dashboard's one section header, its dividers and the jump button
// (020-dashboard-section-header): one solid header pinned under the stats
// bar that follows the section scrolled to, in that section's colour; grey
// dividers between sections in the path; and a button back to the
// learner's current lesson when it is out of view.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/courses/course_badge.dart';
import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/features/lesson/widgets/category_banner.dart';
import 'package:elang/features/lesson/widgets/dashboard_header.dart';
import 'package:elang/features/lesson/widgets/skill_path_node.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/widgets/app_card.dart';
import 'package:elang/shared/widgets/app_icon_button.dart';

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

const _sections = [
  SkillCategory(id: 'c1', title: 'Foundations & Greetings', subtitle: 'ሰላምታ'),
  SkillCategory(id: 'c2', title: 'Family & People', subtitle: 'ቤተሰብ'),
  SkillCategory(id: 'c3', title: 'Food & Drink', subtitle: 'ምግብ'),
];

/// Six skills per section. [activeIn] names the section whose first skill
/// is active: earlier ones are completed, later ones locked. `null` makes
/// every skill completed, so there is no active node.
SkillTreeResponse _tree({int? activeIn = 0}) {
  final nodes = <SkillTreeNode>[];
  for (var s = 0; s < _sections.length; s++) {
    for (var i = 0; i < 6; i++) {
      final state = activeIn == null || s < activeIn
          ? SkillNodeState.completed
          : s == activeIn && i == 0
          ? SkillNodeState.active
          : SkillNodeState.locked;
      nodes.add(
        SkillTreeNode(
          id: 's$s-$i',
          lessonId: 'lesson-s$s-$i',
          title: 'Skill $s.$i',
          subtitle: '',
          state: state,
          categoryId: _sections[s].id,
        ),
      );
    }
  }
  return SkillTreeResponse(
    categories: _sections,
    nodes: nodes,
    streakCount: 3,
    beans: 5,
    beansMax: 5,
    totalXp: 100,
  );
}

Widget _dashboard(
  SkillTreeResponse tree, {
  bool reduceMotion = false,
  double textScale = 1,
}) {
  final api = ControllableLessonApi()
    ..skillTree = tree
    ..beansStatus = _beans
    ..dueCount = 0;
  final connectivity = FakeConnectivityMonitor();
  final session = SessionRepository(storage: InMemorySecureStorageService());
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
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

Future<void> _pump(
  WidgetTester tester,
  SkillTreeResponse tree, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(400, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_dashboard(tree, reduceMotion: reduceMotion));
  await tester.pumpAndSettle();
}

ScrollController _controller(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

Future<void> _scrollTo(WidgetTester tester, double offset) async {
  _controller(tester).jumpTo(offset);
  await tester.pumpAndSettle();
}

/// The header's section title (the first line of the one header).
String _headerTitle(WidgetTester tester) {
  final banner = tester.widget<CategoryBanner>(find.byType(CategoryBanner));
  return banner.category.title;
}

double _headerBottom(WidgetTester tester) =>
    tester.getBottomLeft(find.byType(CategoryBanner)).dy;

/// Off-screen dividers count too: they are laid out, just not painted.
Finder _divider(String title) => find.ancestor(
  of: find.text(title, skipOffstage: false),
  matching: find.byType(PathSectionDivider, skipOffstage: false),
);

/// Scrolls so the line of [title]'s divider (its middle) sits [dy] px below
/// the header's bottom edge (negative: tucked under it).
Future<void> _placeDivider(WidgetTester tester, String title, double dy) async {
  final gap = tester.getCenter(_divider(title)).dy - _headerBottom(tester);
  await _scrollTo(tester, _controller(tester).offset + gap - dy);
}

Finder get _jump => find.byTooltip('Jump to your current lesson');

Finder get _activeNode => find.byWidgetPredicate(
  (w) => w is SkillPathNode && w.node.state == SkillNodeState.active,
);

void main() {
  group('the header', () {
    testWidgets('there is exactly one, pinned under the stats bar at every '
        'scroll position', (tester) async {
      await _pump(tester, _tree());
      final max = _controller(tester).position.maxScrollExtent;
      for (final offset in [0.0, max / 3, max * 2 / 3, max]) {
        await _scrollTo(tester, offset);
        expect(find.byType(CategoryBanner), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(CategoryBanner)).dy,
          closeTo(tester.getBottomLeft(find.byType(DashboardHeader)).dy, 1),
          reason: 'offset $offset',
        );
      }
    });

    testWidgets('it starts on the first section and switches as each '
        "divider passes under it, taking that section's colour", (
      tester,
    ) async {
      await _pump(tester, _tree());
      AppTone tone() => tester
          .widget<AppCard>(
            find.descendant(
              of: find.byType(CategoryBanner),
              matching: find.byType(AppCard),
            ),
          )
          .tone;

      expect(_headerTitle(tester), 'Foundations & Greetings');
      expect(tone(), AppTone.primary);

      // Just short of the header: still the first section.
      await _placeDivider(tester, 'Family & People', 4);
      expect(_headerTitle(tester), 'Foundations & Greetings');

      // Tucked under it: the second.
      await _placeDivider(tester, 'Family & People', -4);
      expect(_headerTitle(tester), 'Family & People');
      expect(tone(), AppTone.secondary);

      await _placeDivider(tester, 'Food & Drink', -4);
      expect(_headerTitle(tester), 'Food & Drink');
      expect(tone(), AppTone.tertiary);
    });

    testWidgets('scrolling back up switches it back as soon as the divider '
        'comes out from under it', (tester) async {
      await _pump(tester, _tree());
      await _placeDivider(tester, 'Food & Drink', -20);
      expect(_headerTitle(tester), 'Food & Drink');

      await _placeDivider(tester, 'Food & Drink', 4);
      expect(_headerTitle(tester), 'Family & People');

      await _scrollTo(tester, 0);
      expect(_headerTitle(tester), 'Foundations & Greetings');
    });

    testWidgets('it shows the section it names: its own count and bar', (
      tester,
    ) async {
      await _pump(tester, _tree(activeIn: 1));
      expect(find.text('6/6 Completed'), findsOneWidget);
      await _placeDivider(tester, 'Family & People', -4);
      expect(find.text('0/6 Completed'), findsOneWidget);
    });

    testWidgets('the change cross-fades, and is instant with reduced motion', (
      tester,
    ) async {
      AnimatedSwitcher switcher() => tester.widget<AnimatedSwitcher>(
        find.ancestor(
          of: find.byType(CategoryBanner),
          matching: find.byType(AnimatedSwitcher),
        ),
      );

      await _pump(tester, _tree());
      expect(switcher().duration, AppMotion.feedback);

      await _pump(tester, _tree(), reduceMotion: true);
      expect(switcher().duration, Duration.zero);
      await _placeDivider(tester, 'Family & People', -4);
      // One frame, and only the new header is there.
      expect(find.byType(CategoryBanner), findsOneWidget);
      expect(_headerTitle(tester), 'Family & People');
    });

    testWidgets('scrolling within a section keeps the same header, with no '
        'switch', (tester) async {
      await _pump(tester, _tree());
      final before = tester.widget<CategoryBanner>(find.byType(CategoryBanner));
      await _scrollTo(tester, 40);
      await _scrollTo(tester, 80);
      final after = tester.widget<CategoryBanner>(find.byType(CategoryBanner));
      expect(after.key, before.key);
    });
  });

  group('the path', () {
    testWidgets('each section after the first begins with a divider; the '
        'first has none', (tester) async {
      await _pump(tester, _tree());
      final titles = tester
          .widgetList<PathSectionDivider>(
            find.byType(PathSectionDivider, skipOffstage: false),
          )
          .map((d) => d.title)
          .toList();
      expect(titles, ['Family & People', 'Food & Drink']);
    });

    testWidgets('the header is the only coloured card: no section banner is '
        'left in the path', (tester) async {
      await _pump(tester, _tree());
      final max = _controller(tester).position.maxScrollExtent;
      for (final offset in [0.0, max / 2, max]) {
        await _scrollTo(tester, offset);
        final filled = tester
            .widgetList<AppCard>(find.byType(AppCard))
            .where((c) => c.filled);
        expect(filled, hasLength(1), reason: 'offset $offset');
      }
    });
  });

  group('small and large phones', () {
    for (final size in const [Size(320, 568), Size(360, 640), Size(430, 932)]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} at '
            '${scale}x: no overflow with the header in each section, and the '
            'jump button shown', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _dashboard(_tree(activeIn: 0), textScale: scale),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final seen = <String>{};
          final max = _controller(tester).position.maxScrollExtent;
          for (var step = 0; step <= 20; step++) {
            await _scrollTo(tester, max * step / 20);
            expect(tester.takeException(), isNull, reason: 'step $step');
            seen.add(_headerTitle(tester));
          }
          expect(seen, {for (final s in _sections) s.title});
          // At the bottom the active node (first section) is far above.
          expect(_jump, findsOneWidget);
        });
      }
    }
  });

  group('the jump button', () {
    testWidgets('is hidden while the current lesson is in view', (
      tester,
    ) async {
      await _pump(tester, _tree(activeIn: 0));
      expect(_jump, findsNothing);
    });

    testWidgets('points down to a current lesson below the view, and takes '
        'the learner to it', (tester) async {
      await _pump(tester, _tree(activeIn: 2));
      expect(_jump, findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      await tester.tap(_jump);
      await tester.pumpAndSettle();

      // In view under the header, and far enough in that the header names
      // its section: the section's divider is tucked under the header.
      final node = tester.getRect(_activeNode);
      expect(node.top, greaterThanOrEqualTo(_headerBottom(tester) - 1));
      expect(node.bottom, lessThanOrEqualTo(700));
      expect(_headerTitle(tester), 'Food & Drink');
      // The header never names a section whose divider line still shows.
      expect(
        tester.getCenter(_divider('Food & Drink')).dy,
        lessThanOrEqualTo(_headerBottom(tester)),
      );
      expect(_jump, findsNothing);
    });

    testWidgets('points up once the learner has scrolled past it, and brings '
        'it back', (tester) async {
      await _pump(tester, _tree(activeIn: 0));
      await _scrollTo(tester, _controller(tester).position.maxScrollExtent);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      await tester.tap(_jump);
      await tester.pumpAndSettle();
      final node = tester.getRect(_activeNode);
      expect(node.top, greaterThanOrEqualTo(_headerBottom(tester) - 1));
      expect(node.bottom, lessThanOrEqualTo(700));
      expect(_jump, findsNothing);
    });

    testWidgets('never shows when the course has no current lesson', (
      tester,
    ) async {
      await _pump(tester, _tree(activeIn: null));
      final max = _controller(tester).position.maxScrollExtent;
      for (final offset in [0.0, max]) {
        await _scrollTo(tester, offset);
        expect(_jump, findsNothing);
      }
    });

    testWidgets('is a 48 px library icon button, read as "Jump to your '
        'current lesson"', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _tree(activeIn: 2));
      final size = tester.getSize(
        find.ancestor(of: _jump, matching: find.byType(AppIconButton)),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel('Jump to your current lesson'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('with reduced motion it jumps at once', (tester) async {
      await _pump(tester, _tree(activeIn: 2), reduceMotion: true);
      await tester.tap(_jump);
      await tester.pump();
      final node = tester.getRect(_activeNode);
      expect(node.top, greaterThanOrEqualTo(_headerBottom(tester) - 1));
      expect(node.bottom, lessThanOrEqualTo(700));
    });

    testWidgets('steps aside while the course panel is open', (tester) async {
      await _pump(tester, _tree(activeIn: 2));
      expect(_jump, findsOneWidget);
      await tester.tap(find.byType(CourseBadge));
      await tester.pumpAndSettle();
      expect(_jump, findsNothing);
    });
  });
}
