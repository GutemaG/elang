// In-memory stand-in for [MediaCache], used by widget tests so fetching
// clips and pictures ahead can be checked without the file system or the
// network (bolt 057).
//
// Mocking here is at the plugin boundary only, per `coding-standards.md`'s
// "mock at the network/DB boundary only" testing convention.

import 'dart:async';
import 'dart:io';

import 'package:elang/shared/services/media_cache.dart';

class FakeMediaCache implements MediaCache {
  /// Each [warm] call's addresses, in order.
  final List<List<String>> warmed = [];

  /// Every address [fileFor] was asked for, in order.
  final List<String> asked = [];

  /// Where each address is saved. [fileFor] fails for any other.
  final Map<String, String> files = {};

  /// An address listed here is still downloading until its completer
  /// completes.
  final Map<String, Completer<void>> holds = {};

  @override
  Future<File> fileFor(String url) async {
    asked.add(url);
    final hold = holds[url];
    if (hold != null) await hold.future;
    final path = files[url];
    if (path == null) throw MediaCacheException('$url could not be saved');
    return File(path);
  }

  @override
  void warm(Iterable<String> urls) => warmed.add(urls.toList());
}
