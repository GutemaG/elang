// Sounds charts and fakes shared by the Sounds tests.

import 'package:elang/features/sounds/sound_chart.dart';
import 'package:elang/features/sounds/sound_chart_api.dart';
import 'package:elang/features/sounds/sound_player.dart';

const clip = 'https://pub.example/am/sounds';

/// Two rows of a small Fidel (ሀ ሁ ሂ, then ሐ ሑ ሒ, which sound like the
/// first row), and a labialised group of one.
Map<String, Object?> fidelJson({int version = 3}) => {
  'language': 'am',
  'title': {'en': 'Fidel', 'am': 'ፊደል'},
  'version': version,
  'updated_at': '2026-10-04T09:00:00Z',
  'groups': [
    {
      'key': 'fidel',
      'names': {'en': 'Fidel', 'am': 'ፊደል'},
      'columns': 3,
      'column_labels': ['e', 'u', 'i'],
      'letters': [
        _letter('ha', 'ሀ', 'he', example: true),
        _letter('hu', 'ሁ', 'hu'),
        _letter('hi', 'ሂ', 'hi'),
        _letter('hha', 'ሐ', 'he', sameAs: 'ሀ', audio: 'ha'),
        _letter('hhu', 'ሑ', 'hu', sameAs: 'ሁ', audio: 'hu'),
        _letter('hhi', 'ሒ', 'hi', sameAs: 'ሂ', audio: 'hi'),
      ],
    },
    {
      'key': 'labialised',
      'names': {'en': 'Labialised', 'am': 'ዲቃላ'},
      'columns': null,
      'column_labels': <String>[],
      'letters': [_letter('lwa', 'ሏ', 'lwa', hint: 'A w after the l')],
    },
  ],
  'credits': ['Selam'],
};

/// A small Qubee: A to Z with its vowels marked, and a letter pair.
Map<String, Object?> qubeeJson() => {
  'language': 'om',
  'title': {'en': 'Qubee'},
  'version': 2,
  'updated_at': '2026-10-05T09:00:00Z',
  'groups': [
    {
      'key': 'alphabet',
      'names': {'en': 'A–Z'},
      'columns': null,
      'column_labels': <String>[],
      'letters': [
        _letter('a', 'A a', 'a', kind: 'vowel'),
        _letter('b', 'B b', 'b', kind: 'consonant'),
        _letter('c', 'C c', "ch'", kind: 'consonant'),
      ],
    },
    {
      'key': 'pairs',
      'names': {'en': 'Letter pairs'},
      'columns': null,
      'column_labels': <String>[],
      'letters': [_letter('ch', 'Ch ch', 'ch', kind: 'consonant')],
    },
  ],
  'credits': <String>[],
};

Map<String, Object?> _letter(
  String id,
  String glyph,
  String romanization, {
  String? sameAs,
  String? audio,
  String? hint,
  String? kind,
  bool example = false,
}) => {
  'id': id,
  'glyph': glyph,
  'romanization': romanization,
  'kind': ?kind,
  'hint': {'en': ?hint},
  'audio_url': '$clip/${audio ?? id}.m4a',
  'same_as': sameAs,
  'example': example
      ? {
          'word': 'ሀገር',
          'romanization': 'hager',
          'meaning': {'en': 'country', 'am': 'አገር'},
          'audio_url': '$clip/hager.m4a',
        }
      : null,
};

SoundChart fidel({int version = 3}) =>
    SoundChart.fromJson(fidelJson(version: version));

SoundChartSummary summary({String language = 'am', int version = 3}) =>
    SoundChartSummary(
      language: language,
      title: const {'en': 'Fidel'},
      version: version,
      letterCount: 7,
      icon: 'ሀ',
    );

/// A [SoundChartApi] answering from fields, recording each request.
class FakeSoundChartApi implements SoundChartApi {
  List<SoundChartSummary>? charts = [summary()];
  final Map<String, SoundChart> byLanguage = {'am': fidel()};

  /// Every request as `index etag` or `chart am etag`.
  final List<String> asked = [];
  bool offline = false;

  @override
  Future<Fetched<List<SoundChartSummary>>> index({String? etag}) async {
    asked.add('index $etag');
    if (offline) throw const SoundChartApiException('offline');
    final tag = '"i-${charts!.map((c) => '${c.language}${c.version}').join()}"';
    if (etag == tag) return Fetched.notModified(etag: tag);
    return Fetched(charts, etag: tag);
  }

  @override
  Future<Fetched<SoundChart>> chart(String language, {String? etag}) async {
    asked.add('chart $language $etag');
    if (offline) throw const SoundChartApiException('offline');
    final chart = byLanguage[language];
    if (chart == null) {
      throw const SoundChartApiException('gone', notFound: true);
    }
    final tag = '"$language-${chart.version}"';
    if (etag == tag) return Fetched.notModified(etag: tag);
    return Fetched(chart, etag: tag);
  }
}

/// A [SoundPlayer] recording what it was asked to play.
class FakeSoundPlayer implements SoundPlayer {
  final List<String> played = [];
  int stops = 0;
  bool fails = false;

  @override
  Future<void> play(String url, {bool slow = false}) async {
    if (fails) throw Exception('no audio');
    played.add(slow ? 'slow $url' : url);
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async {}
}
