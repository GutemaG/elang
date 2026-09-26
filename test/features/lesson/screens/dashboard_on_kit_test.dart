// The dashboard and courses on the library (018-mobile-design-system, bolt
// 047, story 002): the lattice page, stat pills, milestone banners in
// turning tones, the practice card, the download badge, the sync and
// offline banners, the status pages, the course panel and picker, the home
// placeholder, and small screens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/courses/course_panel.dart';
import 'package:elang/features/courses/course_picker.dart';
import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/features/lesson/widgets/category_banner.dart';
import 'package:elang/features/lesson/widgets/lesson_hud.dart';
import 'package:elang/features/lesson/widgets/sync_status_banner.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/pending_sync_entry.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/screens/home_placeholder_screen.dart';
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
import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_shadows.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_card.dart';
import 'package:elang/shared/widgets/app_icon_button.dart';
import 'package:elang/shared/widgets/app_page.dart';
import 'package:elang/shared/widgets/app_sheet.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:elang/shared/widgets/path_node.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

const _beans = BeansStatus(
  beans: 3,
  beansMax: 5,
  regenMinutesPerBean: 30,
  amoleBalance: 420,
  refillCostAmole: 350,
);

const _amharic = Course(
  id: 'c-en-am',
  learningLanguage: 'am',
  fromLanguage: 'en',
  title: 'English to Amharic',
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

List<SkillCategory> _categories(int n) => [
  for (var i = 1; i <= n; i++)
    SkillCategory(id: 'c$i', title: 'Category $i', subtitle: 'ምድብ $i'),
];

SkillTreeResponse _tree({int categories = 1, List<SkillTreeNode>? nodes}) =>
    SkillTreeResponse(
      course: _amharic,
      categories: _categories(categories),
      nodes:
          nodes ??
          [
            _node('a', 'c1', SkillNodeState.completed),
            _node('b', 'c1', SkillNodeState.active),
            _node('c', 'c1', SkillNodeState.locked),
          ],
      streakCount: 6,
      beans: 3,
      beansMax: 5,
      totalXp: 12340,
    );

ControllableLessonApi _api({SkillTreeResponse? tree, int due = 0}) =>
    ControllableLessonApi()
      ..skillTree = tree ?? _tree()
      ..beansStatus = _beans
      ..dueCount = due;

class _Rig {
  _Rig(this.api, {this.cache, CourseApi? courseApi, bool online = true})
    : connectivity = FakeConnectivityMonitor(online: online),
      courseApi = courseApi ?? FakeCourseApi();

  final ControllableLessonApi api;
  final CourseCacheStore? cache;
  final CourseApi courseApi;
  final FakeConnectivityMonitor connectivity;
  final packStore = FakeLessonPackStore();
  late final downloader = LessonPackDownloader(
    lessonApi: api,
    packStore: packStore,
  );
  late final syncEngine = SyncEngine(
    lessonApi: api,
    connectivityMonitor: connectivity,
    queueStore: FakePendingSyncQueueStore(),
  );

  Widget build({double textScale = 1}) {
    final session = SessionRepository(storage: InMemorySecureStorageService());
    return MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: SkillTreeDashboardScreen(
        lessonApi: api,
        audioPlayer: FakeLessonAudioPlayer(),
        feedbackPlayer: FakeAnswerFeedbackPlayer(),
        connectivityMonitor: connectivity,
        lessonPackStore: packStore,
        lessonPackDownloader: downloader,
        syncEngine: syncEngine,
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

Future<_Rig> _pump(
  WidgetTester tester,
  _Rig rig, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(rig.build(textScale: textScale));
  await tester.pumpAndSettle();
  return rig;
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('the page', () {
    testWidgets('is the lattice AppPage, leaving padding and scrolling to the '
        'pinned scroll view', (tester) async {
      await _pump(tester, _Rig(_api()));

      final page = tester.widget<AppPage>(find.byType(AppPage));
      expect(page.background, AppPageBackground.patterned);
      expect(page.padded, isFalse);
      expect(page.scrollable, isFalse);
      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('the header shows the four stat pills with their values', (
      tester,
    ) async {
      await _pump(tester, _Rig(_api()));

      final pills = tester
          .widgetList<StatPill>(
            find.descendant(
              of: find.byType(LessonHud),
              matching: find.byType(StatPill),
            ),
          )
          .toList();
      expect(pills.map((p) => p.kind), [
        StatKind.streak,
        StatKind.beans,
        StatKind.xp,
        StatKind.amole,
      ]);
      expect(pills.map((p) => p.value), [6, 3, 12340, 420]);
      expect(pills[1].max, 5);
      expect(find.text('12,340'), findsOneWidget);
    });

    testWidgets('loading is the library loading state', (tester) async {
      final rig = _Rig(_api());
      await tester.pumpWidget(rig.build());
      expect(find.byType(LoadingState), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(LoadingState), findsNothing);
    });

    testWidgets('a failed load is an ErrorState with Retry, which reloads', (
      tester,
    ) async {
      final api = _api()
        ..skillTreeError = const LessonApiException('socket closed');
      await _pump(tester, _Rig(api));

      final error = tester.widget<ErrorState>(find.byType(ErrorState));
      expect(error.title, "Couldn't load your skill tree");
      expect(error.message, 'Check your connection and try again.');
      expect(error.icon, Icons.wifi_off);
      expect(error.retryLabel, 'Retry');

      api.skillTreeError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Category 1'), findsOneWidget);
    });

    testWidgets('an ended session is an EmptyState with a primary Sign in', (
      tester,
    ) async {
      final api = _api()
        ..skillTreeError = const LessonApiException(
          'unknown',
          errorCode: 'invalid_session',
        );
      await _pump(tester, _Rig(api));

      final empty = tester.widget<EmptyState>(find.byType(EmptyState));
      expect(empty.title, 'Please sign in again');
      expect(empty.icon, Icons.lock_clock);
      expect(empty.tone, AppTone.tertiary);
      final signIn = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Sign in'),
      );
      expect(signIn.variant, AppButtonVariant.primary);
      expect(signIn.expand, isFalse);
    });
  });

  group('section banners', () {
    AppCard cardOf(WidgetTester tester, String title) => tester.widget<AppCard>(
      find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(CategoryBanner),
        ),
        matching: find.byType(AppCard),
      ),
    );

    testWidgets('each is a compact white card with the Tibeb stripe', (
      tester,
    ) async {
      await _pump(tester, _Rig(_api()));

      final card = cardOf(tester, 'Category 1');
      expect(card.topStripe, isTrue);
      expect(card.padding, AppCardPadding.compact);
      expect(card.selected, isNull);
    });

    testWidgets('consecutive sections take primary, secondary and tertiary in '
        'turn, the bar in the same tone', (tester) async {
      _size(tester, const Size(400, 6000));
      await _pump(
        tester,
        _Rig(
          _api(
            tree: _tree(
              categories: 4,
              nodes: [
                for (var i = 1; i <= 4; i++)
                  _node('n$i', 'c$i', SkillNodeState.active),
              ],
            ),
          ),
        ),
      );

      final tones = [
        for (var i = 1; i <= 4; i++) cardOf(tester, 'Category $i').tone,
      ];
      expect(tones, [
        AppTone.primary,
        AppTone.secondary,
        AppTone.tertiary,
        AppTone.primary,
      ]);
      for (var i = 1; i <= 4; i++) {
        final bar = tester.widget<AppProgressBar>(
          find.descendant(
            of: find.ancestor(
              of: find.text('Category $i'),
              matching: find.byType(CategoryBanner),
            ),
            matching: find.byType(AppProgressBar),
          ),
        );
        expect(bar.tone, tones[i - 1]);
        expect(bar.gradient, isTrue);
      }
    });

    testWidgets('the count is a badge and the bar shows it', (tester) async {
      await _pump(tester, _Rig(_api()));

      expect(find.widgetWithText(CountBadge, '1/3 Completed'), findsOneWidget);
      final bar = tester.widget<AppProgressBar>(
        find.descendant(
          of: find.byType(CategoryBanner),
          matching: find.byType(AppProgressBar),
        ),
      );
      expect(bar.value, closeTo(1 / 3, 0.001));
    });

    testWidgets('a section with no skills shows an empty bar, not an error', (
      tester,
    ) async {
      await _pump(
        tester,
        _Rig(
          _api(
            tree: _tree(
              categories: 2,
              nodes: [_node('a', 'c1', SkillNodeState.active)],
            ),
          ),
        ),
      );

      expect(find.widgetWithText(CountBadge, '0/0 Completed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('extentOf is the card and its content, and nothing more', (
      tester,
    ) async {
      late double reserved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              reserved = CategoryBanner.extentOf(
                context,
                const SkillCategory(id: 'c', title: 'Title', subtitle: 'Sub'),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // Gaps, then the card: shelf, border, stripe and compact padding.
      const chrome =
          2 * AppSpacing.spaceXs +
          AppShadows.shelfDepth +
          2 * AppCard.borderWidth +
          TibebStripe.gradientHeight +
          2 * AppSpacing.spaceSm;
      // Content: at least a title and subtitle, a gap and the bar.
      expect(
        reserved,
        greaterThanOrEqualTo(
          chrome + AppSpacing.space2xs + AppProgressBar.regularHeight + 20 + 16,
        ),
      );
      expect(reserved, lessThan(chrome + AppSpacing.space2xs + 12 + 48));
    });
  });

  group('path nodes', () {
    testWidgets('every skill is drawn by the library node, in its state', (
      tester,
    ) async {
      await _pump(tester, _Rig(_api()));

      final states = tester
          .widgetList<PathNode>(find.byType(PathNode))
          .map((n) => n.state)
          .toList();
      expect(states, [
        PathNodeState.completed,
        PathNodeState.active,
        PathNodeState.locked,
      ]);
    });

    testWidgets('a screen reader hears each node once', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Rig(_api()));

      expect(
        find.bySemanticsLabel('Skill b, active, tap to start'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'Skill b\n')), findsNothing);
      semantics.dispose();
    });
  });

  group('the practice card', () {
    Finder card() => find.ancestor(
      of: find.text('Practice'),
      matching: find.byType(AppCard),
    );

    testWidgets('with words due it is a tappable card with a chevron', (
      tester,
    ) async {
      await _pump(tester, _Rig(_api(due: 3)));

      expect(tester.widget<AppCard>(card()).onTap, isNotNull);
      expect(
        find.descendant(of: card(), matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
      final badge = tester.widget<IconBadge>(
        find.descendant(of: card(), matching: find.byType(IconBadge)),
      );
      expect(badge.icon, Icons.refresh);
      expect(badge.tone, AppTone.primary);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: card(), matching: find.byType(Opacity)).first,
            )
            .opacity,
        1,
      );
    });

    testWidgets('with nothing due it is faded, inert and has no chevron', (
      tester,
    ) async {
      await _pump(tester, _Rig(_api()));

      expect(tester.widget<AppCard>(card()).onTap, isNull);
      expect(
        find.descendant(of: card(), matching: find.byIcon(Icons.chevron_right)),
        findsNothing,
      );
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: card(), matching: find.byType(Opacity)).first,
            )
            .opacity,
        0.5,
      );
    });
  });

  group('the download badge', () {
    Finder badgeFor(IconData icon) => find
        .ancestor(of: find.byIcon(icon), matching: find.byType(GestureDetector))
        .first;

    testWidgets('sits in a 48 px tap target, with a label per state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Rig(_api()));

      // The completed and active nodes have one; the locked node none.
      expect(find.byIcon(Icons.download_outlined), findsNWidgets(2));
      expect(
        tester.getSize(badgeFor(Icons.download_outlined)),
        const Size(48, 48),
      );
      expect(
        tester
            .widget<IconBadge>(
              find.widgetWithIcon(IconBadge, Icons.download_outlined).first,
            )
            .size,
        28,
      );
      expect(
        find.bySemanticsLabel('Download for offline use'),
        findsNWidgets(2),
      );
      semantics.dispose();
    });

    testWidgets('a failed download shows the terracotta error badge, which '
        'tries again', (tester) async {
      final semantics = tester.ensureSemantics();
      final api = _api()..startLessonError = Exception('offline');
      await _pump(tester, _Rig(api));

      await tester.tap(find.byIcon(Icons.download_outlined).first);
      await tester.pumpAndSettle();

      final failed = tester.widget<IconBadge>(
        find.widgetWithIcon(IconBadge, Icons.error_outline),
      );
      expect(failed.tone, AppTone.tertiary);
      expect(
        find.bySemanticsLabel('Download failed, tap to try again'),
        findsOneWidget,
      );

      api
        ..startLessonError = null
        ..lessonContent = const LessonContent(
          lessonId: 'lesson-a',
          skillId: 'a',
          title: 'Skill a',
          exercises: [],
          beansAtStart: 5,
          beansMax: 5,
        );
      await tester.tap(find.byIcon(Icons.error_outline));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(
        find.bySemanticsLabel('Downloaded for offline use'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconBadge>(
              find.widgetWithIcon(IconBadge, Icons.download_done),
            )
            .tone,
        AppTone.primary,
      );
      semantics.dispose();
    });
  });

  group('banners', () {
    testWidgets('offline, the saved copy says so in a neutral banner', (
      tester,
    ) async {
      final cache = InMemoryCourseCacheStore();
      final inner = FakeCourseApi(courses: const [_amharic]);
      final courseApi = CachingCourseApi(inner: inner, cache: cache);
      await courseApi.getCourses();
      await cache.saveDashboard('c-en-am', _tree(), amoleBalance: 420);
      await cache.setActiveCourseId('c-en-am');
      inner.failWith = const CourseApiException('Network request failed');
      final api = _api()
        ..skillTreeError = const LessonApiException('Network request failed');

      await _pump(tester, _Rig(api, cache: cache, courseApi: courseApi));

      final banner = tester.widget<InfoBanner>(
        find.widgetWithText(InfoBanner, 'Offline, showing saved progress'),
      );
      expect(banner.tone, AppTone.neutral);
      expect(banner.icon, Icons.cloud_off_outlined);
    });

    Future<InfoBanner> syncBanner(
      WidgetTester tester,
      SyncEngine engine, {
      FakeLessonPackStore? packs,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusBanner(
              syncEngine: engine,
              lessonPackStore: packs ?? FakeLessonPackStore(),
              lessonPackDownloader: LessonPackDownloader(
                lessonApi: ControllableLessonApi(),
                packStore: FakeLessonPackStore(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<InfoBanner>(find.byType(InfoBanner));
    }

    PendingSyncEntry entry({int daysAgo = 0}) => PendingSyncEntry(
      attemptId: 'a$daysAgo',
      lessonId: 'lesson-a',
      correctCount: 1,
      totalCount: 1,
      timeSpent: const Duration(seconds: 5),
      beansRemainingAtEnd: 5,
      clientCompletedAt: DateTime.now().toUtc().subtract(
        Duration(days: daysAgo),
      ),
    );

    testWidgets('offline with lessons downloaded is a quiet neutral banner; '
        'an old queue turns it into a terracotta warning', (tester) async {
      Future<FakeLessonPackStore> packs() async {
        final store = FakeLessonPackStore();
        await store.save(
          const LessonContent(
            lessonId: 'lesson-a',
            skillId: 'a',
            title: 'Skill a',
            exercises: [],
            beansAtStart: 5,
            beansMax: 5,
          ),
        );
        return store;
      }

      SyncEngine offline() => SyncEngine(
        lessonApi: ControllableLessonApi(),
        connectivityMonitor: FakeConnectivityMonitor(online: false),
        queueStore: FakePendingSyncQueueStore(),
      );

      var banner = await syncBanner(tester, offline(), packs: await packs());
      expect(banner.message, 'Offline -- downloaded lessons available');
      expect(banner.tone, AppTone.neutral);
      expect(banner.emphasis, isFalse);

      final old = offline();
      await old.enqueueOfflineCompletion(entry(daysAgo: 31));
      banner = await syncBanner(tester, old, packs: await packs());
      expect(banner.tone, AppTone.tertiary);
      expect(banner.emphasis, isTrue);
    });

    testWidgets('offline with nothing downloaded is a tertiary banner', (
      tester,
    ) async {
      final banner = await syncBanner(
        tester,
        SyncEngine(
          lessonApi: ControllableLessonApi(),
          connectivityMonitor: FakeConnectivityMonitor(online: false),
          queueStore: FakePendingSyncQueueStore(),
        ),
      );
      expect(banner.message, 'Offline -- nothing downloaded');
      expect(banner.tone, AppTone.tertiary);
      expect(banner.emphasis, isFalse);
    });

    testWidgets('a failing sync is tertiary; an old queue adds emphasis', (
      tester,
    ) async {
      final api = ControllableLessonApi()
        ..completeLessonError = Exception('down');
      final engine = SyncEngine(
        lessonApi: api,
        connectivityMonitor: FakeConnectivityMonitor(online: true),
        queueStore: FakePendingSyncQueueStore(),
        baseRetryDelay: const Duration(seconds: 30),
      );
      await engine.enqueueOfflineCompletion(entry());
      var banner = await syncBanner(tester, engine);
      expect(banner.message, 'Sync failed -- retrying...');
      expect(banner.tone, AppTone.tertiary);
      expect(banner.emphasis, isFalse);
      engine.dispose();

      final old = SyncEngine(
        lessonApi: ControllableLessonApi(),
        connectivityMonitor: FakeConnectivityMonitor(online: false),
        queueStore: FakePendingSyncQueueStore(),
      );
      await old.enqueueOfflineCompletion(entry(daysAgo: 31));
      banner = await syncBanner(tester, old);
      expect(banner.emphasis, isTrue);
      expect(banner.tone, AppTone.tertiary);
      expect(
        banner.message,
        'Offline -- nothing downloaded (unsynced for 30+ days -- please '
        'reconnect soon)',
      );
    });
  });

  group('the course panel', () {
    Future<void> panel(
      WidgetTester tester, {
      bool loading = false,
      VoidCallback? onRetry,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoursePanel(
              courses: loading || onRetry != null ? const [] : const [_amharic],
              activeCourseId: 'c-en-am',
              loading: loading,
              onCourseSelected: (_) {},
              onAddCourse: () {},
              onSettings: () {},
              onDownloads: () {},
              onRetry: onRetry,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('is a card with its entries as list rows', (tester) async {
      await panel(tester);

      expect(
        find.ancestor(
          of: find.text('Course settings'),
          matching: find.byType(AppCard),
        ),
        findsOneWidget,
      );
      final rows = tester.widgetList<ListRow>(find.byType(ListRow)).toList();
      expect(rows.map((r) => r.title), ['Course settings', 'Manage downloads']);
      expect(rows.map((r) => r.icon), [
        Icons.settings_outlined,
        Icons.folder_outlined,
      ]);
      expect(
        tester
            .widget<IconBadge>(find.widgetWithIcon(IconBadge, Icons.add))
            .square,
        isTrue,
      );
    });

    testWidgets('loading shows the library spinner', (tester) async {
      await panel(tester, loading: true);
      expect(find.byType(AppSpinner), findsOneWidget);
    });

    testWidgets('a failed rail offers a compact secondary Retry', (
      tester,
    ) async {
      var retries = 0;
      await panel(tester, onRetry: () => retries++);

      final retry = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Retry'),
      );
      expect(retry.variant, AppButtonVariant.secondary);
      expect(retry.size, AppButtonSize.compact);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });

  group('the course picker', () {
    Future<void> open(WidgetTester tester, CourseApi api) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: GestureDetector(
                  onTap: () => pickAndSwitchCourse(context, courseApi: api),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
    }

    AppCard rowFor(WidgetTester tester, String title) => tester.widget<AppCard>(
      find.ancestor(
        of: find.textContaining(title),
        matching: find.byType(AppCard),
      ),
    );

    testWidgets('opens as the library sheet, closed by its round button', (
      tester,
    ) async {
      await open(tester, FakeCourseApi());

      expect(find.byType(AppSheetFrame), findsOneWidget);
      await tester.tap(find.byType(AppIconButton));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheetFrame), findsNothing);
    });

    testWidgets('each course is a card: the active one chosen, coming soon '
        'faded and inert', (tester) async {
      await open(tester, FakeCourseApi());

      final active = rowFor(tester, 'English to Amharic');
      expect(active.selected, isTrue);
      expect(active.tone, AppTone.primary);
      expect(active.padding, AppCardPadding.compact);

      final other = rowFor(tester, 'English to Afaan Oromo');
      expect(other.selected, isFalse);
      expect(other.tone, AppTone.neutral);
      expect(other.onTap, isNotNull);

      final soon = rowFor(tester, 'Afaan Oromo to Amharic');
      expect(soon.onTap, isNull);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.textContaining('Afaan Oromo to Amharic'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        0.6,
      );
    });

    testWidgets('progress is a library bar', (tester) async {
      await open(tester, FakeCourseApi());

      final bar = tester.widget<AppProgressBar>(
        find.descendant(
          of: find.ancestor(
            of: find.text('English to Amharic'),
            matching: find.byType(AppCard),
          ),
          matching: find.byType(AppProgressBar),
        ),
      );
      expect(bar.value, closeTo(0.3, 0.001));
      expect(bar.semanticLabel, '3 of 10 skills');
    });

    testWidgets('a failed list is an ErrorState with Retry', (tester) async {
      final api = FakeCourseApi()
        ..failWith = const CourseApiException('offline');
      await open(tester, api);

      final error = tester.widget<ErrorState>(find.byType(ErrorState));
      expect(error.title, "Couldn't load your courses");
      expect(error.retryLabel, 'Retry');

      api.failWith = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('For English speakers'), findsOneWidget);
    });
  });

  testWidgets('the home placeholder is an AppPage with an EmptyState', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePlaceholderScreen()));

    expect(find.byType(AppPage), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  group('small screens', () {
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('the dashboard, with every card and banner, fits '
            '${size.width.toInt()} px at ${scale}x', (tester) async {
          _size(tester, size);
          final rig = _Rig(
            _api(tree: _tree(categories: 2), due: 12),
            online: false,
          );
          await _pump(tester, rig, textScale: scale);

          expect(find.byType(InfoBanner), findsOneWidget); // offline
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('the course picker fits ${size.width.toInt()} px at '
            '${scale}x', (tester) async {
          _size(tester, size);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: GestureDetector(
                    onTap: () => pickAndSwitchCourse(
                      context,
                      courseApi: FakeCourseApi(),
                    ),
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('OPEN'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('the course panel dims the path with the library scrim', (
    tester,
  ) async {
    await _pump(tester, _Rig(_api()));
    await tester.tap(find.text('Amharic'));
    await tester.pumpAndSettle();

    final scrim = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey('course-panel-scrim')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(scrim.color, AppColors.scrim);
  });
}
