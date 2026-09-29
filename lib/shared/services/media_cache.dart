import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Clips and pictures kept on the device after their first download, so a
/// question's audio starts at once and its pictures show without waiting
/// (bolt 057).
///
/// Separate from downloaded lessons (`LessonPackDownloader`): those keep
/// their own folder and are never removed behind the learner's back. This
/// is a cache -- a file it drops, or the phone clears, is simply downloaded
/// again the next time it is needed.
///
/// Kept as an interface (mirrors `LessonPackStore`) so widget tests never
/// touch the file system or the network.
abstract class MediaCache {
  /// The saved file for [url], downloading it first when it is not saved
  /// yet. Two calls for the same address share one download. Throws when
  /// it cannot be downloaded.
  Future<File> fileFor(String url);

  /// Starts downloading every web address in [urls] that is not saved yet,
  /// in order, ahead of anything warmed earlier. Nothing waits on it and a
  /// failure is dropped: the question asks for the file again when shown.
  void warm(Iterable<String> urls);
}

/// Whether [source] is on the network, rather than a bundled `assets/`
/// path or a file on the device.
bool isWebAddress(String source) =>
    source.startsWith('http://') || source.startsWith('https://');

/// The extension of [url]'s last path segment, such as `.webp`; a query
/// string never ends up in a file name. Empty when there is none: the app
/// reads clips and pictures by their content, not their name.
String extensionOfUrl(String url) {
  final segments = Uri.parse(url).pathSegments;
  final last = segments.isEmpty ? '' : segments.last;
  final dot = last.lastIndexOf('.');
  return dot <= 0 ? '' : last.substring(dot);
}

/// The cached file's name for [url]: the SHA-1 of the whole address, so a
/// changed `?v=` is a different file, plus the address's extension.
@visibleForTesting
String cacheFileName(String url) =>
    '${sha1.convert(utf8.encode(url))}${extensionOfUrl(url)}';

/// [MediaCache] in the app's cache folder, which the phone's "Clear cache"
/// empties.
///
/// Holds at most [maxBytes]. After each download the files used longest ago
/// are removed first, never the one just saved. A file's modified time is
/// its last use -- set on every hit -- so the order survives a restart.
class DiskMediaCache implements MediaCache {
  DiskMediaCache({
    http.Client? httpClient,
    Future<Directory> Function()? directory,
    this.maxBytes = defaultMaxBytes,
  }) : _httpClient = httpClient ?? http.Client(),
       _directoryOf = directory ?? _defaultDirectory;

  /// 500 MB across every course (the user's choice, 2026-09-29): roughly
  /// 500-1000 lessons' clips and pictures.
  static const defaultMaxBytes = 500 * 1024 * 1024;

  /// Downloads [warm] runs at once.
  static const _parallel = 3;

  final int maxBytes;
  final http.Client _httpClient;
  final Future<Directory> Function() _directoryOf;

  Future<_Index>? _index;
  final Map<String, Future<File>> _inFlight = {};
  List<String> _queue = [];
  int _running = 0;

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationCacheDirectory()).path}/media_cache');

  @override
  Future<File> fileFor(String url) {
    final pending = _inFlight[url];
    if (pending != null) return pending;
    final future = _fetch(url);
    _inFlight[url] = future;
    future.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_inFlight[url], future)) _inFlight.remove(url);
    });
    return future;
  }

  @override
  void warm(Iterable<String> urls) {
    final batch = <String>[
      for (final url in urls.toSet())
        if (isWebAddress(url)) url,
    ];
    if (batch.isEmpty) return;
    final inBatch = batch.toSet();
    _queue = [...batch, ..._queue.where((url) => !inBatch.contains(url))];
    _pump();
  }

  void _pump() {
    while (_running < _parallel && _queue.isNotEmpty) {
      final url = _queue.removeAt(0);
      _running++;
      fileFor(url)
          .then<void>(
            (_) {},
            onError: (Object e) =>
                debugPrint('MediaCache: could not fetch $url ahead: $e'),
          )
          .whenComplete(() {
            _running--;
            _pump();
          });
    }
  }

  Future<File> _fetch(String url) async {
    final index = await (_index ??= _open());
    final name = cacheFileName(url);
    final file = File('${index.directory.path}/$name');
    if (index.sizes.containsKey(name)) {
      if (await file.exists()) {
        index.used(name, DateTime.now());
        unawaited(_markUsed(file));
        return file;
      }
      // Cleared by the phone while the app was running.
      index.remove(name);
    }

    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw MediaCacheException(
        'Failed to download $url: HTTP ${response.statusCode}',
      );
    }
    await index.directory.create(recursive: true);
    // Written aside, then renamed: a download cut short is never taken for
    // a whole file.
    final part = File('${file.path}.part');
    try {
      await part.writeAsBytes(response.bodyBytes, flush: true);
      await part.rename(file.path);
    } on Object {
      try {
        if (await part.exists()) await part.delete();
      } on Object {
        // Best effort: removed when the cache next opens.
      }
      rethrow;
    }
    index.add(name, response.bodyBytes.length, DateTime.now());
    await _evict(index, keep: name);
    return file;
  }

  Future<_Index> _open() async {
    final directory = await _directoryOf();
    final index = _Index(directory);
    if (!await directory.exists()) return index;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      try {
        if (name.endsWith('.part')) {
          await entity.delete();
          continue;
        }
        final stat = await entity.stat();
        index.add(name, stat.size, stat.modified);
      } on Object {
        // A file that can't be read is left for the phone to clear.
      }
    }
    return index;
  }

  Future<void> _evict(_Index index, {required String keep}) async {
    if (index.total <= maxBytes) return;
    final oldestFirst = index.lastUsed.keys.where((n) => n != keep).toList()
      ..sort((a, b) => index.lastUsed[a]!.compareTo(index.lastUsed[b]!));
    for (final name in oldestFirst) {
      if (index.total <= maxBytes) break;
      index.remove(name);
      try {
        final file = File('${index.directory.path}/$name');
        if (await file.exists()) await file.delete();
      } on Object {
        // Out of the index either way; the phone can clear what is left.
      }
    }
  }

  static Future<void> _markUsed(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } on Object {
      // Only the eviction order suffers.
    }
  }
}

/// What the cache folder holds: each file's size and last use.
class _Index {
  _Index(this.directory);

  final Directory directory;
  final Map<String, int> sizes = {};
  final Map<String, DateTime> lastUsed = {};
  int total = 0;

  void add(String name, int size, DateTime when) {
    remove(name);
    sizes[name] = size;
    lastUsed[name] = when;
    total += size;
  }

  void used(String name, DateTime when) => lastUsed[name] = when;

  void remove(String name) {
    final size = sizes.remove(name);
    lastUsed.remove(name);
    if (size != null) total -= size;
  }
}

class MediaCacheException implements Exception {
  const MediaCacheException(this.message);

  final String message;

  @override
  String toString() => 'MediaCacheException: $message';
}
