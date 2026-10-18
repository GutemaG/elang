// The ARB files agree (024-app-localization, story 007): every English key
// is translated into every other app language, with the same placeholders,
// and described for the translator.

import 'dart:convert';
import 'dart:io';

import 'package:elang/shared/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, Object?>;

/// The message keys: everything but `@@locale` and the `@key` metadata.
Set<String> _keys(Map<String, Object?> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// The `{name}` placeholders a message uses (plural branches included).
Set<String> _placeholders(String message) =>
    RegExp(r'\{(\w+)[,}]').allMatches(message).map((m) => m[1]!).toSet();

void main() {
  final english = _arb('en');

  test('every app language has an ARB file', () {
    for (final language in AppLanguage.all) {
      expect(
        File('lib/l10n/app_${language.code}.arb').existsSync(),
        isTrue,
        reason: 'lib/l10n/app_${language.code}.arb is missing',
      );
    }
  });

  test('every English key says where its text appears', () {
    String? description(String key) =>
        (english['@$key'] as Map<String, Object?>?)?['description'] as String?;
    final undescribed = [
      for (final key in _keys(english))
        if (description(key)?.isNotEmpty != true) key,
    ];
    expect(undescribed, isEmpty, reason: 'Add an "@key" description');
  });

  for (final language in AppLanguage.all.where((l) => l.code != 'en')) {
    group(language.englishName, () {
      final arb = _arb(language.code);

      test('has every English key, and no other', () {
        expect(_keys(arb).difference(_keys(english)), isEmpty);
        expect(
          _keys(english).difference(_keys(arb)),
          isEmpty,
          reason: 'Translate these into ${language.englishName}',
        );
      });

      test('uses the same placeholders', () {
        for (final key in _keys(english).intersection(_keys(arb))) {
          expect(
            _placeholders(arb[key]! as String),
            _placeholders(english[key]! as String),
            reason: '$key in app_${language.code}.arb',
          );
        }
      });

      test('says which language it is', () {
        expect(arb['@@locale'], language.code);
      });
    });
  }
}
