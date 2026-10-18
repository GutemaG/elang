import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// FR-9: both fonts ship inside the app, at four weights, with their SIL OFL
// licence beside them, and within the 2 MB budget (NFR-3).
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  const families = {
    'PlusJakartaSans': 'assets/fonts/PlusJakartaSans',
    'NotoSansEthiopic': 'assets/fonts/NotoSansEthiopic',
  };
  const weights = {
    400: 'Regular',
    500: 'Medium',
    700: 'Bold',
    800: 'ExtraBold',
  };

  for (final MapEntry(key: family, value: dir) in families.entries) {
    group(family, () {
      test('should be declared in pubspec.yaml at 400, 500, 700 and 800', () {
        expect(pubspec, contains('- family: $family'));
        for (final MapEntry(key: weight, value: name) in weights.entries) {
          final asset = '$dir/$family-$name.ttf';
          expect(
            RegExp('- asset: ${RegExp.escape(asset)}\\s*\\n\\s*weight: $weight')
                .hasMatch(pubspec),
            isTrue,
            reason: '$asset at $weight',
          );
        }
      });

      test('should ship each declared weight as a real TrueType file', () {
        for (final name in weights.values) {
          final file = File('$dir/$family-$name.ttf');
          expect(file.existsSync(), isTrue, reason: file.path);
          final magic = file.openSync()..setPositionSync(0);
          final head = magic.readSync(4);
          magic.closeSync();
          expect(head, [0x00, 0x01, 0x00, 0x00], reason: file.path);
        }
      });

      test('should carry its SIL Open Font License', () {
        final licence = File('$dir/OFL.txt');
        expect(licence.existsSync(), isTrue);
        expect(
          licence.readAsStringSync(),
          contains('SIL Open Font License, Version 1.1'),
        );
      });
    });
  }

  test('should add no more than 2 MB of fonts to the app', () {
    var bytes = 0;
    for (final dir in families.values) {
      for (final file in Directory(dir).listSync().whereType<File>()) {
        if (file.path.endsWith('.ttf')) bytes += file.lengthSync();
      }
    }
    expect(bytes, lessThanOrEqualTo(2 * 1024 * 1024));
  });
}
