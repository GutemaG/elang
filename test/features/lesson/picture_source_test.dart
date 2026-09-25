// Where a picture is loaded from, by its address
// (019-image-choice-exercise-types, bolts 053 and 054).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/picture_source.dart';

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
}
