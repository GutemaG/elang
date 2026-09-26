// The consistency sweep (018-mobile-design-system, bolt 049, story 005,
// NFR-2 and NFR-4): every screen, sheet and dialog, in its main states, on
// a small phone (360×640) and a large one (430×932), at 1.0× and 1.3×
// text. Any overflow or other framework error fails.
//
// Each screen's own tests check its layout; this file only checks that
// nothing breaks at these sizes, all in one place.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/features/auth/auth_dependencies.dart';
import 'package:elang/features/auth/auth_flow_controller.dart';
import 'package:elang/features/auth/screens/daily_goal_selection_screen.dart';
import 'package:elang/features/auth/screens/language_selection_screen.dart';
import 'package:elang/features/auth/screens/onboarding_carousel_screen.dart';
import 'package:elang/features/auth/screens/sign_in_screen.dart';
import 'package:elang/features/auth/screens/splash_screen.dart';
import 'package:elang/features/courses/course_picker.dart';
import 'package:elang/features/lesson/screens/download_management_screen.dart';
import 'package:elang/features/lesson/screens/lesson_complete_screen.dart';
import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/features/lesson/screens/skill_tree_dashboard_screen.dart';
import 'package:elang/features/lesson/widgets/exit_lesson_sheet.dart';
import 'package:elang/features/lesson/widgets/level_up_sheet.dart';
import 'package:elang/features/lesson/widgets/out_of_beans_sheet.dart';
import 'package:elang/features/lesson/widgets/review_skill_sheet.dart';
import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/models/skill_lesson_progress.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/screens/home_placeholder_screen.dart';
import 'package:elang/shared/services/auth_api.dart';
import 'package:elang/shared/services/caching_course_api.dart';
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/course_cache_store.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/http_user_preferences_api.dart';
import 'package:elang/shared/services/lesson_api_exception.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/onboarding_repository.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/app_sheet.dart';
import 'package:elang/shared/widgets/exercise/answer_action_bar.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';

import '../helpers/controllable_auth_api.dart';
import '../helpers/controllable_lesson_api.dart';
import '../helpers/fake_answer_feedback_player.dart';
import '../helpers/fake_connectivity_monitor.dart';
import '../helpers/fake_lesson_audio_player.dart';
import '../helpers/fake_lesson_pack_store.dart';
import '../helpers/fake_native_sign_in.dart';
import '../helpers/fake_pending_sync_queue_store.dart';
import '../helpers/fake_user_preferences_api.dart';
import '../helpers/in_memory_secure_storage_service.dart';

// ---------------------------------------------------------------------------
// The app shell and small drivers.

Widget _app(Widget home, double scale) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
  // Stand-ins for where screens navigate, so a scene needs no whole app.
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    builder: (_) => Scaffold(body: Text('ROUTE ${settings.name}')),
  ),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// A page with one button that opens a pop-up with [open].
class _Opener extends StatelessWidget {
  const _Opener(this.open);

  final Future<Object?> Function(BuildContext) open;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: GestureDetector(
        onTap: () => open(context),
        child: const Text('OPEN'),
      ),
    ),
  );
}

Future<void> _popup(
  WidgetTester tester,
  double scale,
  Future<Object?> Function(BuildContext) open,
) async {
  await tester.pumpWidget(_app(_Opener(open), scale));
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Onboarding and sign-in.

OnboardingRepository _onboarding() =>
    OnboardingRepository(storage: InMemorySecureStorageService());

SignInScreen _signIn(ControllableAuthApi api) {
  final storage = InMemorySecureStorageService();
  return SignInScreen(
    authApi: api,
    onboardingRepository: OnboardingRepository(storage: storage),
    sessionRepository: SessionRepository(storage: storage),
    googleSignIn: FakeNativeSignIn(),
    appleSignIn: FakeNativeSignIn(),
  );
}

Future<void> _carousel(WidgetTester tester, double scale, int page) async {
  await tester.pumpWidget(_app(const OnboardingCarouselScreen(), scale));
  await tester.pumpAndSettle();
  for (var i = 0; i < page; i++) {
    await _tap(tester, find.text('Continue'));
  }
}

// ---------------------------------------------------------------------------
// The dashboard.

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
      title: 'Greetings and farewells $id',
      subtitle: '',
      state: state,
      categoryId: category,
      crownLevel: state == SkillNodeState.completed ? 3 : 0,
    );

SkillTreeResponse _tree() => SkillTreeResponse(
  course: _amharic,
  categories: const [
    SkillCategory(id: 'c1', title: 'Foundations of speech', subtitle: 'መሠረት'),
    SkillCategory(id: 'c2', title: 'Around the market', subtitle: 'ገበያ'),
  ],
  nodes: [
    _node('a', 'c1', SkillNodeState.completed),
    _node('b', 'c1', SkillNodeState.active),
    _node('c', 'c1', SkillNodeState.locked),
    _node('d', 'c2', SkillNodeState.locked),
  ],
  streakCount: 128,
  beans: 3,
  beansMax: 5,
  totalXp: 123450,
);

ControllableLessonApi _dashboardApi() => ControllableLessonApi()
  ..skillTree = _tree()
  ..beansStatus = const BeansStatus(
    beans: 3,
    beansMax: 5,
    regenMinutesPerBean: 30,
    amoleBalance: 12420,
    refillCostAmole: 350,
  )
  ..dueCount = 12;

Widget _dashboard(
  ControllableLessonApi api, {
  CourseApi? courseApi,
  CourseCacheStore? cache,
}) {
  final connectivity = FakeConnectivityMonitor();
  final packStore = FakeLessonPackStore();
  final session = SessionRepository(storage: InMemorySecureStorageService());
  return SkillTreeDashboardScreen(
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
      connectivityMonitor: connectivity,
      queueStore: FakePendingSyncQueueStore(),
    ),
    courseApi: courseApi ?? FakeCourseApi(),
    courseCache: cache,
    sessionRepository: session,
    userPreferencesApi: HttpUserPreferencesApi(sessionRepository: session),
    soundPreferenceRepository: SoundPreferenceRepository(
      storage: InMemorySecureStorageService(),
    ),
  );
}

// ---------------------------------------------------------------------------
// The lesson: one question of each type, with long prompts and answers.

const _clip = 'https://cdn.buna.app/audio/selam.mp3';

const _exercises = <String, Exercise>{
  'multiple choice': MultipleChoiceExercise(
    id: 'mc',
    prompt: 'እንኳን ደህና መጡ',
    promptTranslation: 'What does this greeting mean?',
    options: ['Welcome, come in', 'Goodbye for now', 'Thank you very much'],
    correctOptionIndex: 0,
  ),
  'listening': ListeningExercise(
    id: 'li',
    audioUrl: _clip,
    instruction: 'Tap what you hear',
    options: ['ሰላም', 'ደህና ሁን', 'አመሰግናለሁ'],
    correctOptionIndex: 0,
  ),
  'sentence': SentenceConstructionExercise(
    id: 'sc',
    promptTranslation: "Translate: 'I would like a cup of coffee, please'",
    wordBank: ['እባክህ', 'አንድ', 'ስኒ', 'ቡና', 'እፈልጋለሁ', 'ሻይ', 'ውሃ'],
    correctSentence: ['እባክህ', 'አንድ', 'ስኒ', 'ቡና', 'እፈልጋለሁ'],
  ),
  'match pairs': MatchPairsExercise(
    id: 'mp',
    prompt: 'Match each word to its meaning',
    leftTiles: [
      MatchPairsTile(id: 'l1', text: 'ቡና'),
      MatchPairsTile(id: 'l2', text: 'ሻይ'),
      MatchPairsTile(id: 'l3', text: 'ውሃ'),
      MatchPairsTile(id: 'l4', text: 'ዳቦ'),
    ],
    rightTiles: [
      MatchPairsTile(id: 'r2', text: 'Tea'),
      MatchPairsTile(id: 'r4', text: 'Bread'),
      MatchPairsTile(id: 'r1', text: 'Coffee'),
      MatchPairsTile(id: 'r3', text: 'Water'),
    ],
    correctPairs: {'l1': 'r1', 'l2': 'r2', 'l3': 'r3', 'l4': 'r4'},
  ),
  'gap fill': GapFillExercise(
    id: 'gf',
    prompt: "Complete the sentence: 'I want some cold water'",
    sentenceBefore: 'እኔ ቀዝቃዛ',
    sentenceAfter: 'እፈልጋለሁ',
    options: ['ውሃ', 'ዳቦ', 'ቡና'],
    correctOptionIndex: 0,
  ),
  // Pictures from the network never arrive in a test, so these tiles show
  // their descriptions: the most text a picture tile holds.
  'image choice': ImageChoiceExercise(
    id: 'ic',
    prompt: "Choose the picture: 'ውሻ'",
    choices: [
      PictureChoice(
        imageUrl: 'https://cdn.buna.app/p/dog.webp',
        altText: 'A dog sitting on the grass',
      ),
      PictureChoice(
        imageUrl: 'https://cdn.buna.app/p/cat.webp',
        altText: 'A cat asleep on a chair',
      ),
      PictureChoice(
        imageUrl: 'https://cdn.buna.app/p/house.webp',
        altText: 'A small round house',
      ),
      PictureChoice(
        imageUrl: 'https://cdn.buna.app/p/water.webp',
        altText: 'A glass of water',
      ),
    ],
    correctOptionIndex: 0,
  ),
  // Twelve tiles with a twin (two ፍ), the most the client lays out for.
  'spell tiles': SpellTilesExercise(
    id: 'st',
    prompt: "Spell 'Fruit'",
    tiles: [
      SpellTile(id: 't1', text: 'ፍ'),
      SpellTile(id: 't2', text: 'ሬ'),
      SpellTile(id: 't3', text: 'ቡ'),
      SpellTile(id: 't4', text: 'ፍ'),
      SpellTile(id: 't5', text: 'ና'),
      SpellTile(id: 't6', text: 'ራ'),
      SpellTile(id: 't7', text: 'ሻ'),
      SpellTile(id: 't8', text: 'ይ'),
      SpellTile(id: 't9', text: 'ው'),
      SpellTile(id: 't10', text: 'ሃ'),
      SpellTile(id: 't11', text: 'ዳ'),
      SpellTile(id: 't12', text: 'ቦ'),
    ],
    correctSequence: ['t1', 't6', 't4', 't2'],
  ),
  'audio image choice': AudioImageChoiceExercise(
    id: 'aic',
    audioUrl: _clip,
    instruction: 'Tap the picture you hear',
    choices: [
      PictureChoice(imageUrl: 'assets/pictures/water.webp', altText: 'Water'),
      PictureChoice(imageUrl: 'assets/pictures/dog.webp', altText: 'A dog'),
      PictureChoice(imageUrl: 'assets/pictures/house.webp', altText: 'House'),
      PictureChoice(imageUrl: 'assets/pictures/cat.webp', altText: 'A cat'),
    ],
    correctOptionIndex: 3,
  ),
};

const _result = LessonCompletionResult(
  xpEarned: 25,
  dailyXpTotal: 25,
  dailyXpTarget: 30,
  streakCount: 128,
  streakIncreasedToday: true,
  accuracyPercent: 94,
  correctCount: 16,
  totalCount: 17,
  timeSpent: Duration(minutes: 12, seconds: 34),
);

BeansStatus _outOfBeans() => BeansStatus(
  beans: 0,
  beansMax: 5,
  nextBeanAt: DateTime.now().add(const Duration(minutes: 30)),
  regenMinutesPerBean: 30,
  amoleBalance: 12420,
  refillCostAmole: 350,
);

Widget _lesson(List<Exercise> exercises, {bool online = true}) {
  final api = ControllableLessonApi()
    ..lessonContent = LessonContent(
      lessonId: 'lesson-sweep',
      skillId: 'skill-sweep',
      title: 'Greetings and farewells',
      beansAtStart: 5,
      beansMax: 5,
      exercises: exercises,
    )
    ..completionResult = _result
    ..beansStatus = _outOfBeans();
  final connectivity = FakeConnectivityMonitor(online: online);
  return LessonScreen(
    lessonId: 'lesson-sweep',
    lessonApi: api,
    audioPlayer: FakeLessonAudioPlayer(),
    feedbackPlayer: FakeAnswerFeedbackPlayer(),
    connectivityMonitor: connectivity,
    lessonPackStore: FakeLessonPackStore(),
    syncEngine: SyncEngine(
      lessonApi: api,
      connectivityMonitor: connectivity,
      queueStore: FakePendingSyncQueueStore(),
    ),
  );
}

Finder _tile(String label) =>
    find.byWidgetPredicate((w) => w is AnswerTile && w.label == label);

/// Answers [exercise] correctly, so the feedback panel shows.
Future<void> _answerRight(WidgetTester tester, Exercise exercise) async {
  switch (exercise) {
    case MultipleChoiceExercise e:
      await _tap(tester, _tile(e.options[e.correctOptionIndex]));
    case ListeningExercise e:
      await _tap(tester, _tile(e.options[e.correctOptionIndex]));
    case GapFillExercise e:
      await _tap(tester, _tile(e.options[e.correctOptionIndex]));
    case SentenceConstructionExercise e:
      for (final word in e.correctSentence) {
        await _tap(tester, _tile(word).last);
      }
      await _tap(tester, find.text('Check'));
    case MatchPairsExercise e:
      final text = {
        for (final t in [...e.leftTiles, ...e.rightTiles]) t.id: t.text,
      };
      for (final MapEntry(key: left, value: right) in e.correctPairs.entries) {
        await _tap(tester, _tile(text[left]!));
        await _tap(tester, _tile(text[right]!));
      }
    case ImageChoiceExercise e:
      await _tap(tester, _tile(e.choices[e.correctOptionIndex].altText));
    case AudioImageChoiceExercise e:
      await _tap(tester, _tile(e.choices[e.correctOptionIndex].altText));
    case SpellTilesExercise e:
      for (final id in e.correctSequence) {
        await _tap(tester, find.byKey(ValueKey('bank-$id')));
      }
      await _tap(tester, find.text('Check'));
  }
}

// ---------------------------------------------------------------------------
// Settings and downloads.

SessionApi _sessionApi({bool fails = false}) => SessionApi(
  client: MockClient((request) async {
    if (fails) return http.Response('', 500);
    return http.Response(
      jsonEncode({
        'valid': true,
        'user': {
          'id': 'user-1',
          'selected_language': 'am',
          'daily_xp_target': 30,
          'notification_enabled': true,
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

Future<Widget> _settings({bool fails = false}) async {
  final sessions = SessionRepository(storage: InMemorySecureStorageService());
  await sessions.saveSession(
    SessionState(
      token: 'session-token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      authProvider: 'google',
      displayName: 'Tsehaynesh Gebremariam Woldegiorgis',
      email: 'tsehaynesh.gebremariam.woldegiorgis@example.com',
    ),
  );
  return SettingsScreen(
    sessionApi: _sessionApi(fails: fails),
    courseApi: FakeCourseApi(),
    userPreferencesApi: FakeUserPreferencesApi(),
    soundPreferenceRepository: SoundPreferenceRepository(
      storage: InMemorySecureStorageService(),
    ),
    sessionRepository: sessions,
  );
}

Future<Widget> _downloads({bool empty = false}) async {
  final store = FakeLessonPackStore()..fakeSizeBytes = 2411724;
  if (!empty) {
    await store.save(
      const LessonContent(
        lessonId: 'lesson-a',
        skillId: 'skill-a',
        title: 'Alphabet & Fidel: the first seven families',
        beansAtStart: 5,
        beansMax: 5,
        exercises: [],
      ),
    );
    await store.save(
      const LessonContent(
        lessonId: 'lesson-b',
        skillId: 'skill-b',
        title: 'Akkam',
        beansAtStart: 5,
        beansMax: 5,
        exercises: [],
      ),
      courseId: 'c-am-om',
      courseTitle: 'Amharic to Afaan Oromo',
    );
  }
  return DownloadManagementScreen(
    lessonPackStore: store,
    syncEngine: SyncEngine(
      lessonApi: ControllableLessonApi(),
      connectivityMonitor: FakeConnectivityMonitor(),
      queueStore: FakePendingSyncQueueStore(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Every scene: it pumps a screen at [scale] and drives it to a state.

typedef _Scene = Future<void> Function(WidgetTester tester, double scale);

final _scenes = <String, _Scene>{
  // Onboarding and sign-in.
  'splash': (tester, scale) async {
    final flow = AuthFlowController(
      sessionRepository: AuthDependencies(
        storage: InMemorySecureStorageService(),
      ).sessionRepository,
    );
    await tester.pumpWidget(
      _app(SplashScreen(authFlowController: flow), scale),
    );
    await tester.pump(const Duration(milliseconds: 700));
    // Checked mid-brew: once the animation ends the splash moves on.
    expect(tester.takeException(), isNull);
    expect(find.text('Get Started'), findsOneWidget);
    await tester.pumpAndSettle();
  },
  'carousel, page 1': (tester, scale) => _carousel(tester, scale, 0),
  'carousel, page 2': (tester, scale) => _carousel(tester, scale, 1),
  'carousel, page 3': (tester, scale) => _carousel(tester, scale, 2),
  'language selection': (tester, scale) async {
    await tester.pumpWidget(
      _app(
        LanguageSelectionScreen(
          onboardingRepository: _onboarding(),
          courseApi: FakeCourseApi(),
        ),
        scale,
      ),
    );
    await tester.pumpAndSettle();
  },
  'daily goal': (tester, scale) async {
    await tester.pumpWidget(
      _app(
        DailyGoalSelectionScreen(onboardingRepository: _onboarding()),
        scale,
      ),
    );
    await tester.pumpAndSettle();
  },
  'sign-in': (tester, scale) async {
    await tester.pumpWidget(_app(_signIn(ControllableAuthApi()), scale));
    await tester.pumpAndSettle();
  },
  'sign-in with its error': (tester, scale) async {
    final api = ControllableAuthApi();
    await tester.pumpWidget(_app(_signIn(api), scale));
    await _tap(tester, find.text('Continue with Google'));
    api.completeNext(const AuthFailure(AuthFailureReason.networkError));
    await tester.pumpAndSettle();
  },

  // The dashboard and courses.
  'dashboard': (tester, scale) async {
    await tester.pumpWidget(_app(_dashboard(_dashboardApi()), scale));
    await tester.pumpAndSettle();
  },
  'dashboard, offline with a saved copy': (tester, scale) async {
    final cache = InMemoryCourseCacheStore();
    final inner = FakeCourseApi(courses: const [_amharic]);
    final courseApi = CachingCourseApi(inner: inner, cache: cache);
    await courseApi.getCourses();
    await cache.saveDashboard('c-en-am', _tree(), amoleBalance: 420);
    await cache.setActiveCourseId('c-en-am');
    inner.failWith = const CourseApiException('Network request failed');
    final api = _dashboardApi()
      ..skillTreeError = const LessonApiException('Network request failed');
    await tester.pumpWidget(
      _app(_dashboard(api, courseApi: courseApi, cache: cache), scale),
    );
    await tester.pumpAndSettle();
  },
  'dashboard, failed to load': (tester, scale) async {
    final api = _dashboardApi()
      ..skillTreeError = const LessonApiException('socket closed');
    await tester.pumpWidget(_app(_dashboard(api), scale));
    await tester.pumpAndSettle();
  },
  'course picker': (tester, scale) => _popup(
    tester,
    scale,
    (c) => showAppSheet<Course>(
      context: c,
      builder: (_) => CoursePickerSheet(courseApi: FakeCourseApi()),
    ),
  ),
  'home placeholder': (tester, scale) async {
    await tester.pumpWidget(_app(const HomePlaceholderScreen(), scale));
    await tester.pumpAndSettle();
  },

  // The lesson: each question type, before and after answering.
  for (final MapEntry(key: name, value: exercise) in _exercises.entries) ...{
    'lesson, $name': (tester, scale) async {
      await tester.pumpWidget(_app(_lesson([exercise]), scale));
      await tester.pumpAndSettle();
    },
    'lesson, $name, answered': (tester, scale) async {
      await tester.pumpWidget(_app(_lesson([exercise]), scale));
      await tester.pumpAndSettle();
      await _answerRight(tester, exercise);
    },
  },
  'lesson, a wrong answer': (tester, scale) async {
    await tester.pumpWidget(
      _app(_lesson([_exercises['multiple choice']!]), scale),
    );
    await tester.pumpAndSettle();
    await _tap(tester, _tile('Thank you very much'));
  },
  'lesson, the mistake review': (tester, scale) async {
    final mc = _exercises['multiple choice']!;
    final gap = _exercises['gap fill']!;
    await tester.pumpWidget(_app(_lesson([mc, gap]), scale));
    await tester.pumpAndSettle();
    await _tap(tester, _tile('Thank you very much'));
    await _tap(tester, find.text('Continue'));
    await _answerRight(tester, gap);
    await _tap(tester, find.text('Continue'));
  },
  'lesson, offline': (tester, scale) async {
    await tester.pumpWidget(
      _app(_lesson([_exercises['multiple choice']!], online: false), scale),
    );
    await tester.pumpAndSettle();
  },

  // Lesson complete and the lesson pop-ups.
  'lesson complete': (tester, scale) async {
    await tester.pumpWidget(
      _app(
        const LessonCompleteScreen(
          result: _result,
          skillProgress: SkillLessonProgress(
            skillTitle: 'Greetings and farewells',
            lessonsDoneBefore: 2,
            lessonCount: 3,
          ),
        ),
        scale,
      ),
    );
    await tester.pumpAndSettle();
  },
  'lesson complete, offline': (tester, scale) async {
    await tester.pumpWidget(
      _app(
        const LessonCompleteScreen(
          result: LessonCompletionResult(
            xpEarned: 25,
            dailyXpTotal: 25,
            dailyXpTarget: 30,
            streakCount: 128,
            streakIncreasedToday: false,
            accuracyPercent: 94,
            correctCount: 16,
            totalCount: 17,
            timeSpent: Duration(minutes: 2),
            pendingSync: true,
          ),
        ),
        scale,
      ),
    );
    await tester.pumpAndSettle();
  },
  'exit sheet': (tester, scale) => _popup(tester, scale, showExitLessonSheet),
  'review-skill sheet': (tester, scale) => _popup(
    tester,
    scale,
    (c) => showReviewSkillSheet(c, 'Greetings and farewells'),
  ),
  'out-of-beans sheet': (tester, scale) => _popup(
    tester,
    scale,
    (c) => showOutOfBeansSheet(
      c,
      builder: (_) => OutOfBeansSheet(
        status: _outOfBeans(),
        onRefill: () {},
        onDismiss: () {},
      ),
    ),
  ),
  'level-up dialog': (tester, scale) => _popup(
    tester,
    scale,
    (c) => showLevelUpDialog(
      c,
      const LessonCompletionResult(
        xpEarned: 25,
        dailyXpTotal: 25,
        dailyXpTarget: 30,
        streakCount: 128,
        streakIncreasedToday: true,
        accuracyPercent: 94,
        correctCount: 16,
        totalCount: 17,
        timeSpent: Duration(minutes: 2),
        crownLevel: 12,
        crownLeveledUp: true,
        streakFreezeUnlocked: true,
      ),
    ),
  ),

  // Settings.
  'settings': (tester, scale) async {
    await tester.pumpWidget(_app(await _settings(), scale));
    await tester.pumpAndSettle();
  },
  'settings, failed to load': (tester, scale) async {
    await tester.pumpWidget(_app(await _settings(fails: true), scale));
    await tester.pumpAndSettle();
  },
  'settings, the daily-goal sheet': (tester, scale) async {
    await tester.pumpWidget(_app(await _settings(), scale));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Daily goal'));
  },
  'settings, the log-out dialog': (tester, scale) async {
    await tester.pumpWidget(_app(await _settings(), scale));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Log out'));
  },

  // Downloads.
  'downloads': (tester, scale) async {
    await tester.pumpWidget(_app(await _downloads(), scale));
    await tester.pumpAndSettle();
  },
  'downloads, empty': (tester, scale) async {
    await tester.pumpWidget(_app(await _downloads(empty: true), scale));
    await tester.pumpAndSettle();
  },
  'downloads, the delete dialog': (tester, scale) async {
    await tester.pumpWidget(_app(await _downloads(), scale));
    await tester.pumpAndSettle();
    await _tap(tester, find.byIcon(Icons.delete_outline_rounded).first);
  },
};

/// What each scene must end up showing, so a scene that never reached its
/// state cannot pass by drawing something else.
final _shows = <String, Finder>{
  'splash': find.textContaining('ROUTE'),
  'carousel, page 1': find.text('Bite-Sized Amharic'),
  'carousel, page 2': find.text('Stay Motivated with Streaks'),
  'carousel, page 3': find.text('Get Started'),
  'language selection': find.textContaining('Amharic'),
  'daily goal': find.text('Regular · 10 min/day'),
  'sign-in': find.text('Continue with Google'),
  'sign-in with its error': find.text('Retry'),
  'dashboard': find.text('Foundations of speech'),
  'dashboard, offline with a saved copy': find.text(
    'Offline, showing saved progress',
  ),
  'dashboard, failed to load': find.text("Couldn't load your skill tree"),
  'course picker': find.text('Choose a course'),
  'home placeholder': find.byType(HomePlaceholderScreen),
  for (final name in _exercises.keys) ...{
    'lesson, $name': find.byType(AnswerTile),
    'lesson, $name, answered': find.byType(AnswerFeedbackPanel),
  },
  'lesson, a wrong answer': find.byType(AnswerFeedbackPanel),
  'lesson, the mistake review': find.text("Let's review your mistakes"),
  'lesson, offline': find.text("You're offline"),
  'lesson complete': find.textContaining('Greetings and farewells'),
  'lesson complete, offline': find.textContaining("You're offline"),
  'exit sheet': find.byType(AppSheetFrame),
  'review-skill sheet': find.byType(AppSheetFrame),
  'out-of-beans sheet': find.byType(AppSheetFrame),
  'level-up dialog': find.byType(AppDialogFrame),
  'settings': find.text('Log out'),
  'settings, failed to load': find.text("Couldn't load your settings"),
  'settings, the daily-goal sheet': find.text('Casual · 5 min/day'),
  'settings, the log-out dialog': find.text('Log out?'),
  'downloads': find.textContaining('Akkam'),
  'downloads, empty': find.text('No downloaded lessons yet.'),
  'downloads, the delete dialog': find.textContaining('Delete "Alphabet'),
};

void main() {
  test('every scene says what it shows', () {
    expect(_shows.keys.toSet(), _scenes.keys.toSet());
  });

  for (final size in const [Size(360, 640), Size(430, 932)]) {
    for (final scale in const [1.0, 1.3]) {
      final at = '${size.width.toInt()}×${size.height.toInt()} at ${scale}x';
      group(at, () {
        for (final MapEntry(key: name, value: scene) in _scenes.entries) {
          testWidgets('$name lays out without overflow', (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            await scene(tester, scale);

            expect(tester.takeException(), isNull);
            expect(_shows[name], findsWidgets);
          });
        }
      });
    }
  }
}
