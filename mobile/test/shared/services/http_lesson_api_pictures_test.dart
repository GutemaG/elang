// HttpLessonApi reading both picture question types
// (019-image-choice-exercise-types, bolt 053): in a lesson and in practice's
// due items, with the answer id turned into an index and local addresses
// resolved against the API. A type this build does not know is still
// skipped and counted.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/http_lesson_api.dart';
import 'package:elang/shared/services/session_repository.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

Future<SessionRepository> _signedIn() async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: 'session-token-abc',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    ),
  );
  return repo;
}

/// The response shapes of bolt 050's `ImageChoiceExerciseResponse` and
/// `AudioImageChoiceExerciseResponse`.
Map<String, Object?> _imageChoice({String id = 'ex-img'}) => {
  'id': id,
  'order_index': 1,
  'type': 'image_choice',
  'prompt': "Choose the picture: 'ውሻ'",
  'choices': [
    {
      'id': 'p-cat',
      'image_url': '/media/images/samples/cat.webp',
      'alt_text': 'A cat',
    },
    {
      'id': 'p-dog',
      'image_url': 'https://pub.r2.dev/images/lesson-1/dog.webp',
      'alt_text': 'A dog',
    },
    {
      'id': 'p-sun',
      'image_url': '/media/images/samples/sun.webp',
      'alt_text': 'The sun',
    },
  ],
  'correct_choice_id': 'p-dog',
};

Map<String, Object?> _audioImageChoice() => {
  'id': 'ex-aud',
  'order_index': 2,
  'type': 'audio_image_choice',
  'prompt': 'Tap the picture you hear',
  'audio_url': '/media/audio/am/one.m4a',
  'choices': [
    {
      'id': 'a',
      'image_url': '/media/images/samples/number-2.webp',
      'alt_text': 'The number 2',
    },
    {
      'id': 'b',
      'image_url': '/media/images/samples/number-5.webp',
      'alt_text': 'The number 5',
    },
    {
      'id': 'c',
      'image_url': '/media/images/samples/number-10.webp',
      'alt_text': 'The number 10',
    },
    {
      'id': 'd',
      'image_url': '/media/images/samples/number-1.webp',
      'alt_text': 'The number 1',
    },
  ],
  'correct_choice_id': 'd',
};

const _beans = {
  'beans': 5,
  'beans_max': 5,
  'next_bean_at': null,
  'regen_minutes_per_bean': 30,
  'amole_balance': 0,
  'refill_cost_amole': 350,
};

Future<HttpLessonApi> _apiServing(
  List<Map<String, Object?>> exercises, {
  String baseUrl = 'http://localhost:8000',
}) async {
  final client = MockClient((request) async {
    if (request.url.path == '/api/v1/beans') {
      return http.Response(jsonEncode(_beans), 200);
    }
    return http.Response(
      jsonEncode({
        'lesson': {
          'id': 'lesson-1',
          'skill_id': 'skill-1',
          'title': 'Pictures',
          'order_index': 1,
        },
        'exercises': exercises,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return HttpLessonApi(
    client: client,
    baseUrl: baseUrl,
    sessionRepository: await _signedIn(),
  );
}

void main() {
  group('startLesson', () {
    test('an image choice question keeps its prompt, its pictures in order, '
        'and the answer as an index', () async {
      final api = await _apiServing([_imageChoice()]);

      final content = await api.startLesson('lesson-1');

      final exercise = content.exercises.single as ImageChoiceExercise;
      expect(exercise.id, 'ex-img');
      expect(exercise.prompt, "Choose the picture: 'ውሻ'");
      expect(exercise.choices.map((c) => c.altText), [
        'A cat',
        'A dog',
        'The sun',
      ]);
      expect(exercise.correctOptionIndex, 1);
      expect(isAnswerCorrect(exercise, 1), isTrue);
      expect(isAnswerCorrect(exercise, 0), isFalse);
      expect(content.unrenderableCount, 0);
    });

    test('an audio image choice question keeps its instruction, clip and '
        'pictures', () async {
      final api = await _apiServing([_audioImageChoice()]);

      final content = await api.startLesson('lesson-1');

      final exercise = content.exercises.single as AudioImageChoiceExercise;
      expect(exercise.instruction, 'Tap the picture you hear');
      expect(exercise.audioUrl, 'http://localhost:8000/media/audio/am/one.m4a');
      expect(exercise.choices, hasLength(4));
      expect(exercise.correctOptionIndex, 3);
      expect(isAnswerCorrect(exercise, 3), isTrue);
      expect(isAnswerCorrect(exercise, 0), isFalse);
    });

    test('a local /media picture resolves against the API; an https one is '
        'kept as it is', () async {
      final api = await _apiServing([
        _imageChoice(),
      ], baseUrl: 'https://ethio-lang.vercel.app');

      final content = await api.startLesson('lesson-1');

      final urls = (content.exercises.single as ImageChoiceExercise).choices
          .map((c) => c.imageUrl);
      expect(urls, [
        'https://ethio-lang.vercel.app/media/images/samples/cat.webp',
        'https://pub.r2.dev/images/lesson-1/dog.webp',
        'https://ethio-lang.vercel.app/media/images/samples/sun.webp',
      ]);
    });

    test('a listening clip still resolves the same way', () async {
      final api = await _apiServing([
        {
          'id': 'ex-li',
          'order_index': 1,
          'type': 'listening',
          'prompt': 'Tap what you hear',
          'audio_url': '/media/audio/am/hello.m4a',
          'choices': [
            {'id': 'a', 'text': 'ሰላም'},
          ],
          'correct_choice_id': 'a',
        },
      ], baseUrl: 'https://ethio-lang.vercel.app');

      final content = await api.startLesson('lesson-1');

      expect(
        (content.exercises.single as ListeningExercise).audioUrl,
        'https://ethio-lang.vercel.app/media/audio/am/hello.m4a',
      );
    });

    test('beside both picture types, a type invented later is skipped and '
        'counted, and the rest keep their order', () async {
      final api = await _apiServing([
        _imageChoice(),
        {
          'id': 'ex-future',
          'order_index': 2,
          'type': 'video_choice',
          'prompt': 'Watch, then choose',
          'video_url': '/media/video/1.mp4',
        },
        _audioImageChoice(),
      ]);

      final content = await api.startLesson('lesson-1');

      expect(content.exercises.map((e) => e.id), ['ex-img', 'ex-aud']);
      expect(content.unrenderableCount, 1);
    });
  });

  group('getDueItems', () {
    test(
      'a due word asked as a picture question comes with its pictures',
      () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/v1/practice/due-items');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'vocab_item_id': 'vocab-dog',
                  'word': 'ውሻ',
                  'translation': 'Dog',
                  'exercise': _imageChoice(id: 'ex-due'),
                  'box_level': 1,
                  'next_review_at': '2026-09-25T00:00:00Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final api = HttpLessonApi(
          client: client,
          baseUrl: 'http://localhost:8000',
          sessionRepository: await _signedIn(),
        );

        final item = (await api.getDueItems()).single;

        expect(item.vocabItemId, 'vocab-dog');
        final exercise = item.exercise as ImageChoiceExercise;
        expect(exercise.id, 'ex-due');
        expect(exercise.correctOptionIndex, 1);
        expect(
          exercise.choices.first.imageUrl,
          'http://localhost:8000/media/images/samples/cat.webp',
        );
      },
    );
  });
}
