// Keeps every screen on the shared design library (018-mobile-design-system,
// NFR-1). Colours, shadows, radii, borders, buttons, sheets, page scaffolds
// and progress indicators may only be drawn in `lib/shared/`, where the
// tokens and components live; a screen that draws its own fails here.
//
// Every screen is on the library (bolts 045 to 049), so there is no
// allow-list: a violation found later is fixed by moving the code into the
// library, never by excusing the file. The library itself must not keep a
// widget that nothing uses.

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

/// The end of the class body whose `class` keyword is at [start]: the
/// index of its closing brace.
int _classBodyEnd(String source, int start) {
  var depth = 0;
  for (var i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}' && --depth == 0) return i;
  }
  return source.length - 1;
}

/// Every Dart file in `lib/`, by path, without comments.
Map<String, String> _libSources() => {
  for (final file
      in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
    file.path.replaceAll(r'\', '/'): _withoutComments(file.readAsStringSync()),
};

/// Public classes in `lib/shared/widgets/` that nothing in [sources] uses:
/// not another file (the gallery does not count), and not their own file
/// outside their own body (so a painter used by its page counts).
List<String> _unusedSharedClasses(Map<String, String> sources) {
  final declaration = RegExp(
    r'^(?:abstract |sealed |final |base )*class ([A-Z]\w*)',
    multiLine: true,
  );
  final unused = <String>[];
  for (final MapEntry(key: path, value: source) in sources.entries) {
    if (!path.startsWith('lib/shared/widgets/')) continue;
    for (final match in declaration.allMatches(source)) {
      final name = match[1]!;
      final use = RegExp('\\b$name\\b');
      final outsideBody =
          source.substring(0, match.start) +
          source.substring(_classBodyEnd(source, match.end) + 1);
      final used =
          use.hasMatch(outsideBody) ||
          sources.entries.any(
            (other) =>
                other.key != path &&
                !other.key.startsWith('lib/shared/gallery/') &&
                use.hasMatch(other.value),
          );
      if (!used) unused.add('$path  $name');
    }
  }
  return unused..sort();
}

void main() {
  final violations = _scan();

  test('no file outside the library draws its own decoration', () {
    expect(
      violations,
      isEmpty,
      reason:
          'Move this into lib/shared/ (a token or a shared component) '
          'instead:\n${violations.join('\n')}',
    );
  });

  test('every shared widget is used somewhere in the app', () {
    final unused = _unusedSharedClasses(_libSources());
    expect(
      unused,
      isEmpty,
      reason:
          'Nothing in lib/ (outside the gallery) uses these; delete them:\n'
          '${unused.join('\n')}',
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

    test('a class body is matched to its own closing brace', () {
      const source =
          'class A {\n  void f() { if (x) { y(); } }\n}\nclass B {}\n';
      final end = _classBodyEnd(source, 0);
      expect(source.substring(end + 1), '\nclass B {}\n');
    });

    test('a shared class counts as used from a screen or from its own '
        'file, but not from the gallery or its own body', () {
      const sources = {
        'lib/shared/widgets/kit.dart':
            'class Used {}\n'
            'class GalleryOnly {}\n'
            'class SelfOnly { SelfOnly(); SelfOnly copy() => SelfOnly(); }\n'
            'class Painter {}\n'
            'class Page { Object paint() => Painter(); }\n',
        'lib/shared/gallery/gallery.dart': 'final a = GalleryOnly();',
        'lib/features/screen.dart': 'final b = Used(); final c = Page();',
      };
      expect(_unusedSharedClasses(sources), [
        'lib/shared/widgets/kit.dart  GalleryOnly',
        'lib/shared/widgets/kit.dart  SelfOnly',
      ]);
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
