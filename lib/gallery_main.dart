import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'shared/gallery/component_gallery.dart';

/// Entry point for the debug-only component gallery:
///
///     flutter run -t lib/gallery_main.dart
///
/// The app's `main.dart` never imports the gallery, so it is not part of any
/// app build; this refuses to start in anything but a debug build as well.
void main() {
  if (!kDebugMode) {
    throw StateError('The component gallery runs in debug builds only.');
  }
  runApp(const ComponentGalleryApp());
}
