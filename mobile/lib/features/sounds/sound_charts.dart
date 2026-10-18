import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../shared/services/media_cache.dart';
import 'sound_chart.dart';
import 'sound_chart_api.dart';
import 'sound_chart_store.dart';

/// Which languages have a Sounds chart, and each chart, saved on the phone
/// first and brought up to date from the server.
///
/// Everything is kept: the list of charts and each chart opened (with
/// their `ETag`s, so an unchanged one is never downloaded again), and the
/// recordings in [MediaCache], fetched ahead when a chart arrives. So the
/// tab opens at once, plays at once, and works offline once seen.
///
/// Notifies when the list of charts changes, which is what shows or hides
/// the Sounds tab.
class SoundCharts extends ChangeNotifier {
  SoundCharts({SoundChartApi? api, SoundChartStore? store, this.mediaCache})
    : _api = api ?? HttpSoundChartApi(),
      _store = store ?? FileSoundChartStore();

  final SoundChartApi _api;
  final SoundChartStore _store;
  final MediaCache? mediaCache;

  List<SoundChartSummary> _charts = const [];
  String? _indexTag;
  bool _loaded = false;
  Future<void>? _refreshing;
  final Map<String, Future<SoundChart?>> _fetching = {};

  /// The charts learners can open, as last known.
  List<SoundChartSummary> get charts => _charts;

  SoundChartSummary? summaryOf(String? language) {
    for (final chart in _charts) {
      if (chart.language == language) return chart;
    }
    return null;
  }

  bool has(String? language) => summaryOf(language) != null;

  /// The saved list first, so the tab shows offline, then the server's.
  /// Never throws.
  Future<void> load() async {
    if (!_loaded) {
      _loaded = true;
      final saved = await _store.loadIndex();
      if (saved != null) {
        _charts = saved.value;
        _indexTag = saved.etag;
        notifyListeners();
      }
    }
    await refresh();
  }

  /// Asks the server for the list. Offline, the saved one stays. Two calls
  /// at once share one request. Never throws.
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    try {
      final fetched = await _api.index(etag: _indexTag);
      if (fetched.notModified) return;
      final charts = fetched.value ?? const <SoundChartSummary>[];
      _charts = charts;
      _indexTag = fetched.etag;
      await _store.saveIndex(charts, etag: fetched.etag);
      notifyListeners();
    } on Object catch (e) {
      debugPrint('SoundCharts: could not refresh the list: $e');
    }
  }

  /// The saved copy of [language]'s chart, if any.
  Future<SoundChart?> saved(String language) async =>
      (await _store.loadChart(language))?.value;

  /// [language]'s chart, current: the saved copy when its version is the
  /// one the list names, else a download (or "not modified" when the saved
  /// copy's `ETag` still matches). Offline, the saved copy, however old.
  /// `null` when there is none at all; throws only when offline with no
  /// copy. Fetching it also fetches its recordings ahead.
  Future<SoundChart?> chart(String language) {
    final pending = _fetching[language];
    if (pending != null) return pending;
    // A block, not an arrow: `remove` returns this very future, and
    // `whenComplete` would wait for it.
    final future = _chart(language).whenComplete(() {
      _fetching.remove(language);
    });
    return _fetching[language] = future;
  }

  Future<SoundChart?> _chart(String language) async {
    final saved = await _store.loadChart(language);
    final summary = summaryOf(language);
    if (saved != null &&
        summary != null &&
        saved.value.version == summary.version) {
      _warm(saved.value);
      return saved.value;
    }
    try {
      final fetched = await _api.chart(language, etag: saved?.etag);
      final chart = fetched.notModified ? saved?.value : fetched.value;
      if (chart != null && !fetched.notModified) {
        await _store.saveChart(chart, etag: fetched.etag);
      }
      if (chart != null) _warm(chart);
      return chart;
    } on SoundChartApiException catch (e) {
      if (e.notFound) {
        // Turned off or removed since the list was fetched.
        await _store.removeChart(language);
        unawaited(refresh());
        return null;
      }
      if (saved != null) return saved.value;
      rethrow;
    }
  }

  void _warm(SoundChart chart) => mediaCache?.warm(chart.audioUrls);
}
