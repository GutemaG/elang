// The course panel (011-dashboard-ui-polish, bolt 029, stories 003 and 004):
// the rail with the active course ringed, the "+ Course" tile, the two screen
// entries, the loading and failure states, horizontal scrolling, tap targets
// and narrow-screen behaviour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/courses/course_panel.dart';
import 'package:elang/shared/models/course.dart';

const _amharic = Course(
  id: 'c-en-am',
  learningLanguage: 'am',
  fromLanguage: 'en',
  title: 'English to Amharic',
  isActive: true,
);
const _oromo = Course(
  id: 'c-en-om',
  learningLanguage: 'om',
  fromLanguage: 'en',
  title: 'English to Afaan Oromo',
);
const _oromoFromAmharic = Course(
  id: 'c-am-om',
  learningLanguage: 'om',
  fromLanguage: 'am',
  title: 'Amharic to Afaan Oromo',
);

class _Taps {
  final List<String> switched = [];
  int addCourse = 0;
  int settings = 0;
  int downloads = 0;
  int retries = 0;
}

Future<_Taps> _pump(
  WidgetTester tester, {
  List<Course> courses = const [_amharic, _oromo],
  bool loading = false,
  bool failed = false,
  double width = 400,
  double textScale = 1.0,
}) async {
  final taps = _Taps();
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: CoursePanel(
            courses: loading || failed ? const [] : courses,
            activeCourseId: 'c-en-am',
            loading: loading,
            onCourseSelected: (c) => taps.switched.add(c.id),
            onAddCourse: () => taps.addCourse++,
            onSettings: () => taps.settings++,
            onDownloads: () => taps.downloads++,
            onRetry: failed ? () => taps.retries++ : null,
          ),
        ),
      ),
    ),
  );
  // A spinner never settles, so the loading case is pumped once instead.
  if (loading) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  return taps;
}

void main() {
  testWidgets('shows a tile per course, the add tile, and both entries', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Amharic'), findsOneWidget);
    expect(find.text('Afaan Oromo'), findsOneWidget);
    expect(find.text('from English'), findsNWidgets(2));
    expect(find.text('Course'), findsOneWidget); // the add tile
    expect(find.text('Course settings'), findsOneWidget);
    expect(find.text('Manage downloads'), findsOneWidget);
  });

  testWidgets('exactly one tile is marked as the current course', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, courses: const [_amharic, _oromo, _oromoFromAmharic]);

    expect(find.bySemanticsLabel('Amharic, current course'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Switch to Afaan Oromo from English'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Switch to Afaan Oromo from Amharic'),
      findsOneWidget,
    );

    handle.dispose();
  });

  testWidgets('tapping a course reports it, including the active one', (
    tester,
  ) async {
    final taps = await _pump(tester);

    await tester.tap(find.text('Afaan Oromo'));
    await tester.pumpAndSettle();
    expect(taps.switched, ['c-en-om']);

    // The panel does not decide what "tapping the active course" means; the
    // dashboard does. It still reports the tap.
    await tester.tap(find.text('Amharic'));
    await tester.pumpAndSettle();
    expect(taps.switched, ['c-en-om', 'c-en-am']);
  });

  testWidgets('the add tile and both entries fire their callbacks', (
    tester,
  ) async {
    final taps = await _pump(tester);

    await tester.tap(find.text('Course'));
    await tester.tap(find.text('Course settings'));
    await tester.tap(find.text('Manage downloads'));
    await tester.pumpAndSettle();

    expect(taps.addCourse, 1);
    expect(taps.settings, 1);
    expect(taps.downloads, 1);
  });

  testWidgets('every tile and row is at least a 48dp tap target', (
    tester,
  ) async {
    await _pump(tester);

    for (final label in ['Amharic', 'Afaan Oromo', 'Course']) {
      final size = tester.getSize(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
      );
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
    for (final label in ['Course settings', 'Manage downloads']) {
      final size = tester.getSize(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
      );
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('while the rail loads the entries are already usable', (
    tester,
  ) async {
    final taps = await _pump(tester, loading: true);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Course settings'), findsOneWidget);

    await tester.tap(find.text('Manage downloads'));
    await tester.pump(); // the spinner is still running; do not settle
    expect(taps.downloads, 1);
  });

  testWidgets('a failed course list offers Retry and keeps the entries', (
    tester,
  ) async {
    final taps = await _pump(tester, failed: true);

    expect(find.text("Couldn't load your courses"), findsOneWidget);
    expect(find.text('Course settings'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(taps.retries, 1);
  });

  testWidgets('more courses than fit scroll horizontally without clipping', (
    tester,
  ) async {
    final many = [
      _amharic,
      _oromo,
      _oromoFromAmharic,
      for (int i = 0; i < 6; i++)
        Course(
          id: 'extra-$i',
          learningLanguage: 'om',
          fromLanguage: 'en',
          title: 'Extra $i',
        ),
    ];
    await _pump(tester, courses: many, width: 320);

    expect(tester.takeException(), isNull);
    // The last tile is off-screen until the rail is scrolled to it.
    final rail = find.byType(ListView);
    await tester.drag(rail, const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Course'), findsOneWidget); // the add tile, now reachable
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 320.0]) {
    testWidgets('does not overflow at ${width}dp with large text', (
      tester,
    ) async {
      await _pump(
        tester,
        courses: const [_amharic, _oromo, _oromoFromAmharic],
        width: width,
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
    });
  }
}
