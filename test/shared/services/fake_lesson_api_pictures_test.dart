// The fake API's picture questions and the pictures bundled for them
// (019-image-choice-exercise-types, bolt 053).
//
// The fake and the gallery show pictures without a backend by bundling four
// of bolt 051's credited sample pictures. These tests keep the copies
// identical to the credited originals, keep their credits beside them, and
// check every picture the fake asks for is really bundled.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/practice_completion_result.dart';
import 'package:elang/shared/services/fake_lesson_api.dart';

const _bundled = ['water.webp', 'dog.webp', 'house.webp', 'cat.webp'];

/// The picture assets `pubspec.yaml` lists.
List<String> _listedPictures() =>
    File('pubspec.yaml')
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.startsWith('- assets/pictures/'))
        .map((line) => line.substring(2))
        .toList();

List<Map<String, dynamic>> _credits(String path) =>
    ((jsonDecode(File(path).readAsStringSync()) as Map)['pictures'] as List)
        .cast<Map<String, dynamic>>();

List<PictureChoice> _picturesOf(Exercise exercise) => switch (exercise) {
  ImageChoiceExercise e => e.choices,
  AudioImageChoiceExercise e => e.choices,
  _ => const [],
};

int _answerOf(Exercise exercise) => switch (exercise) {
  ImageChoiceExercise e => e.correctOptionIndex,
  AudioImageChoiceExercise e => e.correctOptionIndex,
  _ => -1,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the bundled pictures', () {
    test('are byte-for-byte the credited sample pictures', () {
      for (final name in _bundled) {
        expect(
          File('assets/pictures/$name').readAsBytesSync(),
          File('backend/sample_pictures/$name').readAsBytesSync(),
          reason: name,
        );
      }
    });

    test('are exactly the pictures in the folder', () {
      final webps =
          Directory('assets/pictures')
              .listSync()
              .map((f) => f.uri.pathSegments.last)
              .where((n) => n.endsWith('.webp'))
              .toList()
            ..sort();
      expect(webps, [..._bundled]..sort());
    });

    test('carry their credits, the same as the originals\'', () {
      final originals = {
        for (final c in _credits('backend/sample_pictures/credits.json'))
          c['file']: c,
      };
      final copies = _credits('assets/pictures/credits.json');

      expect(copies.map((c) => c['file']), _bundled);
      for (final copy in copies) {
        expect(copy, originals[copy['file']], reason: '${copy['file']}');
        expect(copy['author'], isNotEmpty);
        expect(copy['licence'], startsWith('CC'));
      }
    });

    test('are all listed in pubspec.yaml, and nothing else under '
        'pictures is', () {
      expect(_listedPictures(), [
        for (final name in _bundled) 'assets/pictures/$name',
      ]);
    });

    test('are in the app bundle', () async {
      for (final name in _bundled) {
        final data = await rootBundle.load('assets/pictures/$name');
        // "RIFF....WEBP"
        expect(
          String.fromCharCodes(data.buffer.asUint8List(8, 4)),
          'WEBP',
          reason: name,
        );
      }
    });
  });

  group('the coffee lesson', () {
    test('ends with one question of each picture type, after the other '
        'five', () async {
      final api = FakeLessonApi(latency: Duration.zero);
      final lesson = await api.startLesson('lesson-coffee');

      expect(lesson.exercises.map((e) => e.runtimeType.toString()), [
        'MultipleChoiceExercise',
        'ListeningExercise',
        'SentenceConstructionExercise',
        'MatchPairsExercise',
        'GapFillExercise',
        'ImageChoiceExercise',
        'AudioImageChoiceExercise',
      ]);
    });

    test('its picture questions are valid: 2 to 4 described, bundled '
        'pictures and an answer among them', () async {
      final api = FakeLessonApi(latency: Duration.zero);
      final lesson = await api.startLesson('lesson-coffee');
      final listed = _listedPictures();

      final pictureQuestions = lesson.exercises.where(
        (e) => _picturesOf(e).isNotEmpty,
      );
      expect(pictureQuestions, hasLength(2));
      for (final exercise in pictureQuestions) {
        final pictures = _picturesOf(exercise);
        expect(pictures.length, inInclusiveRange(2, 4), reason: exercise.id);
        expect(_answerOf(exercise), inInclusiveRange(0, pictures.length - 1));
        for (final p in pictures) {
          expect(listed, contains(p.imageUrl), reason: exercise.id);
          expect(p.altText.trim(), isNotEmpty);
        }
        expect(
          pictures.map((p) => p.imageUrl).toSet(),
          hasLength(pictures.length),
          reason: '${exercise.id}: each picture once',
        );
      }
    });

    test(
      'the image question asks for water, and water is its answer',
      () async {
        final api = FakeLessonApi(latency: Duration.zero);
        final lesson = await api.startLesson('lesson-coffee');
        final image = lesson.exercises.whereType<ImageChoiceExercise>().single;

        expect(image.prompt, "Choose the picture: 'ውሃ'");
        expect(
          image.choices[image.correctOptionIndex].imageUrl,
          'assets/pictures/water.webp',
        );
      },
    );

    test('the audio question never writes its word', () async {
      final api = FakeLessonApi(latency: Duration.zero);
      final lesson = await api.startLesson('lesson-coffee');
      final audio = lesson.exercises
          .whereType<AudioImageChoiceExercise>()
          .single;

      expect(audio.instruction, 'Tap the picture you hear');
      expect(
        audio.choices[audio.correctOptionIndex].imageUrl,
        'assets/pictures/dog.webp',
      );
    });
  });

  group('practice', () {
    test('one word is due, asked as a picture question', () async {
      final api = FakeLessonApi(latency: Duration.zero);

      expect(await api.getDueCount(), 1);
      final item = (await api.getDueItems()).single;
      expect(item.word, 'ቤት');
      final exercise = item.exercise as ImageChoiceExercise;
      expect(
        exercise.choices[exercise.correctOptionIndex].imageUrl,
        'assets/pictures/house.webp',
      );
    });

    test('it stays due until a practice session reports it', () async {
      final api = FakeLessonApi(latency: Duration.zero);
      final item = (await api.getDueItems()).single;

      await api.completePracticeSession(
        sessionId: 's-1',
        results: const [PracticeResult(vocabItemId: 'another', correct: true)],
        timeSpent: Duration.zero,
      );
      expect(await api.getDueCount(), 1);

      await api.completePracticeSession(
        sessionId: 's-2',
        results: [PracticeResult(vocabItemId: item.vocabItemId, correct: true)],
        timeSpent: Duration.zero,
      );
      expect(await api.getDueCount(), 0);
      expect(await api.getDueItems(), isEmpty);
    });

    test('a fresh fake starts with the word due again', () async {
      final first = FakeLessonApi(latency: Duration.zero);
      final item = (await first.getDueItems()).single;
      await first.completePracticeSession(
        sessionId: 's',
        results: [PracticeResult(vocabItemId: item.vocabItemId, correct: true)],
        timeSpent: Duration.zero,
      );

      expect(await FakeLessonApi(latency: Duration.zero).getDueCount(), 1);
    });

    test('the limit is respected', () async {
      final api = FakeLessonApi(latency: Duration.zero);
      expect(await api.getDueItems(limit: 0), isEmpty);
    });
  });
}
