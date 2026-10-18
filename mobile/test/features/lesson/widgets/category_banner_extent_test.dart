// The section banner must fit the height it reserves (011-dashboard-ui-polish).
//
// A pinned sliver declares its extent before laying out, so `extentOf` has to
// cover the banner's real composed height -- text lines, the gap and the
// progress bar -- at every text scale, in Latin and Fidel. Reserving a value
// derived from the type scale left it a pixel short on device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/widgets/category_banner.dart';
import 'package:elang/shared/models/skill_tree.dart';

const _latin = SkillCategory(
  id: 'c1',
  title: 'Foundations & Greetings',
  subtitle: 'the first steps',
);
const _fidel = SkillCategory(
  id: 'c2',
  title: 'Foundations & Greetings',
  subtitle: 'ሰላምታ እና ፈደል መግቢያ',
);
const _long = SkillCategory(
  id: 'c3',
  title: 'Colors, Body & Health and other very long category names',
  subtitle: 'ቀለሞች፣ አካል እና ጤና እና ሌሎች በጣም ረጅም የምድብ ስሞች እዚህ ይገኛሉ',
);
const _empty = SkillCategory(id: 'c4', title: 'Numbers & Time', subtitle: '');

/// Renders the banner inside exactly the height it asked for, the way the
/// pinned sliver does, and reports what it actually needed.
Future<({double reserved, double needed})> _measure(
  WidgetTester tester,
  SkillCategory category, {
  required double textScale,
  required double width,
}) async {
  late double reserved;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 900),
        textScaler: TextScaler.linear(textScale),
      ),
      // Inside a MaterialApp, as the dashboard renders it: `Text` merges the
      // ambient DefaultTextStyle before laying out, so a bare Directionality
      // would measure a different style than the app actually paints.
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              reserved = CategoryBanner.extentOf(context, category);
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: CategoryBanner(
                    category: category,
                    completed: 12,
                    total: 30,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  final needed = tester.getSize(find.byType(CategoryBanner)).height;
  return (reserved: reserved, needed: needed);
}

void main() {
  final categories = {
    'latin subtitle': _latin,
    'fidel subtitle': _fidel,
    'long fidel subtitle': _long,
    'empty subtitle': _empty,
  };

  for (final scale in [1.0, 1.1, 1.15, 1.3, 1.5, 2.0]) {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final entry in categories.entries) {
        testWidgets(
          'reserves enough for a ${entry.key} at ${scale}x on ${width}dp',
          (tester) async {
            final result = await _measure(
              tester,
              entry.value,
              textScale: scale,
              width: width,
            );

            expect(
              result.reserved,
              greaterThanOrEqualTo(result.needed),
              reason: 'reserved ${result.reserved} but the banner needed '
                  '${result.needed}',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('the reserved height is not wastefully larger than needed', (
    tester,
  ) async {
    final result = await _measure(
      tester,
      _fidel,
      textScale: 1.0,
      width: 360,
    );

    // Within a couple of pixels: exact enough that the banner is not padded
    // by accident, loose enough to survive rounding.
    expect(result.reserved - result.needed, lessThanOrEqualTo(2));
  });
  // The decisive test. A pinned sliver commits to a height before it lays
  // out, and the test font's metrics are not the device's, so no measurement
  // here can prove the prediction is exact on a real phone. Instead prove the
  // banner survives being given *less* than it asked for: that is the failure
  // mode, and it must not overflow.
  for (final short in [1.0, 2.0, 4.0, 8.0]) {
    for (final entry in {'fidel': _fidel, 'empty': _empty}.entries) {
      testWidgets(
        'a ${entry.key} subtitle survives ${short}px less than reserved',
        (tester) async {
          late double reserved;
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(size: Size(360, 900)),
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      reserved = CategoryBanner.extentOf(context, entry.value);
                      return Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: 360,
                          // Exactly how the pinned sliver sizes it, minus the
                          // shortfall a font-metric disagreement would cause.
                          height: reserved - short,
                          child: CategoryBanner(
                            category: entry.value,
                            completed: 12,
                            total: 30,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );

          expect(reserved, greaterThan(0));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

}
