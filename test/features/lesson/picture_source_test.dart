// Where a picture is loaded from, by its address
// (019-image-choice-exercise-types, bolts 053 and 054).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/picture_source.dart';

import '../../helpers/fake_media_cache.dart';

/// A 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  test('an https or http address is a network picture', () {
    expect(
      pictureImageFor('https://pub.r2.dev/p/dog.webp'),
      const NetworkImage('https://pub.r2.dev/p/dog.webp'),
    );
    expect(
      pictureImageFor('http://localhost:8000/media/images/dog.webp'),
      const NetworkImage('http://localhost:8000/media/images/dog.webp'),
    );
  });

  test('an assets/ path is bundled with the app', () {
    expect(
      pictureImageFor('assets/pictures/dog.webp'),
      const AssetImage('assets/pictures/dog.webp'),
    );
  });

  test('anything else is a downloaded file on the device', () {
    const path = '/data/user/0/app/lesson_packs/l-1/ic-1-picture-0.webp';
    final image = pictureImageFor(path);
    expect(image, isA<FileImage>());
    expect((image as FileImage).file.path, File(path).path);

    const windows =
        r'C:\Users\me\Documents\lesson_packs\l-1\ic-1-picture-0.webp';
    expect(pictureImageFor(windows), isA<FileImage>());
  });

  test('an address merely containing "https" is still a file', () {
    expect(pictureImageFor('/packs/https-picture.webp'), isA<FileImage>());
  });

  group('with a media cache (bolt 057)', () {
    test('a web address is read from the cache', () {
      final cache = FakeMediaCache();
      const url = 'https://pub.r2.dev/p/dog.webp';

      final image = pictureImageFor(url, cache: cache);

      expect(image, CachedPicture(url, cache));
      expect(image, isNot(CachedPicture(url, FakeMediaCache())));
    });

    test('bundled and downloaded pictures do not use it', () {
      final cache = FakeMediaCache();
      expect(
        pictureImageFor('assets/pictures/dog.webp', cache: cache),
        isA<AssetImage>(),
      );
      expect(
        pictureImageFor('/packs/l-1/ic-1-picture-0.webp', cache: cache),
        isA<FileImage>(),
      );
    });

    testWidgets('the picture is decoded from its saved file', (tester) async {
      final folder = Directory.systemTemp.createTempSync('cached_picture');
      addTearDown(() => folder.deleteSync(recursive: true));
      final file = File('${folder.path}/dog.png')..writeAsBytesSync(_png);
      const url = 'https://pub.r2.dev/p/dog.png';
      final cache = FakeMediaCache()..files[url] = file.path;

      final info = await tester.runAsync(() {
        final done = Completer<ImageInfo>();
        CachedPicture(url, cache)
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (info, _) => done.complete(info),
                onError: done.completeError,
              ),
            );
        return done.future;
      });

      expect(info!.image.width, 1);
      expect(cache.asked, [url]);
    });
  });
}
