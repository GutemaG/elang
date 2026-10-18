// The Sounds tab's data: a language's letters and where each one's sound
// plays from, as `GET /api/v1/sound-charts/{language}` sends it
// (backend/app/infrastructure/api/sound_schemas.py).
//
// Each model reads the server's JSON and writes the same shape back, so a
// chart saved on the phone reads exactly like one just downloaded.

/// Text in several app languages: `en` always, `am` and `om` when
/// translated.
typedef Localized = Map<String, String>;

/// [text] in the app language [code], else English, else whatever there is.
String inLanguage(Localized text, String code) =>
    text[code] ?? text['en'] ?? (text.isEmpty ? '' : text.values.first);

Localized _localized(Object? raw) => {
  if (raw is Map)
    for (final MapEntry(:key, :value) in raw.entries)
      if (key is String && value is String) key: value,
};

String _string(Object? raw) => raw is String
    ? raw
    : throw const FormatException('expected text in a sound chart');

int _int(Object? raw) => raw is int
    ? raw
    : throw const FormatException('expected a number in a sound chart');

List<Object?> _list(Object? raw) => raw is List
    ? raw
    : throw const FormatException('expected a list in a sound chart');

Map<String, Object?> _map(Object? raw) => raw is Map<String, Object?>
    ? raw
    : throw const FormatException('expected an object in a sound chart');

/// One chart learners can open, from `GET /api/v1/sound-charts`.
class SoundChartSummary {
  const SoundChartSummary({
    required this.language,
    required this.title,
    required this.version,
    required this.letterCount,
    required this.icon,
  });

  factory SoundChartSummary.fromJson(Object? raw) {
    final json = _map(raw);
    return SoundChartSummary(
      language: _string(json['language']),
      title: _localized(json['title']),
      version: _int(json['version']),
      letterCount: _int(json['letter_count']),
      icon: json['icon'] is String ? json['icon']! as String : '',
    );
  }

  final String language;
  final Localized title;

  /// Goes up on every change, so a saved chart with the same number is
  /// current and needs no download.
  final int version;
  final int letterCount;

  /// What the Sounds tab shows for this language: its first letter, such
  /// as ሀ, or "Aa" for a Latin script.
  final String icon;

  Map<String, Object?> toJson() => {
    'language': language,
    'title': title,
    'version': version,
    'letter_count': letterCount,
    'icon': icon,
  };
}

class SoundExample {
  const SoundExample({
    required this.word,
    this.romanization,
    this.meaning = const {},
    this.audioUrl,
  });

  factory SoundExample.fromJson(Object? raw) {
    final json = _map(raw);
    return SoundExample(
      word: _string(json['word']),
      romanization: json['romanization'] as String?,
      meaning: _localized(json['meaning']),
      audioUrl: json['audio_url'] as String?,
    );
  }

  final String word;
  final String? romanization;
  final Localized meaning;
  final String? audioUrl;

  Map<String, Object?> toJson() => {
    'word': word,
    'romanization': romanization,
    'meaning': meaning,
    'audio_url': audioUrl,
  };
}

class SoundLetter {
  const SoundLetter({
    required this.id,
    required this.glyph,
    required this.romanization,
    this.kind,
    this.hint = const {},
    this.audioUrl,
    this.sameAs,
    this.example,
  });

  factory SoundLetter.fromJson(Object? raw) {
    final json = _map(raw);
    return SoundLetter(
      id: _string(json['id']),
      glyph: _string(json['glyph']),
      romanization: _string(json['romanization']),
      kind: json['kind'] as String?,
      hint: _localized(json['hint']),
      audioUrl: json['audio_url'] as String?,
      sameAs: json['same_as'] as String?,
      example: json['example'] == null
          ? null
          : SoundExample.fromJson(json['example']),
    );
  }

  final String id;
  final String glyph;
  final String romanization;

  /// `vowel`, `consonant`, or null when the chart does not say (the
  /// Fidel's letters are both at once).
  final String? kind;

  bool get isVowel => kind == 'vowel';
  bool get isConsonant => kind == 'consonant';

  /// A tip for a sound English has not got, by app language.
  final Localized hint;

  /// What plays: its own recording, or the one of the letter it sounds
  /// the same as.
  final String? audioUrl;

  /// The glyph of the letter it sounds the same as, such as ሀ for ሐ.
  final String? sameAs;
  final SoundExample? example;

  SoundLetter withUrls(String Function(String) resolve) => SoundLetter(
    id: id,
    glyph: glyph,
    romanization: romanization,
    kind: kind,
    hint: hint,
    audioUrl: audioUrl == null ? null : resolve(audioUrl!),
    sameAs: sameAs,
    example: example == null
        ? null
        : SoundExample(
            word: example!.word,
            romanization: example!.romanization,
            meaning: example!.meaning,
            audioUrl: example!.audioUrl == null
                ? null
                : resolve(example!.audioUrl!),
          ),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'glyph': glyph,
    'romanization': romanization,
    'kind': kind,
    'hint': hint,
    'audio_url': audioUrl,
    'same_as': sameAs,
    'example': example?.toJson(),
  };
}

class SoundGroup {
  const SoundGroup({
    required this.key,
    required this.names,
    required this.letters,
    this.columns,
    this.columnLabels = const [],
  });

  factory SoundGroup.fromJson(Object? raw) {
    final json = _map(raw);
    return SoundGroup(
      key: _string(json['key']),
      names: _localized(json['names']),
      columns: json['columns'] as int?,
      columnLabels: [
        for (final label in _list(json['column_labels'] ?? const []))
          if (label is String) label,
      ],
      letters: [
        for (final letter in _list(json['letters']))
          SoundLetter.fromJson(letter),
      ],
    );
  }

  final String key;
  final Localized names;

  /// Set for a grid such as the Fidel's: that many letters to a row, under
  /// [columnLabels] (the seven vowel orders).
  final int? columns;
  final List<String> columnLabels;
  final List<SoundLetter> letters;

  /// The grid's rows; one row of everything for a group with no columns.
  List<List<SoundLetter>> get rows {
    final size = columns ?? letters.length;
    if (size <= 0) return const [];
    return [
      for (var i = 0; i < letters.length; i += size)
        letters.sublist(
          i,
          i + size > letters.length ? letters.length : i + size,
        ),
    ];
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'names': names,
    'columns': columns,
    'column_labels': columnLabels,
    'letters': [for (final letter in letters) letter.toJson()],
  };
}

class SoundChart {
  const SoundChart({
    required this.language,
    required this.title,
    required this.version,
    required this.groups,
    this.credits = const [],
  });

  factory SoundChart.fromJson(Object? raw) {
    final json = _map(raw);
    return SoundChart(
      language: _string(json['language']),
      title: _localized(json['title']),
      version: _int(json['version']),
      groups: [
        for (final group in _list(json['groups'])) SoundGroup.fromJson(group),
      ],
      credits: [
        for (final name in _list(json['credits'] ?? const []))
          if (name is String) name,
      ],
    );
  }

  final String language;
  final Localized title;
  final int version;
  final List<SoundGroup> groups;

  /// The speakers who recorded it.
  final List<String> credits;

  Iterable<SoundLetter> get letters => groups.expand((g) => g.letters);

  /// Every address a sound plays from, for fetching ahead.
  Set<String> get audioUrls => {
    for (final letter in letters) ...[
      ?letter.audioUrl,
      ?letter.example?.audioUrl,
    ],
  };

  /// The same chart with every relative address (a local backend's
  /// `/media/...`) made absolute against [base].
  SoundChart resolvedAgainst(String base) {
    final root = Uri.parse(base);
    String resolve(String url) => root.resolve(url).toString();
    return SoundChart(
      language: language,
      title: title,
      version: version,
      credits: credits,
      groups: [
        for (final g in groups)
          SoundGroup(
            key: g.key,
            names: g.names,
            columns: g.columns,
            columnLabels: g.columnLabels,
            letters: [for (final x in g.letters) x.withUrls(resolve)],
          ),
      ],
    );
  }

  Map<String, Object?> toJson() => {
    'language': language,
    'title': title,
    'version': version,
    'groups': [for (final group in groups) group.toJson()],
    'credits': credits,
  };
}
