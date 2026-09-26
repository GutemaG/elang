// Lesson complete and the lesson pop-ups on the library
// (018-mobile-design-system, bolt 048, story 003): the celebration page with
// stat cards, progress cards and a docked Continue; level-up in the library
// dialog; exit, review and out-of-beans in the library sheet, each
// returning what it returned before; and small screens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_complete_screen.dart';
import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/features/lesson/widgets/exit_lesson_sheet.dart';
import 'package:elang/features/lesson/widgets/level_up_sheet.dart';
import 'package:elang/features/lesson/widgets/out_of_beans_sheet.dart';
import 'package:elang/features/lesson/widgets/review_skill_sheet.dart';
import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/models/skill_lesson_progress.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_card.dart';
import 'package:elang/shared/widgets/app_page.dart';
import 'package:elang/shared/widgets/app_sheet.dart';
import 'package:elang/shared/widgets/app_status.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

const _result = LessonCompletionResult(
  xpEarned: 25,
  dailyXpTotal: 25,
  dailyXpTarget: 30,
  streakCount: 6,
  streakIncreasedToday: true,
  accuracyPercent: 94,
  correctCount: 16,
  totalCount: 17,
  timeSpent: Duration(minutes: 2),
);

LessonCompletionResult _with({
  bool streakIncreasedToday = true,
  bool pendingSync = false,
  bool isReview = false,
  int dailyXpTotal = 25,
  int dailyXpTarget = 30,
  int? crownLevel,
  bool crownLeveledUp = false,
  bool streakFreezeUnlocked = false,
}) => LessonCompletionResult(
  xpEarned: 25,
  dailyXpTotal: dailyXpTotal,
  dailyXpTarget: dailyXpTarget,
  streakCount: 6,
  streakIncreasedToday: streakIncreasedToday,
  accuracyPercent: 94,
  correctCount: 16,
  totalCount: 17,
  timeSpent: const Duration(minutes: 2),
  pendingSync: pendingSync,
  isReview: isReview,
  crownLevel: crownLevel,
  crownLeveledUp: crownLeveledUp,
  streakFreezeUnlocked: streakFreezeUnlocked,
);

BeansStatus _beans({
  int amole = 1000,
  int regen = 30,
  Duration? next = const Duration(minutes: 12),
}) => BeansStatus(
  beans: 0,
  beansMax: 5,
  regenMinutesPerBean: regen,
  amoleBalance: amole,
  refillCostAmole: 350,
  nextBeanAt: next == null ? null : DateTime.now().add(next),
);

Widget _app(Widget home, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

/// A page that opens a pop-up with [open] and shows what it returned.
class _Opener extends StatefulWidget {
  const _Opener(this.open);

  final Future<Object?> Function(BuildContext) open;

  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  String _result = 'none yet';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              final result = await widget.open(context);
              if (mounted) setState(() => _result = 'returned $result');
            },
            child: const Text('OPEN'),
          ),
          Text(_result),
        ],
      ),
    ),
  );
}

Future<void> _open(
  WidgetTester tester,
  Future<Object?> Function(BuildContext) open, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(_app(_Opener(open), textScale: textScale));
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

/// Taps the backdrop above the sheet or around the dialog.
Future<void> _tapOutside(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('lesson complete', () {
    testWidgets('a celebration page with Continue docked as the primary '
        'action', (tester) async {
      await tester.pumpWidget(
        _app(const LessonCompleteScreen(result: _result)),
      );

      expect(
        tester.widget<AppPage>(find.byType(AppPage)).background,
        AppPageBackground.celebration,
      );
      final page = tester.widget<AppPage>(find.byType(AppPage));
      expect(page.bottomDock, hasLength(1));
      expect(_button(tester, 'Continue').variant, AppButtonVariant.primary);
      expect(
        tester
            .widget<IconBadge>(find.widgetWithIcon(IconBadge, Icons.local_cafe))
            .size,
        120,
      );
    });

    testWidgets('three stat cards: gold XP, terracotta streak with its '
        'ribbon, green accuracy', (tester) async {
      await tester.pumpWidget(
        _app(const LessonCompleteScreen(result: _result)),
      );

      final cards = tester.widgetList<StatCard>(find.byType(StatCard)).toList();
      expect(cards.map((c) => c.label), ['XP EARNED', 'STREAK', 'ACCURACY']);
      expect(cards.map((c) => c.value), ['+25', '6 Days', '94%']);
      expect(cards.map((c) => c.tone), [
        AppTone.secondary,
        AppTone.tertiary,
        AppTone.primary,
      ]);
      expect(cards.map((c) => c.ribbon), [null, '+1 Today', null]);
    });

    testWidgets('no ribbon when the streak did not grow today', (tester) async {
      await tester.pumpWidget(
        _app(LessonCompleteScreen(result: _with(streakIncreasedToday: false))),
      );
      expect(find.byType(RibbonBadge), findsNothing);
      expect(find.text('+1 Today'), findsNothing);
    });

    testWidgets('the daily goal is a gold card with a bar and the XP line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const LessonCompleteScreen(result: _result)),
      );

      final card = find.ancestor(
        of: find.text('Daily Goal Progress'),
        matching: find.byType(AppCard),
      );
      expect(tester.widget<AppCard>(card).tone, AppTone.secondary);
      final bar = tester.widget<AppProgressBar>(
        find.descendant(of: card, matching: find.byType(AppProgressBar)),
      );
      expect(bar.value, closeTo(25 / 30, 0.001));
      expect(bar.tone, AppTone.secondary);
      expect(find.text('25 / 30 XP today'), findsOneWidget);
    });

    testWidgets('a goal already passed fills the bar, and no goal leaves it '
        'empty', (tester) async {
      AppProgressBar bar() => tester.widget<AppProgressBar>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Daily Goal Progress'),
            matching: find.byType(AppCard),
          ),
          matching: find.byType(AppProgressBar),
        ),
      );
      await tester.pumpWidget(
        _app(LessonCompleteScreen(result: _with(dailyXpTotal: 60))),
      );
      expect(bar().value, 1);
      await tester.pumpWidget(
        _app(LessonCompleteScreen(result: _with(dailyXpTarget: 0))),
      );
      expect(bar().value, 0);
    });

    testWidgets('offline, the streak waits for sync and the goal card keeps '
        'its sentence instead of a bar', (tester) async {
      await tester.pumpWidget(
        _app(LessonCompleteScreen(result: _with(pendingSync: true))),
      );

      final streak = tester
          .widgetList<StatCard>(find.byType(StatCard))
          .elementAt(1);
      expect(streak.value, '--');
      expect(streak.label, 'SYNCS WHEN ONLINE');
      expect(streak.ribbon, isNull);
      expect(find.byType(AppProgressBar), findsNothing);
      expect(find.textContaining("You're offline"), findsOneWidget);
    });

    testWidgets('skill progress is a green card with a bar of lessons done', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const LessonCompleteScreen(
            result: _result,
            skillProgress: SkillLessonProgress(
              skillTitle: 'Numbers',
              lessonsDoneBefore: 0,
              lessonCount: 3,
            ),
          ),
        ),
      );

      final card = find.ancestor(
        of: find.text('Lesson 1 of 3 done'),
        matching: find.byType(AppCard),
      );
      expect(tester.widget<AppCard>(card).tone, AppTone.primary);
      final bar = tester.widget<AppProgressBar>(
        find.descendant(of: card, matching: find.byType(AppProgressBar)),
      );
      expect(bar.value, closeTo(1 / 3, 0.001));
      expect(bar.semanticLabel, 'Lessons done in Numbers');
      expect(find.text('2 more lessons to finish Numbers.'), findsOneWidget);
    });

    testWidgets('a review shows two green stat cards and a neutral banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(LessonCompleteScreen(result: _with(isReview: true))),
      );

      final cards = tester.widgetList<StatCard>(find.byType(StatCard)).toList();
      expect(cards.map((c) => c.label), ['CORRECT', 'ACCURACY']);
      expect(cards.map((c) => c.value), ['16/17', '94%']);
      expect(cards.every((c) => c.tone == AppTone.primary), isTrue);
      final banner = tester.widget<InfoBanner>(find.byType(InfoBanner));
      expect(banner.tone, AppTone.neutral);
      expect(banner.message, startsWith("Reviews don't earn XP"));
      expect(find.text('Review Complete!'), findsOneWidget);
    });
  });

  group('level-up', () {
    Future<void> openSummary(
      WidgetTester tester,
      LessonCompletionResult result,
    ) async {
      await _open(
        tester,
        (context) => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => LessonCompleteScreen(result: result),
          ),
        ),
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens in the library dialog, laid out by SheetHero, with a '
        'level badge', (tester) async {
      await openSummary(tester, _with(crownLevel: 3, crownLeveledUp: true));

      expect(find.byType(AppDialogFrame), findsOneWidget);
      expect(find.byType(AppSheetFrame), findsNothing);
      final hero = tester.widget<SheetHero>(find.byType(SheetHero));
      expect(hero.title, 'Crown Level Up!');
      final badge = hero.illustrationBadge! as CountBadge;
      expect(badge.label, 'Lv 3');
      expect(badge.tone, AppTone.secondary);
      expect(
        (hero.primaryAction! as AppButton).variant,
        AppButtonVariant.primary,
      );
    });

    testWidgets('no level, no badge', (tester) async {
      await openSummary(tester, _with(streakFreezeUnlocked: true));

      expect(find.text('Streak Freeze Unlocked!'), findsOneWidget);
      expect(
        tester.widget<SheetHero>(find.byType(SheetHero)).illustrationBadge,
        isNull,
      );
    });

    for (final (how, close) in <(String, Future<void> Function(WidgetTester))>[
      (
        'Continue',
        (tester) async {
          await tester.tap(find.text('Continue').last);
          await tester.pumpAndSettle();
        },
      ),
      (
        'the close button',
        (tester) async {
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
        },
      ),
      ('a tap outside', _tapOutside),
    ]) {
      testWidgets('$how closes it, and the summary then goes back', (
        tester,
      ) async {
        await openSummary(tester, _with(crownLevel: 2, crownLeveledUp: true));
        await close(tester);

        expect(find.byType(AppDialogFrame), findsNothing);
        expect(find.text('OPEN'), findsOneWidget);
        expect(find.text('Lesson Complete!'), findsNothing);
      });
    }
  });

  group('review a finished skill', () {
    testWidgets('opens in the library sheet: primary Review, "Not now" as a '
        'text link', (tester) async {
      await _open(tester, (c) => showReviewSkillSheet(c, 'Greetings'));

      expect(find.byType(AppSheetFrame), findsOneWidget);
      expect(
        tester.widget<SheetHero>(find.byType(SheetHero)).title,
        'Greetings',
      );
      expect(_button(tester, 'Review').variant, AppButtonVariant.primary);
      expect(_button(tester, 'Not now').variant, AppButtonVariant.text);
    });

    testWidgets('Review returns true', (tester) async {
      await _open(tester, (c) => showReviewSkillSheet(c, 'Greetings'));
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(find.text('returned true'), findsOneWidget);
    });

    testWidgets('Not now, a tap outside and a swipe down return null', (
      tester,
    ) async {
      await _open(tester, (c) => showReviewSkillSheet(c, 'Greetings'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('returned null'), findsOneWidget);

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await _tapOutside(tester);
      expect(find.byType(AppSheetFrame), findsNothing);
      expect(find.text('returned null'), findsOneWidget);

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Greetings'), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheetFrame), findsNothing);
      expect(find.text('returned null'), findsOneWidget);
    });
  });

  group('leave a lesson', () {
    testWidgets('Keep learning is primary and returns false; Leave is '
        'secondary and returns true', (tester) async {
      await _open(tester, showExitLessonSheet);

      expect(find.byType(AppSheetFrame), findsOneWidget);
      expect(
        tester.widget<SheetHero>(find.byType(SheetHero)).tone,
        AppTone.tertiary,
      );
      expect(
        _button(tester, 'Keep learning').variant,
        AppButtonVariant.primary,
      );
      expect(_button(tester, 'Leave').variant, AppButtonVariant.secondary);
      expect(
        tester.getRect(find.text('Leave')).top,
        greaterThan(tester.getRect(find.text('Keep learning')).bottom),
      );

      await tester.tap(find.text('Keep learning'));
      await tester.pumpAndSettle();
      expect(find.text('returned false'), findsOneWidget);

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('returned true'), findsOneWidget);
    });

    testWidgets('a tap outside returns null, and practice says practice', (
      tester,
    ) async {
      await _open(tester, (c) => showExitLessonSheet(c, isPractice: true));

      expect(find.text('Leave this practice?'), findsOneWidget);
      expect(
        find.text("Your progress in this practice won't be saved."),
        findsOneWidget,
      );
      await _tapOutside(tester);
      expect(find.text('returned null'), findsOneWidget);
    });
  });

  group('out of beans', () {
    Future<void> openBeans(
      WidgetTester tester,
      BeansStatus status, {
      VoidCallback? onRefill,
      VoidCallback? onDismiss,
      double textScale = 1,
    }) => _open(
      tester,
      (context) => showOutOfBeansSheet(
        context,
        builder: (sheet) => OutOfBeansSheet(
          status: status,
          onRefill: onRefill ?? () => Navigator.of(sheet).pop(),
          onDismiss: onDismiss ?? () => Navigator.of(sheet).pop(),
        ),
      ),
      textScale: textScale,
    );

    testWidgets('neither a tap outside nor a swipe down closes it, and it has '
        'no handle', (tester) async {
      await openBeans(tester, _beans());

      final frame = tester.widget<AppSheetFrame>(find.byType(AppSheetFrame));
      expect(frame.showHandle, isFalse);
      await _tapOutside(tester);
      await tester.drag(find.text('Out of Beans!'), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text('Out of Beans!'), findsOneWidget);
    });

    testWidgets('the illustration carries a "0 / 5" terracotta badge', (
      tester,
    ) async {
      await openBeans(tester, _beans());

      final hero = tester.widget<SheetHero>(find.byType(SheetHero));
      expect(hero.tone, AppTone.tertiary);
      final badge = hero.illustrationBadge! as CountBadge;
      expect(badge.label, '0 / 5');
      expect(badge.tone, AppTone.tertiary);
    });

    testWidgets('the refill timer is a striped card with the countdown, a bar '
        'and the refill rate', (tester) async {
      final semantics = tester.ensureSemantics();
      await openBeans(tester, _beans());

      final card = tester.widget<AppCard>(
        find.ancestor(
          of: find.text('Next bean in'),
          matching: find.byType(AppCard),
        ),
      );
      expect(card.topStripe, isTrue);
      expect(
        tester
            .widget<IconBadge>(
              find.widgetWithIcon(IconBadge, Icons.hourglass_top),
            )
            .square,
        isTrue,
      );
      expect(find.textContaining(RegExp(r'^1[12]:\d\d$')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Next bean in 1[12]:\d\d$')),
        findsOneWidget,
      );

      final bar = tester.widget<AppProgressBar>(find.byType(AppProgressBar));
      // 12 of 30 minutes still to go: 60 % brewed.
      expect(bar.value, closeTo(0.6, 0.01));
      expect(bar.startLabel, 'Refills 1 bean every 30 minutes');
      semantics.dispose();
    });

    testWidgets('one minute is singular', (tester) async {
      await openBeans(
        tester,
        _beans(regen: 1, next: const Duration(seconds: 30)),
      );
      expect(find.text('Refills 1 bean every 1 minute'), findsOneWidget);
      expect(
        tester.widget<AppProgressBar>(find.byType(AppProgressBar)).value,
        closeTo(0.5, 0.02),
      );
    });

    testWidgets('an unknown rate has no caption and an empty bar', (
      tester,
    ) async {
      await openBeans(tester, _beans(regen: 0));
      final bar = tester.widget<AppProgressBar>(find.byType(AppProgressBar));
      expect(bar.startLabel, isNull);
      expect(bar.value, 0);
    });

    testWidgets('beans already full show no countdown and an empty bar', (
      tester,
    ) async {
      await openBeans(tester, _beans(next: null));
      expect(find.text('--:--'), findsOneWidget);
      expect(
        tester.widget<AppProgressBar>(find.byType(AppProgressBar)).value,
        0,
      );
    });

    testWidgets('Refill is the orange button with the price as its badge, '
        'read aloud with it', (tester) async {
      final semantics = tester.ensureSemantics();
      var refills = 0;
      await openBeans(tester, _beans(), onRefill: () => refills++);

      final refill = _button(tester, 'Refill with Amole');
      expect(refill.variant, AppButtonVariant.accent);
      expect(refill.badge!.label, '350 Amole');
      expect(refill.badge!.icon, Icons.diamond);
      expect(
        find.bySemanticsLabel('Refill with Amole, 350 Amole'),
        findsOneWidget,
      );

      await tester.tap(find.text('Refill with Amole'));
      expect(refills, 1);
      semantics.dispose();
    });

    testWidgets('without enough Amole Refill is disabled, still showing the '
        'price', (tester) async {
      var refills = 0;
      await openBeans(tester, _beans(amole: 100), onRefill: () => refills++);

      final refill = _button(tester, 'Not enough Amole');
      expect(refill.onPressed, isNull);
      expect(refill.badge!.label, '350 Amole');
      await tester.tap(find.text('Not enough Amole'), warnIfMissed: false);
      expect(refills, 0);
    });

    testWidgets('"Not now" is a text link that calls onDismiss', (
      tester,
    ) async {
      var dismissed = 0;
      await openBeans(tester, _beans(), onDismiss: () => dismissed++);
      expect(_button(tester, 'Not now').variant, AppButtonVariant.text);
      await tester.tap(find.text('Not now'));
      expect(dismissed, 1);
    });
  });

  group('the lesson screen uses them', () {
    const mc = MultipleChoiceExercise(
      id: 'mc',
      prompt: 'ቡና',
      promptTranslation: 'What does this word mean?',
      options: ['Coffee', 'Tea', 'Water'],
      correctOptionIndex: 0,
    );

    Widget lesson({int beans = 5}) {
      final connectivity = FakeConnectivityMonitor();
      final api = ControllableLessonApi()
        ..lessonContent = LessonContent(
          lessonId: 'lesson-1',
          skillId: 'skill-1',
          title: 'One',
          beansAtStart: beans,
          beansMax: 5,
          exercises: const [mc, mc],
        )
        ..beansStatus = _beans();
      return _app(
        LessonScreen(
          lessonId: 'lesson-1',
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
        ),
      );
    }

    testWidgets('the close button opens the exit sheet in the library sheet', (
      tester,
    ) async {
      await tester.pumpWidget(lesson());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Exit lesson'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSheetFrame), findsOneWidget);
      expect(find.byType(ExitLessonSheet), findsOneWidget);
    });

    testWidgets('running out of beans opens the sheet that cannot be '
        'dismissed', (tester) async {
      await tester.pumpWidget(lesson(beans: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tea'));
      await tester.pumpAndSettle();

      expect(find.byType(OutOfBeansSheet), findsOneWidget);
      expect(
        tester.widget<AppSheetFrame>(find.byType(AppSheetFrame)).showHandle,
        isFalse,
      );
      await _tapOutside(tester);
      expect(find.byType(OutOfBeansSheet), findsOneWidget);
    });
  });

  group('small screens', () {
    final screens = <String, Widget Function()>{
      'lesson complete': () => const LessonCompleteScreen(
        result: _result,
        skillProgress: SkillLessonProgress(
          skillTitle: 'Numbers & Time',
          lessonsDoneBefore: 2,
          lessonCount: 3,
        ),
      ),
      'offline': () => LessonCompleteScreen(result: _with(pendingSync: true)),
      'review': () => LessonCompleteScreen(result: _with(isReview: true)),
    };
    final popups = <String, Future<Object?> Function(BuildContext)>{
      'exit': showExitLessonSheet,
      'review sheet': (c) => showReviewSkillSheet(c, 'Greetings & Basics'),
      'out of beans': (c) => showOutOfBeansSheet(
        c,
        builder: (_) => OutOfBeansSheet(
          status: _beans(),
          onRefill: () {},
          onDismiss: () {},
        ),
      ),
      'level-up': (c) => showLevelUpDialog(
        c,
        _with(crownLevel: 12, crownLeveledUp: true, streakFreezeUnlocked: true),
      ),
    };
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      for (final scale in const [1.0, 1.3]) {
        final at = '${size.width.toInt()} px at ${scale}x';
        for (final MapEntry(key: name, value: build) in screens.entries) {
          testWidgets('$name fits $at', (tester) async {
            _size(tester, size);
            await tester.pumpWidget(_app(build(), textScale: scale));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
        for (final MapEntry(key: name, value: open) in popups.entries) {
          testWidgets('the $name pop-up fits $at', (tester) async {
            _size(tester, size);
            await _open(tester, open, textScale: scale);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
