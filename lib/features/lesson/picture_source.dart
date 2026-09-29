import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../shared/services/media_cache.dart';

/// Where a picture question's picture is loaded from, by the shape of its
/// address (019-image-choice-exercise-types).
///
/// - An `http://` or `https://` address is on the network: an uploaded
///   picture on R2, or a local backend's `/media/...` path, already
///   resolved against the API by `HttpLessonApi`. With a [cache] it is
///   read from the device once saved there (bolt 057).
/// - An `assets/...` path is bundled with the app: the fake API's
///   questions use these, so they show without a backend.
/// - Anything else is a file on the device: a downloaded lesson's picture,
///   saved by `LessonPackDownloader` (bolt 054).
ImageProvider pictureImageFor(String source, {MediaCache? cache}) {
  if (isWebAddress(source)) {
    return cache == null ? NetworkImage(source) : CachedPicture(source, cache);
  }
  if (source.startsWith('assets/')) return AssetImage(source);
  return FileImage(File(source));
}

/// A web picture read from its file in [MediaCache], downloading it there
/// first when it is not saved yet (bolt 057).
///
/// Equal for the same address and cache, so Flutter's image cache shares
/// one decode between the early load and the tile.
@immutable
class CachedPicture extends ImageProvider<CachedPicture> {
  const CachedPicture(this.url, this.cache);

  final String url;
  final MediaCache cache;

  @override
  Future<CachedPicture> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CachedPicture>(this);

  @override
  ImageStreamCompleter loadImage(
    CachedPicture key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: url,
    informationCollector: () => [DiagnosticsProperty('Picture', url)],
  );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final file = await cache.fileFor(url);
    final bytes = await file.readAsBytes();
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is CachedPicture &&
      other.url == url &&
      identical(other.cache, cache);

  @override
  int get hashCode => Object.hash(url, identityHashCode(cache));

  @override
  String toString() => '${objectRuntimeType(this, 'CachedPicture')}("$url")';
}
