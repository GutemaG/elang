// The arithmetic behind every pinned extent (011-dashboard-ui-polish).
//
// A pinned sliver declares its height before it lays out, so `scaledLineHeight`
// has to agree with what `Text` actually renders. When it under-measures by
// even a fraction, the banner overflows its reserved space -- which is exactly
// what happened on device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/widgets/pinned_header_sliver.dart';
import 'package:elang/shared/theme/app_typography.dart';

/// Renders [text] in [style] and reports the height `Text` really took.
Future<double> _renderedHeight(
  WidgetTester tester,
  String text,
  TextStyle style, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    ),
  );
  return tester.getSize(find.text(text)).height;
}

/// The same context the widgets use, so the helper sees the real text scale.
Future<double> _reported(
  WidgetTester tester,
  TextStyle style, {
  double textScale = 1.0,
  int lines = 1,
}) async {
  late double value;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Builder(
        builder: (context) {
          value = scaledLineHeight(context, style, lines: lines);
          return const SizedBox();
        },
      ),
    ),
  );
  return value;
}

void main() {
  const styles = <String, TextStyle>{
    'labelLg': AppTypography.labelLg,
    'labelMd': AppTypography.labelMd,
    'labelSm': AppTypography.labelSm,
    'bodySm': AppTypography.bodySm,
  };

  for (final scale in [1.0, 1.15, 1.3, 1.5]) {
    for (final entry in styles.entries) {
      testWidgets(
        'scaledLineHeight covers a rendered ${entry.key} line at ${scale}x',
        (tester) async {
          final reported = await _reported(
            tester,
            entry.value,
            textScale: scale,
          );
          // Latin and Fidel: a line box is set by the style's height
          // multiplier, and both must fit inside what was reserved.
          for (final probe in ['Numbers & Time', 'ቁጥሮች እና ጊዜ']) {
            final rendered = await _renderedHeight(
              tester,
              probe,
              entry.value,
              textScale: scale,
            );
            expect(
              reported,
              greaterThanOrEqualTo(rendered),
              reason: '${entry.key} at ${scale}x, "$probe": reserved '
                  '$reported but rendered $rendered',
            );
          }
        },
      );
    }
  }

  testWidgets('a reserved height is a whole number of pixels', (tester) async {
    // Sub-pixel arithmetic is what produced a 1px overflow on device.
    final value = await _reported(tester, AppTypography.labelLg, textScale: 1.15);

    expect(value, value.roundToDouble());
  });

  testWidgets('several lines cost exactly as much as one line each', (
    tester,
  ) async {
    final one = await _reported(tester, AppTypography.bodySm);
    final three = await _reported(tester, AppTypography.bodySm, lines: 3);

    expect(three, one * 3);
  });
}
