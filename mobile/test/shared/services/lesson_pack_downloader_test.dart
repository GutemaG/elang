// LessonPackDownloader tests (009-offline-caching-and-sync-ui, story 001).
//
// Covers: a lesson with no listening exercises downloads without any HTTP
// audio fetch; a lesson with a listening exercise downloads its audio and
// rewrites the exercise's `audioUrl` to the saved local file path; a
// failure fetching the lesson itself, and a failure downloading its audio,
// both land the lesson in `failed` status with nothing persisted;
// `refreshDownloadedStatuses` reflects packs already on disk from a
// previous session.
//
// `path_provider`'s platform channel is swapped for a fake pointing at a
// real temp directory (not further mocked) -- this is the plugin boundary,
// per `coding-standards.md`'s "mock at the network/DB boundary only"
// convention, and it lets the audio-file-write path run for real.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/lesson_pack_downloader.dart';

import '../../helpers/controllable_lesson_api.dart';
import '../../helpers/fake_lesson_pack_store.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

const _mcOnly = LessonContent(
  lessonId: 'lesson-mc',
  skillId: 'skill-mc',
  title: 'MC Lesson',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    MultipleChoiceExercise(
      id: 'mc-1',
      prompt: 'ሀ',
      promptTranslation: 'Which sound?',
      options: ['ha', 'le'],
      correctOptionIndex: 0,
    ),
  ],
);

const _matchPairsOnly = LessonContent(
  lessonId: 'lesson-mp',
  skillId: 'skill-mp',
  title: 'Match Pairs Lesson',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    MatchPairsExercise(
      id: 'mp-1',
      prompt: 'Match each word to its meaning',
      leftTiles: [MatchPairsTile(id: 'l1', text: 'ቡና'), MatchPairsTile(id: 'l2', text: 'ሻይ')],
      rightTiles: [MatchPairsTile(id: 'r1', text: 'Coffee'), MatchPairsTile(id: 'r2', text: 'Tea')],
      correctPairs: {'l1': 'r1', 'l2': 'r2'},
    ),
  ],
);

const _withAudio = LessonContent(
  lessonId: 'lesson-mixed',
  skillId: 'skill-mixed',
  title: 'Mixed Lesson',
  beansAtStart: 5,
  beansMax: 5,
  exercises: [
    ListeningExercise(
      id: 'listen-1',
      audioUrl: 'https://cdn.buna.app/audio/test.mp3',
      instruction: 'Tap what you hear',
      options: ['ሰላም', 'ደህና'],
      correctOptionIndex: 0,
    ),
  ],
);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lesson_pack_downloader_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a lesson with no listening exercises downloads with zero HTTP audio calls', () async {
    final api = ControllableLessonApi()..lessonContent = _mcOnly;
    final packStore = FakeLessonPackStore();
    var httpCalls = 0;
    final downloader = LessonPackDownloader(
      lessonApi: api,
      packStore: packStore,
      httpClient: MockClient((request) async {
        httpCalls++;
        return http.Response('', 200);
      }),
    );

    await downloader.downloadLesson('lesson-mc');

    expect(downloader.statusFor('lesson-mc'), LessonDownloadStatus.downloaded);
    expect(httpCalls, 0);
    final saved = await packStore.load('lesson-mc');
    expect(saved, isNotNull);
    expect(saved!.exercises, hasLength(1));
  });

  test(
    // 004-match-pairs-exercise-type, story 002: proves a match_pairs
    // exercise downloads through the unmodified downloader path (it only
    // special-cases `ListeningExercise`) with zero HTTP calls, rather than
    // assuming this from the downloader's design.
    'a lesson with only a match_pairs exercise downloads with zero HTTP calls',
    () async {
      final api = ControllableLessonApi()..lessonContent = _matchPairsOnly;
      final packStore = FakeLessonPackStore();
      var httpCalls = 0;
      final downloader = LessonPackDownloader(
        lessonApi: api,
        packStore: packStore,
        httpClient: MockClient((request) async {
          httpCalls++;
          return http.Response('', 200);
        }),
      );

      await downloader.downloadLesson('lesson-mp');

      expect(downloader.statusFor('lesson-mp'), LessonDownloadStatus.downloaded);
      expect(httpCalls, 0);
      final saved = await packStore.load('lesson-mp');
      final exercise = saved!.exercises.single as MatchPairsExercise;
      expect(exercise.correctPairs, {'l1': 'r1', 'l2': 'r2'});
    },
  );

  test(
    'a lesson with a listening exercise downloads its audio and rewrites audioUrl to the local file',
    () async {
      final api = ControllableLessonApi()..lessonContent = _withAudio;
      final packStore = FakeLessonPackStore();
      final downloader = LessonPackDownloader(
        lessonApi: api,
        packStore: packStore,
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'https://cdn.buna.app/audio/test.mp3');
          return http.Response.bytes([1, 2, 3, 4], 200);
        }),
      );

      await downloader.downloadLesson('lesson-mixed');

      expect(downloader.statusFor('lesson-mixed'), LessonDownloadStatus.downloaded);
      final saved = await packStore.load('lesson-mixed');
      final exercise = saved!.exercises.single as ListeningExercise;
      expect(exercise.audioUrl, isNot(startsWith('http')));
      expect(exercise.audioUrl, contains(tempDir.path));
      final file = File(exercise.audioUrl);
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), [1, 2, 3, 4]);
    },
  );

  test('a failure fetching the lesson itself leaves it failed with nothing saved', () async {
    final api = ControllableLessonApi()..startLessonError = Exception('network down');
    final packStore = FakeLessonPackStore();
    final downloader = LessonPackDownloader(lessonApi: api, packStore: packStore);

    await downloader.downloadLesson('lesson-mc');

    expect(downloader.statusFor('lesson-mc'), LessonDownloadStatus.failed);
    expect(await packStore.load('lesson-mc'), isNull);
  });

  test('a non-200 audio download leaves the lesson failed with nothing saved', () async {
    final api = ControllableLessonApi()..lessonContent = _withAudio;
    final packStore = FakeLessonPackStore();
    final downloader = LessonPackDownloader(
      lessonApi: api,
      packStore: packStore,
      httpClient: MockClient((request) async => http.Response('not found', 404)),
    );

    await downloader.downloadLesson('lesson-mixed');

    expect(downloader.statusFor('lesson-mixed'), LessonDownloadStatus.failed);
    expect(await packStore.load('lesson-mixed'), isNull);
  });

  test(
    // Dropping it made an offline completion of this lesson report a short
    // `total_count`, which the server rejects -- so it could never sync.
    'rewriting audio keeps the count of exercises this build skipped',
    () async {
      final api = ControllableLessonApi()
        ..lessonContent = LessonContent(
          lessonId: _withAudio.lessonId,
          skillId: _withAudio.skillId,
          title: _withAudio.title,
          beansAtStart: 5,
          beansMax: 5,
          exercises: _withAudio.exercises,
          unrenderableCount: 2,
        );
      final packStore = FakeLessonPackStore();
      final downloader = LessonPackDownloader(
        lessonApi: api,
        packStore: packStore,
        httpClient: MockClient(
          (request) async => http.Response.bytes([1, 2, 3], 200),
        ),
      );

      await downloader.downloadLesson('lesson-mixed');

      final saved = await packStore.load('lesson-mixed');
      expect(saved!.unrenderableCount, 2);
    },
  );

  test('statusFor defaults to notDownloaded for a lesson never touched', () async {
    final downloader = LessonPackDownloader(
      lessonApi: ControllableLessonApi(),
      packStore: FakeLessonPackStore(),
    );

    expect(downloader.statusFor('unknown-lesson'), LessonDownloadStatus.notDownloaded);
  });

  test('refreshDownloadedStatuses reflects packs already saved from a previous session', () async {
    final packStore = FakeLessonPackStore();
    await packStore.save(_mcOnly);
    final downloader = LessonPackDownloader(
      lessonApi: ControllableLessonApi(),
      packStore: packStore,
    );
    expect(downloader.statusFor('lesson-mc'), LessonDownloadStatus.notDownloaded);

    await downloader.refreshDownloadedStatuses();

    expect(downloader.statusFor('lesson-mc'), LessonDownloadStatus.downloaded);
  });
}
