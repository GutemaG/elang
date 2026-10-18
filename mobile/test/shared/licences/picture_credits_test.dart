// The bundled pictures' credits on the licence page
// (019-image-choice-exercise-types, bolt 054, story 005).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/licences/picture_credits.dart';

Map<String, String> _picture(String file, {String licence = 'CC BY-SA 4.0'}) =>
    {
      'file': file,
      'subject': 'The $file',
      'author': 'Author of $file',
      'source': 'OpenMoji',
      'source_url': 'https://openmoji.org/library/$file/',
      'licence': licence,
      'licence_url': 'https://creativecommons.org/licenses/by-sa/4.0/',
      'changes': 'Resized to 512 px and converted to WebP',
    };

String _json(List<Map<String, String>> pictures) =>
    jsonEncode({'pictures': pictures});

List<String> _paragraphs(LicenseEntry entry) =>
    entry.paragraphs.map((p) => p.text).toList();

/// Serves [files] by name, as the app bundle would; anything else is
/// missing.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);

  final Map<String, String> files;
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    final text = files[key];
    if (text == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

Future<List<LicenseEntry>> _registered() => LicenseRegistry.licenses
    .where((e) => e.packages.contains(pictureCreditsPackage))
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(LicenseRegistry.reset);

  group('building the entries', () {
    test('one entry per picture, in order, under "Sample pictures"', () {
      final entries = pictureCreditEntries(
        _json([_picture('water'), _picture('dog'), _picture('cat')]),
      );

      expect(entries, hasLength(3));
      for (final entry in entries) {
        expect(entry.packages, ['Sample pictures']);
      }
      expect(entries.map((e) => _paragraphs(e).first), [
        'The water',
        'The dog',
        'The cat',
      ]);
    });

    test('title, author and source, source link, licence and link, and '
        'the changes', () {
      final entry = pictureCreditEntries(_json([_picture('dog')])).single;

      expect(_paragraphs(entry), [
        'The dog',
        'By Author of dog, from OpenMoji',
        'https://openmoji.org/library/dog/',
        'Licence: CC BY-SA 4.0',
        'https://creativecommons.org/licenses/by-sa/4.0/',
        'Changes: Resized to 512 px and converted to WebP',
      ]);
    });

    test('a CC0 picture is listed too', () {
      final entry = pictureCreditEntries(
        _json([_picture('sun', licence: 'CC0 1.0')]),
      ).single;

      expect(_paragraphs(entry), contains('Licence: CC0 1.0'));
      expect(_paragraphs(entry), contains('By Author of sun, from OpenMoji'));
    });

    test('a picture added to the file is listed with no code change', () {
      final one = pictureCreditEntries(_json([_picture('water')]));
      final two = pictureCreditEntries(
        _json([_picture('water'), _picture('a-new-picture')]),
      );

      expect(one, hasLength(1));
      expect(two, hasLength(2));
      expect(_paragraphs(two.last).first, 'The a-new-picture');
    });

    test('missing or blank fields are left out, not printed empty', () {
      final entry = pictureCreditEntries(
        jsonEncode({
          'pictures': [
            {'file': 'plain.webp', 'author': '  ', 'licence': 'CC BY 4.0'},
          ],
        }),
      ).single;

      expect(_paragraphs(entry), ['plain.webp', 'Licence: CC BY 4.0']);
    });
  });

  group('registering them', () {
    test(
      'the licence registry lists them, read from the bundled file',
      () async {
        final bundle = _Bundle({
          pictureCreditsAsset: _json([_picture('water'), _picture('dog')]),
        });

        registerPictureCredits(bundle: bundle);
        expect(bundle.loads, 0, reason: 'read only when the page asks');

        final entries = await _registered();
        expect(entries, hasLength(2));
        expect(_paragraphs(entries.first).first, 'The water');
        expect(bundle.loads, 1);
      },
    );

    test(
      'a file that cannot be read lists nothing and raises nothing',
      () async {
        registerPictureCredits(bundle: _Bundle(const {}));

        expect(await _registered(), isEmpty);
        // The rest of the licence page is unaffected.
        await expectLater(LicenseRegistry.licenses.toList(), completes);
      },
    );

    test('the real bundled file credits each bundled picture', () async {
      registerPictureCredits();

      final entries = await _registered();
      final credits =
          ((jsonDecode(File('assets/pictures/credits.json').readAsStringSync())
                      as Map)['pictures']
                  as List)
              .cast<Map<String, dynamic>>();
      final bundled = Directory('assets/pictures')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.webp'))
          .toSet();

      expect(credits.map((c) => c['file']).toSet(), bundled);
      expect(entries, hasLength(bundled.length));
      for (final (i, credit) in credits.indexed) {
        final text = _paragraphs(entries[i]).join('\n');
        expect(text, contains(credit['author'] as String));
        expect(text, contains(credit['source_url'] as String));
        expect(text, contains(credit['licence'] as String));
      }
    });
  });
}
