// Downloaded lessons carry their pictures and clips
// (019-image-choice-exercise-types, bolt 054, story 003): what is fetched,
// what the files are called, a shared picture fetched once, and a failed
// download leaving nothing behind. Files are written for real, into a temp
// folder standing in for the app's documents folder.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';
import 'package:elang/shared/services/lesson_pack_store.dart';

import '../../helpers/controllable_lesson_api.dart';
import '../../helpers/fake_lesson_pack_store.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

const _cdn = 'https://pub.r2.dev';

const _image = ImageChoiceExercise(
  id: 'ic-1',
  prompt: "Choose the picture: 'ውሻ'",
  choices: [
    PictureChoice(imageUrl: '$_cdn/p/cat.webp', altText: 'A cat'),
    PictureChoice(imageUrl: '$_cdn/p/dog.webp?v=2', altText: 'A dog'),
    PictureChoice(imageUrl: '$_cdn/p/house', altText: 'A house'),
  ],
  correctOptionIndex: 1,
);

const _audioImage = AudioImageChoiceExercise(
  id: 'aic-1',
  audioUrl: '$_cdn/a/dog.m4a',
  instruction: 'Tap the picture you hear',
  choices: [
    // The same picture as the image question's dog: fetched once.
    PictureChoice(imageUrl: '$_cdn/p/dog.webp?v=2', altText: 'A dog'),
    PictureChoice(imageUrl: '$_cdn/p/sun.png', altText: 'The sun'),
  ],
  correctOptionIndex: 0,
);

const _listen = ListeningExercise(
  id: 'li-1',
  audioUrl: '$_cdn/a/selam.mp3',
  instruction: 'Tap what you hear',
  options: ['ሰላም', 'ደህና'],
  correctOptionIndex: 0,
);

const _mc = MultipleChoiceExercise(
  id: 'mc-1',
  prompt: 'ቡና',
  promptTranslation: 'What does this word mean?',
  options: ['Coffee', 'Tea'],
  correctOptionIndex: 0,
);

LessonContent _lesson(List<Exercise> exercises) => LessonContent(
  lessonId: 'lesson-pictures',
  skillId: 'skill-pictures',
  title: 'Pictures',
  beansAtStart: 5,
  beansMax: 5,
  exercises: exercises,
  unrenderableCount: 1,
);

/// Serves each address as bytes naming it, and counts requests per
/// address; any address in [failing] gets a 404.
class _Cdn {
  _Cdn({this.failing = const {}});

  final Set<String> failing;
  final Map<String, int> requests = {};

  http.Client get client => MockClient((request) async {
    final url = request.url.toString();
    requests[url] = (requests[url] ?? 0) + 1;
    if (failing.contains(url)) return http.Response('gone', 404);
    return http.Response.bytes(url.codeUnits, 200);
  });
}

void main() {
  late Directory tempDir;
  late String packDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pack_pictures_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    packDir = '${tempDir.path}/lesson_packs/lesson-pictures';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<(LessonPackDownloader, FakeLessonPackStore)> download(
    List<Exercise> exercises,
    _Cdn cdn, {
    FakeLessonPackStore? store,
  }) async {
    final packStore = store ?? FakeLessonPackStore();
    final downloader = LessonPackDownloader(
      lessonApi: ControllableLessonApi()..lessonContent = _lesson(exercises),
      packStore: packStore,
      httpClient: cdn.client,
    );
    await downloader.downloadLesson('lesson-pictures');
    return (downloader, packStore);
  }

  List<String> filesIn(String dir) => Directory(dir).existsSync()
      ? (Directory(dir).listSync().map((f) => f.uri.pathSegments.last).toList()
          ..sort())
      : const [];

  String nameOf(String path) => File(path).uri.pathSegments.last;

  group('a lesson with both picture types', () {
    test(
      'saves every picture and the clip, and points the pack at them',
      () async {
        final cdn = _Cdn();
        final (downloader, store) = await download([
          _mc,
          _image,
          _audioImage,
        ], cdn);

        expect(
          downloader.statusFor('lesson-pictures'),
          LessonDownloadStatus.downloaded,
        );
        final saved = (await store.load('lesson-pictures'))!;
        final image = saved.exercises[1] as ImageChoiceExercise;
        final audio = saved.exercises[2] as AudioImageChoiceExercise;

        for (final path in [
          ...image.choices.map((c) => c.imageUrl),
          audio.audioUrl,
          ...audio.choices.map((c) => c.imageUrl),
        ]) {
          expect(path, startsWith(packDir), reason: path);
          expect(File(path).existsSync(), isTrue, reason: path);
        }
        // Each file holds what its own address served.
        expect(
          String.fromCharCodes(
            File(image.choices[0].imageUrl).readAsBytesSync(),
          ),
          '$_cdn/p/cat.webp',
        );
        expect(
          String.fromCharCodes(File(audio.audioUrl).readAsBytesSync()),
          '$_cdn/a/dog.m4a',
        );
      },
    );

    test('keeps everything else about each question', () async {
      final (_, store) = await download([_image, _audioImage], _Cdn());
      final saved = (await store.load('lesson-pictures'))!;

      final image = saved.exercises[0] as ImageChoiceExercise;
      expect(image.id, 'ic-1');
      expect(image.prompt, _image.prompt);
      expect(image.correctOptionIndex, 1);
      expect(image.choices.map((c) => c.altText), [
        'A cat',
        'A dog',
        'A house',
      ]);

      final audio = saved.exercises[1] as AudioImageChoiceExercise;
      expect(audio.instruction, 'Tap the picture you hear');
      expect(audio.correctOptionIndex, 0);
      expect(audio.choices.map((c) => c.altText), ['A dog', 'The sun']);
      expect(saved.unrenderableCount, 1);
    });

    test('names files {exercise}-picture-{n} and {exercise}, with the '
        'extension of the address\'s path', () async {
      final (_, store) = await download([_image, _audioImage], _Cdn());
      final saved = (await store.load('lesson-pictures'))!;
      final image = saved.exercises[0] as ImageChoiceExercise;
      final audio = saved.exercises[1] as AudioImageChoiceExercise;

      expect(image.choices.map((c) => nameOf(c.imageUrl)), [
        'ic-1-picture-0.webp',
        // `?v=2` is not part of the name.
        'ic-1-picture-1.webp',
        // No extension in the address: none on the file.
        'ic-1-picture-2',
      ]);
      expect(nameOf(audio.audioUrl), 'aic-1.m4a');
      // The shared dog is the image question's file.
      expect(nameOf(audio.choices[0].imageUrl), 'ic-1-picture-1.webp');
      expect(nameOf(audio.choices[1].imageUrl), 'aic-1-picture-1.png');
    });

    test(
      'a picture used twice is fetched once, and both choices show it',
      () async {
        final cdn = _Cdn();
        final (_, store) = await download([_image, _audioImage], cdn);
        final saved = (await store.load('lesson-pictures'))!;

        expect(cdn.requests['$_cdn/p/dog.webp?v=2'], 1);
        expect(cdn.requests.values.every((n) => n == 1), isTrue);
        expect(cdn.requests, hasLength(5));
        expect(
          (saved.exercises[1] as AudioImageChoiceExercise).choices[0].imageUrl,
          (saved.exercises[0] as ImageChoiceExercise).choices[1].imageUrl,
        );
      },
    );

    test(
      'a listening clip is still saved as {exercise}{ext} beside them',
      () async {
        final (_, store) = await download([_listen, _image], _Cdn());
        final saved = (await store.load('lesson-pictures'))!;

        final listen = saved.exercises[0] as ListeningExercise;
        expect(nameOf(listen.audioUrl), 'li-1.mp3');
        expect(File(listen.audioUrl).existsSync(), isTrue);
      },
    );

    test('every file the pack refers to is one the download saved', () async {
      final (_, store) = await download([_listen, _image, _audioImage], _Cdn());
      final saved = (await store.load('lesson-pictures'))!;

      expect(
        packLocalFiles(saved).map(nameOf).toList()..sort(),
        filesIn(packDir),
      );
    });
  });

  group('a failed download', () {
    for (final failing in [
      '$_cdn/p/house',
      '$_cdn/a/dog.m4a',
      '$_cdn/p/sun.png',
    ]) {
      test(
        'when $failing fails: failed, nothing saved, no files left',
        () async {
          final (downloader, store) = await download([
            _image,
            _audioImage,
          ], _Cdn(failing: {failing}));

          expect(
            downloader.statusFor('lesson-pictures'),
            LessonDownloadStatus.failed,
          );
          expect(await store.load('lesson-pictures'), isNull);
          expect(filesIn(packDir), isEmpty);
        },
      );
    }

    test(
      'a failed re-download keeps the files of the pack already saved',
      () async {
        final store = FakeLessonPackStore();
        await download([_image, _audioImage], _Cdn(), store: store);
        final before = (await store.load('lesson-pictures'))!;
        final files = packLocalFiles(before);

        final (downloader, _) = await download(
          [_image, _audioImage],
          _Cdn(failing: {'$_cdn/p/sun.png'}),
          store: store,
        );

        expect(
          downloader.statusFor('lesson-pictures'),
          LessonDownloadStatus.failed,
        );
        expect(await store.load('lesson-pictures'), same(before));
        for (final path in files) {
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      },
    );

    test('a failed re-download still removes a file only it created', () async {
      final store = FakeLessonPackStore();
      // The first download had no audio question.
      await download([_image], _Cdn(), store: store);
      final kept = filesIn(packDir);

      await download(
        [_image, _audioImage],
        _Cdn(failing: {'$_cdn/p/sun.png'}),
        store: store,
      );

      // aic-1.m4a was new in the second attempt, so it is gone again.
      expect(filesIn(packDir), kept);
    });
  });

  test('a lesson whose only media is an image choice question still '
      'downloads its pictures', () async {
    final cdn = _Cdn();
    final (downloader, store) = await download([_mc, _image], cdn);

    expect(
      downloader.statusFor('lesson-pictures'),
      LessonDownloadStatus.downloaded,
    );
    expect(cdn.requests, hasLength(3));
    final image =
        (await store.load('lesson-pictures'))!.exercises[1]
            as ImageChoiceExercise;
    for (final choice in image.choices) {
      expect(choice.imageUrl, startsWith(packDir));
    }
  });

  test('a lesson with no clip or picture makes no request', () async {
    final cdn = _Cdn();
    final (downloader, store) = await download([_mc], cdn);

    expect(
      downloader.statusFor('lesson-pictures'),
      LessonDownloadStatus.downloaded,
    );
    expect(cdn.requests, isEmpty);
    expect((await store.load('lesson-pictures'))!.exercises.single, same(_mc));
  });
}
