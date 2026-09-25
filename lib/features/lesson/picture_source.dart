import 'package:flutter/widgets.dart';

/// Where a picture question's picture is loaded from, by the shape of its
/// address (019-image-choice-exercise-types).
///
/// - An `assets/...` path is bundled with the app: the fake API's
///   questions use these, so they show without a backend.
/// - Anything else is an http or https address: an uploaded picture on R2,
///   or a local backend's `/media/...` path, already resolved against the
///   API by `HttpLessonApi`.
///
/// Bolt 054 adds downloaded pictures, which are files on the device.
ImageProvider pictureImageFor(String source) {
  if (source.startsWith('assets/')) return AssetImage(source);
  return NetworkImage(source);
}
