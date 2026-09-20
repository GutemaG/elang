// Course picker tests (010-multi-language-courses, bolt 026): grouped by the
// language to learn with the from-language on each row, the active course
// marked, coming soon disabled, progress shown, a load failure with Retry, and
// `pickAndSwitchCourse` switching only on a real change and keeping the
// current course (with a message) when the switch fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/courses/course_picker.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/widgets/selectable_option_card.dart';

/// A page with a button that runs `pickAndSwitchCourse` and stores its result.
class _Harness extends StatefulWidget {
  const _Harness({required this.api, this.onResult});

  final CourseApi api;
  final ValueChanged<Course?>? onResult;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await pickAndSwitchCourse(
              context,
              courseApi: widget.api,
            );
            widget.onResult?.call(result);
          },
          child: const Text('OPEN'),
        ),
      ),
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  CourseApi api, {
  ValueChanged<Course?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _Harness(api: api, onResult: onResult),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

SelectableOptionCard _card(WidgetTester tester, String text) {
  return tester.widget<SelectableOptionCard>(
    find
        .ancestor(
          of: find.text(text),
          matching: find.byType(SelectableOptionCard),
        )
        .first,
  );
}

void main() {
  testWidgets(
    'groups courses by the language to learn, with the from-language',
    (tester) async {
      await _open(tester, FakeCourseApi());

      expect(find.text('Choose a course'), findsOneWidget);
      expect(find.text('Learn Amharic'), findsOneWidget);
      expect(find.text('Learn Afaan Oromo'), findsOneWidget);
      expect(find.text('From English'), findsNWidgets(2));
      expect(find.text('From Amharic'), findsOneWidget);
      expect(find.text('From Afaan Oromo'), findsOneWidget);
    },
  );

  testWidgets(
    'marks the active course, shows progress, and disables coming soon',
    (tester) async {
      await _open(tester, FakeCourseApi());

      final active = _card(tester, 'English to Amharic · 3/10 skills');
      expect(active.selected, isTrue);
      expect(active.enabled, isTrue);

      final comingSoon = _card(tester, 'Coming soon');
      expect(comingSoon.enabled, isFalse);
      expect(comingSoon.selected, isFalse);

      // A course with no skills yet shows just its title.
      expect(find.text('English to Afaan Oromo · 0/2 skills'), findsOneWidget);
    },
  );

  testWidgets('a load failure shows a message and Retry, which recovers', (
    tester,
  ) async {
    final api = FakeCourseApi()..failWith = const CourseApiException('offline');
    await _open(tester, api);

    expect(find.text("Couldn't load your courses"), findsOneWidget);

    api.failWith = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Learn Amharic'), findsOneWidget);
  });

  testWidgets('choosing another course switches to it and returns it', (
    tester,
  ) async {
    final api = FakeCourseApi();
    Course? result;
    await _open(tester, api, onResult: (c) => result = c);

    await tester.tap(find.textContaining('English to Afaan Oromo'));
    await tester.pumpAndSettle();

    expect(api.switchCalls, ['c-en-om']);
    expect(api.activeCourseId, 'c-en-om');
    expect(result?.id, 'c-en-om');
    expect(result?.isActive, isTrue);
    // The sheet closed.
    expect(find.text('Choose a course'), findsNothing);
  });

  testWidgets('choosing the already-active course does nothing', (
    tester,
  ) async {
    final api = FakeCourseApi();
    var results = 0;
    Course? result;
    await _open(
      tester,
      api,
      onResult: (c) {
        results++;
        result = c;
      },
    );

    await tester.tap(find.textContaining('English to Amharic'));
    await tester.pumpAndSettle();

    expect(api.switchCalls, isEmpty);
    expect(results, 1);
    expect(result, isNull);
  });

  testWidgets('a coming-soon course cannot be chosen', (tester) async {
    final api = FakeCourseApi();
    await _open(tester, api);

    await tester.tap(find.text('Coming soon'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(api.switchCalls, isEmpty);
    expect(find.text('Choose a course'), findsOneWidget);
  });

  testWidgets('a failed switch keeps the current course and shows a message', (
    tester,
  ) async {
    final api = FakeCourseApi()
      ..switchFailure = const CourseApiException('nope');
    Course? result = const Course(
      id: 'sentinel',
      learningLanguage: 'am',
      fromLanguage: 'en',
      title: 'x',
    );
    await _open(tester, api, onResult: (c) => result = c);

    await tester.tap(find.textContaining('English to Afaan Oromo'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(api.activeCourseId, 'c-en-am');
    expect(
      find.text("Couldn't switch course. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('dismissing the sheet does nothing', (tester) async {
    final api = FakeCourseApi();
    Course? result = const Course(
      id: 'sentinel',
      learningLanguage: 'am',
      fromLanguage: 'en',
      title: 'x',
    );
    await _open(tester, api, onResult: (c) => result = c);

    await tester.tapAt(const Offset(10, 10)); // the barrier above the sheet
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(api.switchCalls, isEmpty);
  });

  for (final width in [360.0, 320.0]) {
    testWidgets('does not overflow at ${width}dp with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: const TextScaler.linear(1.3),
          ),
          child: MaterialApp(home: _Harness(api: FakeCourseApi())),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
