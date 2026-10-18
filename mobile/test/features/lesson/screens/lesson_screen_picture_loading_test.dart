// Picture questions from a download, and pictures loaded early
// (019-image-choice-exercise-types, bolt 054, stories 003 and 004).

import 'dart:io';

import 'package:elang/features/lesson/picture_source.dart';
import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_completion_result.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/course_cache_store.dart';
import 'package:elang/shared/services/sync_engine.dart';
import 'package:elang/shared/widgets/exercise/picture_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

const _mc = MultipleChoiceExercise(
  id: 'mc',
  prompt: 'ቡና',
  promptTranslation: 'What does this word mean?',
  options: ['Coffee', 'Tea'],
  correctOptionIndex: 0,
);

ImageChoiceExercise _image(List<String> sources, {String id = 'ic'}) =>
    ImageChoiceExercise(
      id: id,
      prompt: "Choose the picture: 'ውሻ'",
      choices: [
        for (var i = 0; i < sources.length; i++)
          PictureChoice(imageUrl: sources[i], altText: 'Picture $i'),
      ],
      correctOptionIndex: 0,
    );

AudioImageChoiceExercise _audioImage(String clip, List<String> sources) =>
    AudioImageChoiceExercise(
      id: 'aic',
      audioUrl: clip,
      instruction: 'Tap the picture you hear',
      choices: [
        for (var i = 0; i < sources.length; i++)
          PictureChoice(imageUrl: sources[i], altText: 'Heard $i'),
      ],
      correctOptionIndex: 0,
    );

LessonContent _lesson(List<Exercise> exercises) => LessonContent(
  lessonId: 'lesson-pictures',
  skillId: 'skill-pictures',
  title: 'Pictures',
  beansAtStart: 5,
  beansMax: 5,
  exercises: exercises,
);

ControllableLessonApi _api(LessonContent content) => ControllableLessonApi()
  ..lessonContent = content
  ..completionResult = const LessonCompletionResult(
    xpEarned: 10,
    dailyXpTotal: 10,
    dailyXpTarget: 30,
    streakCount: 1,
    streakIncreasedToday: true,
    accuracyPercent: 100,
    correctCount: 1,
    totalCount: 1,
    timeSpent: Duration(seconds: 10),
  );

Widget _app(
  ControllableLessonApi api, {
  bool online = true,
  FakeLessonPackStore? packs,
  CourseCacheStore? cache,
  FakeLessonAudioPlayer? audio,
}) {
  final connectivity = FakeConnectivityMonitor(online: online);
  return MaterialApp(
    home: LessonScreen(
      lessonId: 'lesson-pictures',
      lessonApi: api,
      audioPlayer: audio ?? FakeLessonAudioPlayer(),
      feedbackPlayer: FakeAnswerFeedbackPlayer(),
      connectivityMonitor: connectivity,
      lessonPackStore: packs ?? FakeLessonPackStore(),
      syncEngine: SyncEngine(
        lessonApi: api,
        connectivityMonitor: connectivity,
        queueStore: FakePendingSyncQueueStore(),
      ),
      lessonCache: cache,
    ),
  );
}

/// A 400 × 800 phone at 2× pixels.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// The cache key of [source] as a tile on that phone decodes it: the grid
/// spans 400 px less the page's 20 px margins.
Future<Object> _tileKey(String source) {
  final side = PictureTile.pictureSideFor(PictureGrid.tileWidthFor(400 - 40));
  return PictureTile.decodedImage(
    pictureImageFor(source),
    pictureSide: side,
    devicePixelRatio: 2,
  ).obtainKey(ImageConfiguration.empty);
}

Future<bool> _requested(String source) async =>
    imageCache.statusForKey(await _tileKey(source)).tracked;

int _cacheEntries() => imageCache.pendingImageCount + imageCache.currentSize;

/// Lets real file reads (a `FileImage`) finish, then their results land.
Future<void> _letFilesLoad(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
}

void main() {
  late Directory tempDir;

  setUp(() {
    imageCache.clear();
    imageCache.clearLiveImages();
    tempDir = Directory.systemTemp.createTempSync('picture_loading_test');
  });

  tearDown(() {
    imageCache.clear();
    imageCache.clearLiveImages();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A downloaded file, as the downloader saves one.
  String file(String name) {
    final f = File('${tempDir.path}/$name')..writeAsBytesSync([1, 2, 3]);
    return f.path;
  }

  group('a downloaded pack, offline', () {
    testWidgets('plays its pictures and clip from the device', (tester) async {
      final pictures = [file('ic-picture-0.webp'), file('ic-picture-1.webp')];
      final clip = file('aic.m4a');
      final packs = FakeLessonPackStore();
      await packs.save(_lesson([_audioImage(clip, pictures)]));
      final audio = FakeLessonAudioPlayer();

      await tester.pumpWidget(
        _app(_api(_lesson([_mc])), online: false, packs: packs, audio: audio),
      );
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<PictureTile>(find.byType(PictureTile));
      expect(tiles.map((t) => t.image), [
        for (final p in pictures) FileImage(File(p)),
      ]);
      expect(audio.playedUrls, [clip]);
    });

    testWidgets('its pictures are loaded early from the device, not the '
        'network', (tester) async {
      _phone(tester);
      final pictures = [file('ic-picture-0.webp'), file('ic-picture-1.webp')];
      final packs = FakeLessonPackStore();
      await packs.save(_lesson([_mc, _image(pictures)]));

      await tester.pumpWidget(
        _app(_api(_lesson([_mc])), online: false, packs: packs),
      );
      await tester.pumpAndSettle();

      // Still on the first question, with no picture tile yet.
      expect(find.byType(PictureTile), findsNothing);
      for (final p in pictures) {
        expect(await _requested(p), isTrue, reason: p);
        expect(pictureImageFor(p), isA<FileImage>());
      }
    });
  });

  group('a cached copy, offline', () {
    testWidgets('holding only an audio picture question asks for a download', (
      tester,
    ) async {
      final cache = InMemoryCourseCacheStore();
      await cache.saveLesson(
        _lesson([
          _mc,
          _audioImage('https://pub.r2.dev/a.m4a', ['a', 'b']),
        ]),
      );

      await tester.pumpWidget(
        _app(_api(_lesson([_mc])), online: false, cache: cache),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Download this lesson while online to take it offline.'),
        findsOneWidget,
      );
    });

    testWidgets('with no clip or picture still plays', (tester) async {
      final cache = InMemoryCourseCacheStore();
      await cache.saveLesson(_lesson([_mc]));

      await tester.pumpWidget(
        _app(_api(_lesson([_mc])), online: false, cache: cache),
      );
      await tester.pumpAndSettle();

      expect(find.text('ቡና'), findsOneWidget);
    });
  });

  group('pictures are loaded early', () {
    const cat = 'assets/pictures/cat.webp';
    const dog = 'assets/pictures/dog.webp';
    const house = 'assets/pictures/house.webp';

    testWidgets('every picture in the lesson is asked for when it opens, '
        'each once', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          _api(
            _lesson([
              _mc,
              _image([cat, dog]),
              // The dog again, and a new picture.
              _audioImage('https://pub.r2.dev/a.m4a', [dog, house]),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PictureTile), findsNothing);
      for (final source in [cat, dog, house]) {
        expect(await _requested(source), isTrue, reason: source);
      }
      expect(_cacheEntries(), 3);
    });

    testWidgets('at the size the tile asks for, so the tile uses the early '
        'copy', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          _api(
            _lesson([
              _mc,
              _image([cat, dog]),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = _cacheEntries();

      await tester.tap(find.text('Coffee'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final drawn = tester.widgetList<Image>(
        find.descendant(
          of: find.byType(PictureTile),
          matching: find.byType(Image),
        ),
      );
      final drawnKeys = [
        for (final image in drawn)
          await image.image.obtainKey(ImageConfiguration.empty),
      ];
      expect(drawnKeys, [await _tileKey(cat), await _tileKey(dog)]);
      // No second copy: the tiles found the early ones.
      expect(_cacheEntries(), before);
    });

    testWidgets('a lesson with no pictures asks for nothing', (tester) async {
      await tester.pumpWidget(_app(_api(_lesson([_mc]))));
      await tester.pumpAndSettle();

      expect(_cacheEntries(), 0);
      expect(imageCache.liveImageCount, 0);
    });

    testWidgets('a picture that fails blocks nothing, and its tile asks for '
        'it again when shown', (tester) async {
      _phone(tester);
      final missing = '${tempDir.path}/never-downloaded.webp';
      await tester.pumpWidget(
        _app(
          _api(
            _lesson([
              _mc,
              _image([missing, cat]),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsOneWidget);

      await _letFilesLoad(tester);
      // Forgotten after failing, so nothing stale is kept.
      expect(await _requested(missing), isFalse);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Coffee'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(await _requested(missing), isTrue);
      await _letFilesLoad(tester);
      await tester.pump();
      // It failed again (the file is still missing), so it shows its
      // description.
      expect(find.byKey(PictureTile.failedKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaving before the pictures arrive raises nothing', (
      tester,
    ) async {
      final slow = ['${tempDir.path}/a.webp', '${tempDir.path}/b.webp'];
      await tester.pumpWidget(_app(_api(_lesson([_mc, _image(slow)]))));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await _letFilesLoad(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('practice loads its pictures early too', (tester) async {
      _phone(tester);
      final api = ControllableLessonApi();
      final connectivity = FakeConnectivityMonitor();
      await tester.pumpWidget(
        MaterialApp(
          home: LessonScreen.practice(
            practiceContent: _lesson([
              _mc,
              _image([house, cat]),
            ]),
            practiceVocabItemIdByExerciseId: const {'mc': 'v1', 'ic': 'v2'},
            lessonApi: api,
            audioPlayer: FakeLessonAudioPlayer(),
            feedbackPlayer: FakeAnswerFeedbackPlayer(),
            syncEngine: SyncEngine(
              lessonApi: api,
              connectivityMonitor: connectivity,
              queueStore: FakePendingSyncQueueStore(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(await _requested(house), isTrue);
      expect(await _requested(cat), isTrue);
    });
  });
}
