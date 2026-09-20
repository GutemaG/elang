// Course catalog tests (010 bolt 026, rebuilt by 011 bolt 029): grouped by the
// language the learner speaks, each row naming the language taught with its
// course title, progress as a bar, the active course marked, coming soon
// disabled, a load failure with Retry, and `pickAndSwitchCourse` switching only
// on a real change and keeping the current course (with a message) when the
// switch fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/courses/course_picker.dart';
import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/fake_course_api.dart';

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

void main() {
  testWidgets('groups courses by the language the learner speaks', (
    tester,
  ) async {
    await _open(tester, FakeCourseApi());

    expect(find.text('Choose a course'), findsOneWidget);
    expect(find.text('For English speakers'), findsOneWidget);
    expect(find.text('For Amharic speakers'), findsOneWidget);
    expect(find.text('For Afaan Oromo speakers'), findsOneWidget);

    // Each row names the language taught; its course title says the pair.
    expect(find.text('Amharic'), findsNWidgets(2)); // from English, from Oromo
    expect(find.text('Afaan Oromo'), findsNWidgets(2));
    expect(find.text('English to Amharic'), findsOneWidget);
    expect(find.text('Amharic to Afaan Oromo'), findsOneWidget);
  });

  testWidgets('marks the active course, shows progress, and disables coming soon', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, FakeCourseApi());

    // The active course is the only one wearing the check.
    expect(find.byIcon(Icons.check), findsOneWidget);
    // Progress is a bar now, not a count in a sentence, but it still says so.
    expect(find.bySemanticsLabel('3 of 10 skills'), findsOneWidget);
    expect(find.bySemanticsLabel('0 of 2 skills'), findsNWidgets(2));

    // Coming soon is named on the row and locked.
    expect(
      find.text('Afaan Oromo to Amharic · Coming soon'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    handle.dispose();
  });

  testWidgets('a load failure shows a message and Retry, which recovers', (
    tester,
  ) async {
    final api = FakeCourseApi()..failWith = const CourseApiException('offline');
    await _open(tester, api);

    expect(find.text("Couldn't load your courses"), findsOneWidget);

    api.failWith = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('For English speakers'), findsOneWidget);
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

    await tester.tap(
      find.text('Afaan Oromo to Amharic · Coming soon'),
      warnIfMissed: false,
    );
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

  testWidgets('the close button dismisses without choosing', (tester) async {
    final api = FakeCourseApi();
    Course? result = const Course(
      id: 'sentinel',
      learningLanguage: 'am',
      fromLanguage: 'en',
      title: 'x',
    );
    await _open(tester, api, onResult: (c) => result = c);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(api.switchCalls, isEmpty);
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
