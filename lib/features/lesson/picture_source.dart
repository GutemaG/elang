import 'dart:io';

import 'package:flutter/widgets.dart';

/// Where a picture question's picture is loaded from, by the shape of its
/// address (019-image-choice-exercise-types).
///
/// - An `http://` or `https://` address is on the network: an uploaded
///   picture on R2, or a local backend's `/media/...` path, already
///   resolved against the API by `HttpLessonApi`.
/// - An `assets/...` path is bundled with the app: the fake API's
///   questions use these, so they show without a backend.
/// - Anything else is a file on the device: a downloaded lesson's picture,
///   saved by `LessonPackDownloader` (bolt 054).
ImageProvider pictureImageFor(String source) {
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return NetworkImage(source);
  }
  if (source.startsWith('assets/')) return AssetImage(source);
  return FileImage(File(source));
}
