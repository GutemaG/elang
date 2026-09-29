// A lesson's clips and pictures (bolt 057): they are fetched ahead as soon
// as the lesson's content is known, in question order, and online a
// downloaded lesson of the same version plays its own files instead of
// fetching them again.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elang/features/lesson/screens/lesson_screen.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/lesson_content.dart';
import 'package:elang/shared/services/sync_engine.dart';

import '../../../helpers/controllable_lesson_api.dart';
import '../../../helpers/fake_answer_feedback_player.dart';
import '../../../helpers/fake_connectivity_monitor.dart';
import '../../../helpers/fake_lesson_audio_player.dart';
import '../../../helpers/fake_lesson_pack_store.dart';
import '../../../helpers/fake_media_cache.dart';
import '../../../helpers/fake_pending_sync_queue_store.dart';

const _cdn = 'https://pub.r2.dev';

ListeningExercise _listen(String clip) => ListeningExercise(
  id: 'li-1',
  audioUrl: clip,
  instruction: 'Tap what you hear',
  options: const ['ሰላም', 'ደህና'],
  correctOptionIndex: 0,
);

const _mc = MultipleChoiceExercise(
  id: 'mc-1',
  prompt: 'ቡና',
  promptTranslation: 'What does this word mean?',
  options: ['Coffee', 'Tea'],
  correctOptionIndex: 0,
);

ImageChoiceExercise _image(List<String> pictures) => ImageChoiceExercise(
  id: 'ic-1',
  prompt: "Choose the picture: 'ውሻ'",
  choices: [for (final p in pictures) PictureChoice(imageUrl: p, altText: p)],
  correctOptionIndex: 0,
);

AudioImageChoiceExercise _audioImage(String clip, List<String> pictures) =>
    AudioImageChoiceExercise(
      id: 'aic-1',
      audioUrl: clip,
      instruction: 'Tap the picture you hear',
      choices: [
        for (final p in pictures) PictureChoice(imageUrl: p, altText: p),
      ],
      correctOptionIndex: 0,
    );

LessonContent _lesson(List<Exercise> exercises, {DateTime? version}) =>
    LessonContent(
      lessonId: 'l-1',
      skillId: 's-1',
      title: 'Greetings',
      beansAtStart: 5,
      beansMax: 5,
      exercises: exercises,
      contentVersion: version,
    );

final _v1 = DateTime.utc(2026, 9, 1);
final _v2 = DateTime.utc(2026, 9, 2);

class _Rig {
  _Rig(LessonContent served)
    : api = ControllableLessonApi()..lessonContent = served;

  final ControllableLessonApi api;
  final audio = FakeLessonAudioPlayer();
  final media = FakeMediaCache();
  final packs = FakeLessonPackStore();

  Widget build() {
    final connectivity = FakeConnectivityMonitor();
    return MaterialApp(
      home: LessonScreen(
        lessonId: 'l-1',
        lessonApi: api,
        audioPlayer: audio,
        feedbackPlayer: FakeAnswerFeedbackPlayer(),
        connectivityMonitor: connectivity,
        lessonPackStore: packs,
        syncEngine: SyncEngine(
          lessonApi: api,
          connectivityMonitor: connectivity,
          queueStore: FakePendingSyncQueueStore(),
        ),
        mediaCache: media,
      ),
    );
  }
}

void main() {
  testWidgets('opening a lesson fetches its clips and pictures ahead, '
      'in question order', (tester) async {
    final rig = _Rig(
      _lesson([
        _listen('$_cdn/a/selam.mp3'),
        _mc,
        _image(['$_cdn/p/dog.webp', '$_cdn/p/cat.webp']),
        _audioImage('$_cdn/a/dog.mp3', ['$_cdn/p/dog.webp', '$_cdn/p/sun.png']),
      ]),
    );

    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    expect(rig.media.warmed, [
      [
        '$_cdn/a/selam.mp3',
        '$_cdn/p/dog.webp',
        '$_cdn/p/cat.webp',
        '$_cdn/a/dog.mp3',
        '$_cdn/p/dog.webp',
        '$_cdn/p/sun.png',
      ],
    ]);
    // The first question's clip still plays on its own.
    expect(rig.audio.playedUrls, ['$_cdn/a/selam.mp3']);
  });

  testWidgets('a lesson with no clips or pictures fetches nothing ahead', (
    tester,
  ) async {
    final rig = _Rig(_lesson([_mc]));

    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    expect(rig.media.warmed, [<String>[]]);
  });

  testWidgets('online, a downloaded lesson of the same version plays its '
      'own files', (tester) async {
    const local = '/data/lesson_packs/l-1/li-1.mp3';
    final rig = _Rig(_lesson([_listen('$_cdn/a/selam.mp3')], version: _v1));
    await rig.packs.save(_lesson([_listen(local)], version: _v1));

    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    expect(rig.audio.playedUrls, [local]);
    expect(rig.media.warmed, [
      [local],
    ]);
  });

  testWidgets('online, a downloaded lesson of an older version is not '
      'played', (tester) async {
    final rig = _Rig(_lesson([_listen('$_cdn/a/new.mp3')], version: _v2));
    await rig.packs.save(
      _lesson([_listen('/data/lesson_packs/l-1/li-1.mp3')], version: _v1),
    );

    await tester.pumpWidget(rig.build());
    await tester.pumpAndSettle();

    expect(rig.audio.playedUrls, ['$_cdn/a/new.mp3']);
  });
}
