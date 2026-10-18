import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'sound_chart.dart';

/// A saved copy and the `ETag` it came with.
class Saved<T> {
  const Saved(this.value, {this.etag});

  final T value;
  final String? etag;
}

/// The Sounds charts kept on the phone, so the tab opens at once and works
/// offline. Kept as an interface (mirrors `CourseCacheStore`) so widget
/// tests never touch the file system.
abstract class SoundChartStore {
  Future<Saved<List<SoundChartSummary>>?> loadIndex();
  Future<void> saveIndex(List<SoundChartSummary> charts, {String? etag});

  Future<Saved<SoundChart>?> loadChart(String language);
  Future<void> saveChart(SoundChart chart, {String? etag});
  Future<void> removeChart(String language);
}

/// The JSON each copy is stored as. An unreadable copy reads as none.
abstract class _JsonSoundChartStore implements SoundChartStore {
  Future<String?> read(String name);
  Future<void> write(String name, String? text);

  static const _index = 'index';
  static String _chart(String language) => 'chart_$language';

  @override
  Future<Saved<List<SoundChartSummary>>?> loadIndex() async {
    try {
      final text = await read(_index);
      if (text == null) return null;
      final json = jsonDecode(text) as Map<String, Object?>;
      return Saved([
        for (final c in json['charts']! as List) SoundChartSummary.fromJson(c),
      ], etag: json['etag'] as String?);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveIndex(List<SoundChartSummary> charts, {String? etag}) =>
      write(
        _index,
        jsonEncode({
          'etag': etag,
          'charts': [for (final c in charts) c.toJson()],
        }),
      );

  @override
  Future<Saved<SoundChart>?> loadChart(String language) async {
    try {
      final text = await read(_chart(language));
      if (text == null) return null;
      final json = jsonDecode(text) as Map<String, Object?>;
      return Saved(
        SoundChart.fromJson(json['chart']),
        etag: json['etag'] as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveChart(SoundChart chart, {String? etag}) => write(
    _chart(chart.language),
    jsonEncode({'etag': etag, 'chart': chart.toJson()}),
  );

  @override
  Future<void> removeChart(String language) => write(_chart(language), null);
}

/// [SoundChartStore] as files in the app's support folder, which the
/// phone's "Clear cache" leaves alone, so the tab still works offline after
/// it. The recordings themselves live in `MediaCache`.
class FileSoundChartStore extends _JsonSoundChartStore {
  FileSoundChartStore({Future<Directory> Function()? directory})
    : _directoryOf = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directoryOf;

  static Future<Directory> _defaultDirectory() async => Directory(
    '${(await getApplicationSupportDirectory()).path}/sound_charts',
  );

  Future<File> _file(String name) async =>
      File('${(await _directoryOf()).path}/$name.json');

  @override
  Future<String?> read(String name) async {
    try {
      final file = await _file(name);
      return await file.exists() ? await file.readAsString() : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String name, String? text) async {
    try {
      final file = await _file(name);
      if (text == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      await file.parent.create(recursive: true);
      // Written aside, then renamed: a write cut short never replaces a
      // good copy with half of one.
      final part = File('${file.path}.part');
      await part.writeAsString(text, flush: true);
      await part.rename(file.path);
    } on Object {
      // No saved copy only means the tab needs the network next time.
    }
  }
}

/// In memory, for tests. Keeps the encoded text, so it reads back through
/// the same JSON as the file store.
class InMemorySoundChartStore extends _JsonSoundChartStore {
  final Map<String, String> files = {};

  @override
  Future<String?> read(String name) async => files[name];

  @override
  Future<void> write(String name, String? text) async {
    if (text == null) {
      files.remove(name);
    } else {
      files[name] = text;
    }
  }
}
