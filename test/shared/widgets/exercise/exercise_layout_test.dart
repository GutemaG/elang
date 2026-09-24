// ExerciseLayout, its top bar, and QuestionPrompt: the one frame and the
// one prompt style (018-mobile-design-system, unit 002 story 001).

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_spacing.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_typography.dart';
import 'package:elang/shared/widgets/app_icon_button.dart';
import 'package:elang/shared/widgets/app_page.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:elang/shared/widgets/exercise/answer_action_bar.dart';
import 'package:elang/shared/widgets/exercise/answer_tile.dart';
import 'package:elang/shared/widgets/exercise/audio_play_button.dart';
import 'package:elang/shared/widgets/exercise/exercise_layout.dart';
import 'package:elang/shared/widgets/tactile_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: home,
    ),
  ),
);

Widget _prompt(Widget child, {double scale = 1, double width = 320}) => _app(
  scale: scale,
  Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

ExerciseLayout _layout({
  VoidCallback? onClose,
  int? beans = 3,
  int tiles = 3,
  AnswerGrade? grade,
}) => ExerciseLayout(
  onClose: onClose ?? () {},
  progress: 0.4,
  beans: beans,
  beansMax: beans == null ? null : 5,
  prompt: const QuestionPrompt(
    instruction: 'What does this mean?',
    question: 'ቡና',
  ),
  answers: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < tiles; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
          child: AnswerTile(label: 'Option $i', onTap: () {}),
        ),
    ],
  ),
  actionBar: AnswerActionBar(grade: grade, onContinue: () {}),
);

Future<void> _phone(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('ExerciseLayout', () {
    testWidgets('sits on AppPage with the top bar, prompt, answers and the '
        'docked action bar', (tester) async {
      await _phone(tester, const Size(400, 800));
      await tester.pumpWidget(_app(_layout()));

      expect(find.byType(AppPage), findsOneWidget);
      final page = tester.widget<AppPage>(find.byType(AppPage));
      expect(page.topBar, isA<ExerciseTopBar>());
      expect(page.bottomDock, hasLength(1));
      expect(page.bottomDock!.single, isA<AnswerActionBar>());
      expect(page.scrollable, isTrue);
      expect(page.padded, isTrue);
    });

    testWidgets('24 px between the prompt and the answers; 20 px margins', (
      tester,
    ) async {
      await _phone(tester, const Size(400, 800));
      await tester.pumpWidget(_app(_layout()));

      final question = tester.getRect(find.text('ቡና'));
      final firstTile = tester.getRect(find.byType(AnswerTile).first);
      expect(firstTile.top - question.bottom, 24);
      expect(firstTile.left, AppSpacing.marginMobile);
      expect(firstTile.right, 400 - AppSpacing.marginMobile);
      expect(
        tester.getTopLeft(find.text('What does this mean?')).dx,
        AppSpacing.marginMobile,
      );
    });

    testWidgets('the action bar is pinned at the bottom in the dock', (
      tester,
    ) async {
      await _phone(tester, const Size(400, 800));
      await tester.pumpWidget(_app(_layout(grade: AnswerGrade.correct)));
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.byType(AnswerActionBar));
      expect(bar.bottom, 800 - AppSpacing.spaceLg);
      expect(bar.left, AppSpacing.marginMobile);
    });

    testWidgets('the action bar stays in the same place whether or not the '
        'answers fill the page', (tester) async {
      await _phone(tester, const Size(400, 800));
      await tester.pumpWidget(_app(_layout(tiles: 1)));
      final few = tester.getRect(find.byType(AnswerActionBar));
      await tester.pumpWidget(_app(_layout(tiles: 12)));
      expect(tester.getRect(find.byType(AnswerActionBar)), few);
    });

    testWidgets('at 360x640 and 1.3x text, a finger scrolls to the last '
        'answer and the action bar stays on screen', (tester) async {
      await _phone(tester, const Size(360, 640));
      await tester.pumpWidget(
        _app(_layout(tiles: 8, grade: AnswerGrade.incorrect), scale: 1.3),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final last = find.text('Option 7');
      final dock = tester.getRect(find.byType(AnswerActionBar));
      expect(dock.bottom, lessThanOrEqualTo(640));
      for (var i = 0; i < 10; i++) {
        if (tester.getRect(last).bottom < dock.top) break;
        await tester.dragFrom(const Offset(180, 250), const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(tester.getRect(last).bottom, lessThan(dock.top));
      expect(tester.getRect(find.byType(AnswerActionBar)), dock);
    });
  });

  group('ExerciseTopBar', () {
    testWidgets('close is "Exit lesson" and calls onClose once', (
      tester,
    ) async {
      var closes = 0;
      await _phone(tester, const Size(400, 800));
      await tester.pumpWidget(_app(_layout(onClose: () => closes++)));

      await tester.tap(find.byTooltip('Exit lesson'));
      await tester.pumpAndSettle();
      expect(closes, 1);
      final button = tester.widget<AppIconButton>(find.byType(AppIconButton));
      expect(button.icon, Icons.close);
    });

    testWidgets('the close face lines up with the 20 px page margin', (
      tester,
    ) async {
      await _phone(tester, const Size(400, 800));
      await tester.pumpWidget(_app(_layout()));
      final face = find.descendant(
        of: find.byType(AppIconButton),
        matching: find.byType(TactilePressable),
      );
      expect(tester.getTopLeft(face).dx, AppSpacing.marginMobile);
    });

    testWidgets('shows lesson progress and the beans pill', (tester) async {
      await _phone(tester, const Size(400, 800));
      await tester.pumpWidget(_app(_layout()));

      final bar = tester.widget<AppProgressBar>(find.byType(AppProgressBar));
      expect(bar.value, 0.4);
      final pill = tester.widget<StatPill>(find.byType(StatPill));
      expect(pill.kind, StatKind.beans);
      expect(pill.value, 3);
      expect(pill.max, 5);
      expect(
        tester.getRect(find.byType(AppProgressBar)).right,
        lessThan(tester.getRect(find.byType(StatPill)).left),
      );
    });

    testWidgets('a lesson without beans has no pill; the bar takes the '
        'room', (tester) async {
      await _phone(tester, const Size(400, 800));
      await tester.pumpWidget(_app(_layout(beans: null)));
      expect(find.byType(StatPill), findsNothing);
      expect(
        tester.getRect(find.byType(AppProgressBar)).right,
        400 - AppTopBar.sidePadding,
      );
    });

    testWidgets('is as tall as every other page\'s top bar', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Column(
              children: [
                const ExerciseTopBar(
                  key: Key('exercise'),
                  onClose: _noop,
                  progress: 0.5,
                  beans: 5,
                  beansMax: 5,
                ),
                AppTopBar(
                  key: const Key('page'),
                  leading: const AppIconButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onPressed: _noop,
                  ),
                  title: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('exercise'))).height,
        tester.getSize(find.byKey(const Key('page'))).height,
      );
    });

    testWidgets('fits a 320 px phone at 1.3x text', (tester) async {
      await _phone(tester, const Size(320, 640));
      await tester.pumpWidget(_app(_layout(beans: 5), scale: 1.3));
      expect(tester.takeException(), isNull);
    });
  });

  group('QuestionPrompt', () {
    testWidgets('an instruction is one muted line and the question large and '
        'bold below it', (tester) async {
      await tester.pumpWidget(
        _prompt(
          const QuestionPrompt(
            instruction: 'Complete the sentence',
            question: 'I want coffee',
          ),
        ),
      );
      final instruction = tester.widget<Text>(
        find.text('Complete the sentence'),
      );
      expect(instruction.style!.fontSize, AppTypography.labelLg.fontSize);
      expect(instruction.style!.color, AppColors.onSurfaceVariant);
      final question = tester.widget<Text>(find.text('I want coffee'));
      expect(question.style!.fontSize, AppTypography.headlineMd.fontSize);
      expect(question.style!.fontWeight, FontWeight.w700);
      expect(question.style!.color, AppColors.onSurface);
      expect(
        tester.getTopLeft(find.text('I want coffee')).dy -
            tester.getBottomLeft(find.text('Complete the sentence')).dy,
        AppSpacing.space2xs,
      );
    });

    testWidgets('without a question the instruction alone is the headline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _prompt(
          const QuestionPrompt(instruction: 'Match each word to its meaning'),
        ),
      );
      final headline = tester.widget<Text>(
        find.text('Match each word to its meaning'),
      );
      expect(headline.style!.fontSize, AppTypography.headlineMd.fontSize);
      expect(headline.style!.color, AppColors.onSurface);
    });

    testWidgets('the headline is a heading for screen readers; the '
        'instruction line is not', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _prompt(
          const QuestionPrompt(instruction: 'Hiiki', question: 'Buna maaloo'),
        ),
      );
      expect(
        tester.getSemantics(find.text('Buna maaloo')),
        isSemantics(label: 'Buna maaloo', isHeader: true),
      );
      expect(
        tester.getSemantics(find.text('Hiiki')),
        isSemantics(label: 'Hiiki', isHeader: false),
      );
      await tester.pumpWidget(
        _prompt(const QuestionPrompt(instruction: 'Match the pairs')),
      );
      expect(
        tester.getSemantics(find.text('Match the pairs')),
        isSemantics(label: 'Match the pairs', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('pronunciation then translation sit under the question, in '
        'that order, in their styles', (tester) async {
      await tester.pumpWidget(
        _prompt(
          const QuestionPrompt(
            instruction: 'What does this mean?',
            question: 'ቡና እፈልጋለሁ',
            pronunciation: 'buna efellegalehu',
            translation: 'I want coffee',
          ),
        ),
      );
      final q = tester.getRect(find.text('ቡና እፈልጋለሁ'));
      final p = tester.getRect(find.text('buna efellegalehu'));
      final t = tester.getRect(find.text('I want coffee'));
      expect(p.top - q.bottom, AppSpacing.space2xs);
      expect(t.top - p.bottom, AppSpacing.space2xs);
      expect(p.left, q.left);

      final phonetic = tester
          .widget<Text>(find.text('buna efellegalehu'))
          .style!;
      expect(phonetic, AppTypography.phonetic);
      expect(phonetic.fontSize, 14);
      expect(phonetic.fontWeight, FontWeight.w500);
      expect(phonetic.color, AppColors.textMuted);
      final translation = tester
          .widget<Text>(find.text('I want coffee'))
          .style!;
      expect(translation.fontSize, AppTypography.bodyMd.fontSize);
      expect(translation.color, AppColors.onSurfaceVariant);
    });

    testWidgets('the speaker chip sits at the start of the question and '
        'plays', (tester) async {
      var plays = 0;
      await tester.pumpWidget(
        _prompt(
          QuestionPrompt(
            instruction: 'Listen',
            question: 'ቡና',
            onPlayAudio: () => plays++,
          ),
        ),
      );
      final chip = find.byType(AudioPlayButton);
      expect(chip, findsOneWidget);
      expect(
        tester.widget<AudioPlayButton>(chip).size,
        AudioPlayButtonSize.small,
      );
      expect(tester.getRect(chip).left, 0);
      expect(
        tester.getRect(find.text('ቡና')).left,
        greaterThan(tester.getRect(chip).right),
      );
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(plays, 1);
    });

    testWidgets('no speaker chip unless asked for', (tester) async {
      await tester.pumpWidget(
        _prompt(const QuestionPrompt(instruction: 'a', question: 'b')),
      );
      expect(find.byType(AudioPlayButton), findsNothing);
    });

    testWidgets('Fidel lines get the Ethiopic line height; Latin keeps its '
        'own', (tester) async {
      await tester.pumpWidget(
        _prompt(const QuestionPrompt(instruction: 'Translate', question: 'ቡና')),
      );
      expect(
        tester.widget<Text>(find.text('ቡና')).style!.height,
        closeTo(
          AppTypography.headlineMd.height! *
              AppTypography.ethiopicLineHeightFactor,
          0.0001,
        ),
      );
      expect(
        tester.widget<Text>(find.text('Translate')).style!.height,
        AppTypography.labelLg.height,
      );
    });

    testWidgets('a long Fidel question wraps and nothing is clipped at 1.3x '
        'on 320 px', (tester) async {
      const long = 'እንደምን አደርክ? ዛሬ ጠዋት ቡና ጠጥተሃል ወይስ ሻይ?';
      await tester.pumpWidget(
        _prompt(
          scale: 1.3,
          const QuestionPrompt(
            instruction: 'Translate this sentence',
            question: long,
            onPlayAudio: _noop,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
      expect(paragraph.didExceedMaxLines, isFalse);
      final lineHeight =
          1.3 *
          AppTypography.headlineMd.fontSize! *
          AppTypography.headlineMd.height! *
          AppTypography.ethiopicLineHeightFactor;
      expect(tester.getSize(find.text(long)).height, greaterThan(lineHeight));
    });
  });
}

void _noop() {}
