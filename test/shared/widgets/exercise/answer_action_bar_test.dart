// AnswerActionBar and its feedback panel: Check, the held space, and
// "Correct!" / "Not quite" above Continue (018-mobile-design-system, unit
// 002 story 003).

import 'package:elang/shared/theme/app_colors.dart';
import 'package:elang/shared/theme/app_motion.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/theme/app_tone.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:elang/shared/widgets/app_status.dart';
import 'package:elang/shared/widgets/exercise/answer_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false, double scale = 1}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(width: 320, child: child),
            ),
          ),
        ),
      ),
    );

AppButton _button(WidgetTester tester) => tester.widget<AppButton>(
  find.descendant(
    of: find.byType(AnswerActionBar),
    matching: find.byType(AppButton),
  ),
);

BoxDecoration _panel(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(AnswerFeedbackPanel),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

/// A question that is graded when its Check is tapped, then reset by
/// Continue.
class _Question extends StatefulWidget {
  const _Question();

  @override
  State<_Question> createState() => _QuestionState();
}

class _QuestionState extends State<_Question> {
  AnswerGrade? grade;
  int continues = 0;

  @override
  Widget build(BuildContext context) => AnswerActionBar(
    grade: grade,
    onCheck: () => setState(() => grade = AnswerGrade.correct),
    canCheck: true,
    onContinue: () => setState(() {
      continues++;
      grade = null;
    }),
  );
}

void main() {
  group('before grading', () {
    testWidgets('Check is a primary button, disabled until there is an '
        'answer', (tester) async {
      var checks = 0;
      await tester.pumpWidget(_host(AnswerActionBar(onCheck: () => checks++)));
      expect(_button(tester).variant, AppButtonVariant.primary);
      expect(_button(tester).label, 'Check');
      expect(_button(tester).onPressed, isNull);
      await tester.tap(find.text('Check'), warnIfMissed: false);
      expect(checks, 0);

      await tester.pumpWidget(
        _host(AnswerActionBar(onCheck: () => checks++, canCheck: true)),
      );
      await tester.tap(find.text('Check'));
      expect(checks, 1);
    });

    testWidgets('without Check, the same height is held empty, hidden from '
        'screen readers and taps', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(AnswerActionBar(onCheck: () {})));
      final withCheck = tester.getSize(find.byType(AnswerActionBar));

      await tester.pumpWidget(_host(const AnswerActionBar()));
      expect(tester.getSize(find.byType(AnswerActionBar)), withCheck);
      expect(find.bySemanticsLabel('Check'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AnswerActionBar),
          matching: find.byWidgetPredicate(
            (w) => w is Opacity && w.opacity == 0,
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('no panel until graded', (tester) async {
      await tester.pumpWidget(_host(AnswerActionBar(onCheck: () {})));
      expect(find.byType(AnswerFeedbackPanel), findsNothing);
      expect(find.text('Correct!'), findsNothing);
      expect(find.text('Not quite'), findsNothing);
    });
  });

  group('after grading', () {
    testWidgets('right: "Correct!" in green on mint above a primary '
        'Continue', (tester) async {
      await tester.pumpWidget(
        _host(AnswerActionBar(grade: AnswerGrade.correct, onContinue: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('Correct!'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Correct!')).style!.color,
        AppColors.primaryContainer,
      );
      final panel = _panel(tester);
      expect(panel.color, AppColors.answerCorrect);
      expect((panel.border! as Border).top.color, AppTone.primary.border);
      expect(
        tester.widget<IconBadge>(find.byType(IconBadge)).icon,
        Icons.check,
      );
      expect(_button(tester).variant, AppButtonVariant.primary);
      expect(_button(tester).label, 'Continue');
      expect(
        tester.getRect(find.byType(AnswerFeedbackPanel)).bottom,
        lessThan(tester.getRect(find.text('Continue')).top),
      );
    });

    testWidgets('wrong: "Not quite" in terracotta on blush above a '
        'terracotta Continue', (tester) async {
      await tester.pumpWidget(
        _host(AnswerActionBar(grade: AnswerGrade.incorrect, onContinue: () {})),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text('Not quite')).style!.color,
        AppColors.tertiaryBrand,
      );
      final panel = _panel(tester);
      expect(panel.color, AppColors.answerIncorrect);
      expect((panel.border! as Border).top.color, AppTone.tertiary.border);
      expect(
        tester.widget<IconBadge>(find.byType(IconBadge)).icon,
        Icons.close,
      );
      expect(_button(tester).variant, AppButtonVariant.destructive);
    });

    testWidgets('the panel slides up over AppMotion.feedback and then '
        'stops', (tester) async {
      await tester.pumpWidget(_host(const _Question()));
      await tester.tap(find.text('Check'));
      await tester.pump();

      final panel = find.byType(AnswerFeedbackPanel);
      await tester.pump(AppMotion.feedback ~/ 2);
      final halfway = tester.getSize(panel).height;
      await tester.pump(AppMotion.feedback);
      final full = tester.getSize(panel).height;
      expect(halfway, greaterThan(0));
      expect(halfway, lessThan(full));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('with reduced motion the panel is there at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AnswerActionBar(grade: AnswerGrade.correct, onContinue: () {}),
          reduceMotion: true,
        ),
      );
      final first = tester.getSize(find.byType(AnswerFeedbackPanel)).height;
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnswerFeedbackPanel)).height, first);
      expect(first, greaterThan(0));
    });

    testWidgets('a screen reader hears the result as it appears', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(AnswerActionBar(grade: AnswerGrade.incorrect, onContinue: () {})),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Not quite')),
        isSemantics(label: 'Not quite', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('one tap on Continue calls onContinue once; the bar goes '
        'back to Check', (tester) async {
      await tester.pumpWidget(_host(const _Question()));
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final state = tester.state<_QuestionState>(find.byType(_Question));
      expect(state.continues, 1);
      expect(find.byType(AnswerFeedbackPanel), findsNothing);
      expect(find.text('Check'), findsOneWidget);
    });

    testWidgets('it shows only the grade it is given: a new grade replaces '
        'the panel', (tester) async {
      await tester.pumpWidget(
        _host(AnswerActionBar(grade: AnswerGrade.correct, onContinue: () {})),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(AnswerActionBar(grade: AnswerGrade.incorrect, onContinue: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('Correct!'), findsNothing);
      expect(find.text('Not quite'), findsOneWidget);
    });
  });

  group('notice', () {
    testWidgets('sits above the button in terracotta', (tester) async {
      const message = "Couldn't save your progress. Tap Continue to try again.";
      await tester.pumpWidget(
        _host(
          AnswerActionBar(
            grade: AnswerGrade.correct,
            onContinue: () {},
            notice: message,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text(message));
      expect(text.style!.color, AppColors.tertiaryBrand);
      expect(
        tester.getRect(find.text(message)).bottom,
        lessThan(tester.getRect(find.text('Continue')).top),
      );
      expect(
        tester.getRect(find.text(message)).top,
        greaterThan(tester.getRect(find.byType(AnswerFeedbackPanel)).bottom),
      );
    });
  });

  testWidgets('fits 320 px at 1.3x text in every state', (tester) async {
    for (final bar in [
      const AnswerActionBar(),
      AnswerActionBar(onCheck: () {}),
      AnswerActionBar(grade: AnswerGrade.correct, onContinue: () {}),
      AnswerActionBar(
        grade: AnswerGrade.incorrect,
        onContinue: () {},
        notice: "Couldn't save your progress. Tap Continue to try again.",
      ),
    ]) {
      await tester.pumpWidget(_host(bar, scale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
