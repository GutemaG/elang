import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/config/auth_config.dart';
import 'sound_chart.dart';

/// A response that may be "nothing new": with the `ETag` of the copy the
/// phone holds, the server answers `304 Not Modified` and sends no body.
class Fetched<T> {
  const Fetched(this.value, {this.etag}) : notModified = false;

  const Fetched.notModified({this.etag}) : value = null, notModified = true;

  /// The new copy; `null` when [notModified].
  final T? value;

  /// What to send as `If-None-Match` next time.
  final String? etag;
  final bool notModified;
}

class SoundChartApiException implements Exception {
  const SoundChartApiException(this.message, {this.notFound = false});

  final String message;

  /// The chart is gone, or turned off: forget the saved copy.
  final bool notFound;

  @override
  String toString() => 'SoundChartApiException: $message';
}

/// The Sounds tab's two reads. Kept as an interface so widget tests never
/// reach the network.
abstract class SoundChartApi {
  /// The charts learners can open.
  Future<Fetched<List<SoundChartSummary>>> index({String? etag});

  /// One language's chart.
  Future<Fetched<SoundChart>> chart(String language, {String? etag});
}

/// [SoundChartApi] over HTTP: `GET /api/v1/sound-charts[/{language}]`. No
/// sign-in; the server sends an `ETag` and the app sends it back, so an
/// unchanged chart costs one small request and no download.
class HttpSoundChartApi implements SoundChartApi {
  HttpSoundChartApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<http.Response> _get(String path, String? etag) async {
    try {
      return await _client
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: {'Accept': 'application/json', 'If-None-Match': ?etag},
          )
          .timeout(AuthConfig.requestTimeout);
    } on Object catch (e) {
      throw SoundChartApiException('Could not reach the server: $e');
    }
  }

  T _decode<T>(http.Response response, T Function(Object?) read) {
    try {
      return read(jsonDecode(utf8.decode(response.bodyBytes)));
    } on Object catch (e) {
      throw SoundChartApiException('Unreadable sound chart: $e');
    }
  }

  @override
  Future<Fetched<List<SoundChartSummary>>> index({String? etag}) async {
    final response = await _get('/api/v1/sound-charts', etag);
    final tag = response.headers['etag'];
    if (response.statusCode == 304) {
      return Fetched.notModified(etag: tag ?? etag);
    }
    if (response.statusCode != 200) {
      throw SoundChartApiException('HTTP ${response.statusCode}');
    }
    return Fetched(
      _decode(response, (json) {
        final charts = (json! as Map<String, Object?>)['charts']! as List;
        return [for (final c in charts) SoundChartSummary.fromJson(c)];
      }),
      etag: tag,
    );
  }

  @override
  Future<Fetched<SoundChart>> chart(String language, {String? etag}) async {
    final response = await _get('/api/v1/sound-charts/$language', etag);
    final tag = response.headers['etag'];
    if (response.statusCode == 304) {
      return Fetched.notModified(etag: tag ?? etag);
    }
    if (response.statusCode == 404) {
      throw const SoundChartApiException('No such chart', notFound: true);
    }
    if (response.statusCode != 200) {
      throw SoundChartApiException('HTTP ${response.statusCode}');
    }
    // A local backend serves recordings at `/media/...` on itself.
    return Fetched(
      _decode(response, SoundChart.fromJson).resolvedAgainst(_baseUrl),
      etag: tag,
    );
  }
}
