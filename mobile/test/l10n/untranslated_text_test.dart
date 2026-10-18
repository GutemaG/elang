// Keeps every word the app shows in the ARB files (024-app-localization,
// FR-2, story 007): a string literal with letters, passed where it is shown
// (`Text('…')`, `label: '…'`, `tooltip: '…'` and the like), fails here.
//
// The screens were moved onto the ARB files from a list of files still to
// do ([_notYetTranslated]), which only shrank: a listed file with nothing
// left fails too. It is empty now, and stays empty.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files still showing literal text, to be translated. Empty since bolt
/// 079: every screen reads its words from the ARB files.
const _notYetTranslated = <String>{};

/// Names, shown as they are in every language.
const _names = {'Buna'};

/// Not scanned: the generated localizations; the design gallery (a
/// developer's tool, never shown to learners); and the services, which draw
/// nothing: their exception messages go to logs, and their fakes stand in
/// for course content the server sends. The reminder's words, which a
/// service does show, are passed in from where they are translated.
bool _skipped(String path) =>
    path.startsWith('lib/l10n/') ||
    path.startsWith('lib/shared/gallery/') ||
    path == 'lib/gallery_main.dart' ||
    path.startsWith('lib/shared/services/') ||
    // A stand-in no route leads to any more; only tests build it.
    path == 'lib/shared/screens/home_placeholder_screen.dart';

/// Where text is shown: `Text(`, or a named argument a widget shows.
final _shownAt = RegExp(
  r'''(?:\bText\(\s*|\b(?:label|title|subtitle|tooltip|message|hint|hintText|labelText|helperText|semanticLabel|semanticsLabel|retryLabel|badgeLabel|description|eyebrow|ribbon)\s*:\s*)(['"])((?:\\.|(?!\1).)*)\1''',
);

/// Interpolations (`$count`, `${a.b}`), which are not words.
final _interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');

/// [source] without comments, so doc comments do not count.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join('\n');

/// The shown literals in [source] that have words in them.
List<String> literalTextIn(String source) => [
  for (final match in _shownAt.allMatches(_withoutComments(source)))
    if (!_names.contains(match[2]) &&
        RegExp('[A-Za-z]').hasMatch(match[2]!.replaceAll(_interpolation, '')))
      match[0]!.replaceAll(RegExp(r'\s+'), ' '),
];

Map<String, List<String>> _scan() {
  final found = <String, List<String>>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (_skipped(path)) continue;
    final text = literalTextIn(file.readAsStringSync());
    if (text.isNotEmpty) found[path] = text;
  }
  return found;
}

void main() {
  final found = _scan();

  test('no screen shows text that is not in the ARB files', () {
    final untranslated = [
      for (final MapEntry(key: path, value: text) in found.entries)
        if (!_notYetTranslated.contains(path))
          '$path\n    ${text.join('\n    ')}',
    ]..sort();
    expect(
      untranslated,
      isEmpty,
      reason:
          'Put these words in lib/l10n/app_en.arb (with am and om) and read '
          'them with context.l10n:\n${untranslated.join('\n')}',
    );
  });

  test('the not-yet-translated list only names files that still need it', () {
    final done = _notYetTranslated.where((p) => !found.containsKey(p)).toList()
      ..sort();
    expect(
      done,
      isEmpty,
      reason:
          'These are translated now (or gone); take them off the list in '
          'test/l10n/untranslated_text_test.dart:\n${done.join('\n')}',
    );
  });

  group('the scan itself', () {
    test('finds text where it is shown', () {
      expect(literalTextIn("Text('Practice')"), hasLength(1));
      expect(literalTextIn("Text(\n  'Practice',\n)"), hasLength(1));
      expect(literalTextIn("label: 'Continue',"), hasLength(1));
      expect(literalTextIn('tooltip: "Close",'), hasLength(1));
      expect(literalTextIn(r"title: '$count skills',"), hasLength(1));
    });

    test('ignores what is not words, comments and keys', () {
      expect(literalTextIn(r"Text('$count')"), isEmpty);
      expect(literalTextIn(r"Text('${a.b} / 5')"), isEmpty);
      expect(literalTextIn("Text(context.l10n.close)"), isEmpty);
      expect(literalTextIn("// Text('Practice')"), isEmpty);
      expect(literalTextIn("/// label: 'Continue'"), isEmpty);
      expect(literalTextIn("ValueKey('settings-appearance')"), isEmpty);
      expect(literalTextIn("Text('·')"), isEmpty);
      expect(literalTextIn("Text('Buna')"), isEmpty);
    });
  });
}
