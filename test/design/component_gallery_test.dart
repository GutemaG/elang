import 'package:elang/shared/gallery/component_gallery.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The gallery lays out every section at once (a Column, not a lazy list),
// so building it is enough to catch any component that overflows.
void main() {
  const sizes = [Size(360, 640), Size(430, 932)];
  const scales = [1.0, 1.3];

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('should lay out every component without overflow when '
          '${size.width.toInt()}×${size.height.toInt()} at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery.withClampedTextScaling(
              minScaleFactor: scale,
              maxScaleFactor: scale,
              child: const ComponentGallery(),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('AppButton'), findsOneWidget);
      });
    }
  }
}
