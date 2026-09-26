// Keeps every screen on the shared design library (018-mobile-design-system,
// NFR-1). Colours, shadows, radii, borders, buttons, sheets, page scaffolds
// and progress indicators may only be drawn in `lib/shared/`, where the
// tokens and components live; a screen that draws its own fails here.
//
// Screens that have not moved onto the library yet are listed in
// [_notYetMigrated] with the exact rules they still break. The list only
// ever shrinks: a file off the list, or a rule not listed for its file,
// fails; so does an entry that no longer matches anything.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

enum _Rule {
  colourLiteral(r'Color\(0x', 'a Color(0x…) literal: use an AppColors token'),
  boxShadow(r'\bBoxShadow\(', 'a hand-built BoxShadow: use AppShadows'),
  radiusOrBorder(
    r'\bBorderRadius\.circular\(|\bBorder\.all\(',
    'a hand-built radius or border: use a shared component',
  ),
  materialButton(
    r'\b(TextButton|ElevatedButton|FilledButton|OutlinedButton|IconButton)(\.\w+)?\(',
    'a Material button: use AppButton or AppIconButton',
  ),
  rawSheetOrDialog(
    r'\b(showModalBottomSheet|showDialog)\b',
    'a raw sheet or dialog: use the shared sheet and dialog',
  ),
  pageScaffold(r'\b(Scaffold|AppBar)\(', 'a Scaffold or AppBar: use AppPage'),
  progressIndicator(
    r'\b(Linear|Circular)ProgressIndicator\(',
    'a raw progress indicator: use the shared status pieces',
  );

  const _Rule(this.pattern, this.description);

  final String pattern;
  final String description;

  RegExp get regExp => RegExp(pattern);
}

/// Where the library lives. The theme may hold colour literals; the
/// widgets and the gallery may draw decoration but must use the tokens.
bool _exempt(String path, _Rule rule) {
  if (path.startsWith('lib/shared/theme/')) return true;
  if (rule == _Rule.colourLiteral) return false;
  return path.startsWith('lib/shared/widgets/') ||
      path.startsWith('lib/shared/gallery/');
}

/// Files not yet on the library, and the rules each still breaks. Each
/// bolt that migrates a screen removes it here (bolts 045 to 049).
const _notYetMigrated = <String, Set<_Rule>>{
  'lib/features/lesson/screens/download_management_screen.dart': {
    _Rule.boxShadow,
    _Rule.radiusOrBorder,
    _Rule.materialButton,
    _Rule.rawSheetOrDialog,
    _Rule.pageScaffold,
    _Rule.progressIndicator,
  },
  'lib/features/settings/screens/settings_screen.dart': {
    _Rule.materialButton,
    _Rule.rawSheetOrDialog,
    _Rule.pageScaffold,
    _Rule.progressIndicator,
  },
};

/// [source] without comments, so doc comments that name a widget do not
/// count. Line numbers are kept.
String _withoutComments(String source) {
  final withoutBlocks = source.replaceAllMapped(
    RegExp(r'/\*[\s\S]*?\*/'),
    (m) => '\n' * '\n'.allMatches(m[0]!).length,
  );
  return withoutBlocks
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i < 0 ? line : line.substring(0, i);
      })
      .join('\n');
}

class _Violation {
  _Violation(this.path, this.line, this.rule);

  final String path;
  final int line;
  final _Rule rule;

  @override
  String toString() => '$path:$line  ${rule.description}';
}

List<_Violation> _scan() {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final violations = <_Violation>[];
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    final lines = _withoutComments(file.readAsStringSync()).split('\n');
    for (final rule in _Rule.values) {
      if (_exempt(path, rule)) continue;
      final regExp = rule.regExp;
      for (var i = 0; i < lines.length; i++) {
        if (regExp.hasMatch(lines[i])) {
          violations.add(_Violation(path, i + 1, rule));
        }
      }
    }
  }
  return violations;
}

void main() {
  final violations = _scan();

  test(
    'no file draws its own decoration unless it is still on the allow-list',
    () {
      final unexpected = violations
          .where((v) => !(_notYetMigrated[v.path]?.contains(v.rule) ?? false))
          .toList();
      expect(
        unexpected,
        isEmpty,
        reason:
            'Move this into lib/shared/ (a token or a shared component) '
            'instead:\n${unexpected.join('\n')}',
      );
    },
  );

  test('every allow-list entry is still needed, so the list only shrinks', () {
    final stale = <String>[];
    for (final MapEntry(key: path, value: rules) in _notYetMigrated.entries) {
      for (final rule in rules) {
        final stillBroken = violations.any(
          (v) => v.path == path && v.rule == rule,
        );
        if (!stillBroken) stale.add('$path  ${rule.name}');
      }
    }
    expect(
      stale,
      isEmpty,
      reason:
          'These no longer break the rule; remove them from '
          '_notYetMigrated:\n${stale.join('\n')}',
    );
  });

  test('no colour literal is allowed anywhere outside the theme', () {
    expect(
      _notYetMigrated.values.where((r) => r.contains(_Rule.colourLiteral)),
      isEmpty,
    );
  });

  group('the rules themselves', () {
    test('each rule catches what it names', () {
      const samples = {
        _Rule.colourLiteral: 'color: Color(0xFFFFF7ED),',
        _Rule.boxShadow: 'boxShadow: [BoxShadow(color: c)],',
        _Rule.radiusOrBorder: 'BorderRadius.circular(20), Border.all()',
        _Rule.materialButton: 'TextButton.icon(onPressed: f)',
        _Rule.rawSheetOrDialog: 'await showModalBottomSheet<bool>(',
        _Rule.pageScaffold: 'return Scaffold(body: b);',
        _Rule.progressIndicator: 'const CircularProgressIndicator()',
      };
      for (final MapEntry(key: rule, value: sample) in samples.entries) {
        expect(rule.regExp.hasMatch(sample), isTrue, reason: rule.name);
      }
    });

    test('comments do not count, and line numbers are kept', () {
      const source =
          '/// Replaces [TextButton(...)]\n'
          'final a = 1; // a Scaffold( in a comment\n'
          '/* BoxShadow(\n   Color(0x1) */ final b = 2;\n'
          'Scaffold(';
      final lines = _withoutComments(source).split('\n');
      expect(lines, hasLength(5));
      expect(_Rule.materialButton.regExp.hasMatch(lines[0]), isFalse);
      expect(_Rule.pageScaffold.regExp.hasMatch(lines[1]), isFalse);
      expect(_Rule.boxShadow.regExp.hasMatch(lines[2]), isFalse);
      expect(_Rule.colourLiteral.regExp.hasMatch(lines[3]), isFalse);
      expect(_Rule.pageScaffold.regExp.hasMatch(lines[4]), isTrue);
    });

    test('the library is exempt, the theme from everything', () {
      expect(
        _exempt('lib/shared/theme/app_colors.dart', _Rule.colourLiteral),
        isTrue,
      );
      expect(
        _exempt('lib/shared/widgets/app_button.dart', _Rule.boxShadow),
        isTrue,
      );
      expect(
        _exempt('lib/shared/widgets/app_button.dart', _Rule.colourLiteral),
        isFalse,
      );
      expect(
        _exempt(
          'lib/shared/gallery/component_gallery.dart',
          _Rule.pageScaffold,
        ),
        isTrue,
      );
      expect(
        _exempt(
          'lib/shared/screens/home_placeholder_screen.dart',
          _Rule.pageScaffold,
        ),
        isFalse,
      );
      expect(
        _exempt(
          'lib/features/lesson/screens/lesson_screen.dart',
          _Rule.boxShadow,
        ),
        isFalse,
      );
    });
  });
}
