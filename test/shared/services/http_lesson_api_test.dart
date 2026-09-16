// Tests for `HttpLessonApi`: request shapes sent to `001-lesson-service`,
// response parsing (including the exercise-type/answer-key mapping and the
// startLesson two-call merge), and error mapping (`LessonApiException` for
// non-2xx/network failures, the one sealed `RefillFailure` case).
//
// Uses `package:http/testing.dart`'s `MockClient` rather than a real socket
// -- mocking at the network boundary only, per `coding-standards.md`'s
// testing convention. The session token is supplied via a real
// `SessionRepository` backed by an in-memory storage fake, not mocked
// directly, since it's a plain persistence boundary already covered by its
// own tests.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/shared/models/beans_status.dart';
import 'package:elang/shared/models/exercise.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/models/skill_tree.dart';
import 'package:elang/shared/services/http_lesson_api.dart';
import 'package:elang/shared/services/lesson_api_exception.dart';
import 'package:elang/shared/services/session_repository.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

Future<SessionRepository> _signedInSessionRepository() async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: 'session-token-abc',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    ),
  );
  return repo;
}

void main() {
  group('getSkillTree', () {
    test('parses the full response, including each skill\'s lesson_id', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/skill-tree');
        expect(request.headers['Authorization'], 'Bearer session-token-abc');
        return http.Response(
          jsonEncode({
            'unit_title': 'Unit 1: Foundations & Greetings',
            'unit_subtitle': 'ሰላምታ እና ፊደል መግቢያ',
            'skills': [
              {
                'id': 'skill-a',
                'title': 'Greetings',
                'order_index': 1,
                'state': 'active',
                'crown_level': 0,
                'lesson_id': 'lesson-a1',
              },
              {
                'id': 'skill-b',
                'title': 'Food',
                'order_index': 2,
                'state': 'locked',
                'crown_level': 0,
                'lesson_id': null,
              },
            ],
            'streak_count': 5,
            'beans': 4,
            'beans_max': 5,
            'total_xp': 120,
          }),
          200,
          // `http.Response` derives its encoding from the content-type
          // header, defaulting to latin1 when absent -- this body's
          // Amharic text needs the utf8-implying `application/json` type
          // explicitly, or the mock response itself throws while encoding.
          headers: {'content-type': 'application/json'},
        );
      });
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      final result = await api.getSkillTree();

      expect(result.unitTitle, 'Unit 1: Foundations & Greetings');
      expect(result.streakCount, 5);
      expect(result.beans, 4);
      expect(result.totalXp, 120);
      expect(result.nodes[0].lessonId, 'lesson-a1');
      expect(result.nodes[0].state, SkillNodeState.active);
      // Falls back to the skill's own id when the backend has no lesson
      // for it (shouldn't happen with real content, but must not crash).
      expect(result.nodes[1].lessonId, 'skill-b');
      expect(result.nodes[1].state, SkillNodeState.locked);
    });

    test('a 401 response throws LessonApiException with the error code', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error_code': 'invalid_session', 'message': 'expired'}),
          401,
        ),
      );
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      await expectLater(
        api.getSkillTree(),
        throwsA(isA<LessonApiException>().having((e) => e.errorCode, 'errorCode', 'invalid_session')),
      );
    });

    test('a network-level failure throws LessonApiException', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      await expectLater(api.getSkillTree(), throwsA(isA<LessonApiException>()));
    });

    test('no stored session throws before making any request', () async {
      var requestMade = false;
      final client = MockClient((request) async {
        requestMade = true;
        return http.Response('{}', 200);
      });
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: SessionRepository(storage: InMemorySecureStorageService()),
      );

      await expectLater(api.getSkillTree(), throwsA(isA<LessonApiException>()));
      expect(requestMade, isFalse);
    });
  });

  group('startLesson', () {
    test('merges the lesson-content and beans responses into one LessonContent', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/lessons/lesson-a1') {
          return http.Response(
            jsonEncode({
              'lesson': {
                'id': 'lesson-a1',
                'skill_id': 'skill-a',
                'title': 'Hello',
                'order_index': 1,
              },
              'exercises': [
                {
                  'id': 'ex-1',
                  'order_index': 1,
                  'type': 'multiple_choice',
                  'prompt': "How do you say 'Hello'?",
                  'choices': [
                    {'id': 'a', 'text': 'ሰላም'},
                    {'id': 'b', 'text': 'ደህና ሁን'},
                  ],
                  'correct_choice_id': 'a',
                },
                {
                  'id': 'ex-2',
                  'order_index': 2,
                  'type': 'listening',
                  'prompt': 'What does this word mean?',
                  'audio_url': 'https://cdn.example.com/hello.mp3',
                  'choices': [
                    {'id': 'a', 'text': 'Hello'},
                    {'id': 'b', 'text': 'Goodbye'},
                  ],
                  'correct_choice_id': 'a',
                },
                {
                  'id': 'ex-3',
                  'order_index': 3,
                  'type': 'sentence_construction',
                  'prompt': "Translate: 'I am fine'",
                  'word_bank': [
                    {'id': 'w1', 'text': 'ደህና'},
                    {'id': 'w2', 'text': 'ነኝ'},
                  ],
                  'correct_sequence': ['w1', 'w2'],
                },
                {
                  'id': 'ex-4',
                  'order_index': 4,
                  'type': 'match_pairs',
                  'prompt': 'Match each word to its meaning',
                  'left_tiles': [
                    {'id': 'l1', 'text': 'ቡና'},
                    {'id': 'l2', 'text': 'ሻይ'},
                  ],
                  'right_tiles': [
                    {'id': 'r1', 'text': 'Coffee'},
                    {'id': 'r2', 'text': 'Tea'},
                  ],
                  'correct_pairs': [
                    ['l1', 'r1'],
                    ['l2', 'r2'],
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.url.path, '/api/v1/beans');
        return http.Response(
          jsonEncode({
            'beans': 3,
            'beans_max': 5,
            'next_bean_at': null,
            'regen_minutes_per_bean': 30,
            'amole_balance': 500,
            'refill_cost_amole': 350,
          }),
          200,
        );
      });
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      final content = await api.startLesson('lesson-a1');

      expect(content.lessonId, 'lesson-a1');
      expect(content.beansAtStart, 3);
      expect(content.beansMax, 5);
      expect(content.exercises, hasLength(4));

      final mc = content.exercises[0] as MultipleChoiceExercise;
      expect(mc.prompt, "How do you say 'Hello'?");
      expect(mc.options, ['ሰላም', 'ደህና ሁን']);
      expect(mc.correctOptionIndex, 0);

      final listening = content.exercises[1] as ListeningExercise;
      expect(listening.audioUrl, 'https://cdn.example.com/hello.mp3');
      expect(listening.options, ['Hello', 'Goodbye']);
      expect(listening.correctOptionIndex, 0);

      final sentence = content.exercises[2] as SentenceConstructionExercise;
      expect(sentence.wordBank, ['ደህና', 'ነኝ']);
      expect(sentence.correctSentence, ['ደህና', 'ነኝ']);

      final matchPairs = content.exercises[3] as MatchPairsExercise;
      expect(matchPairs.leftTiles.map((t) => t.text), ['ቡና', 'ሻይ']);
      expect(matchPairs.rightTiles.map((t) => t.text), ['Coffee', 'Tea']);
      expect(matchPairs.correctPairs, {'l1': 'r1', 'l2': 'r2'});
    });

    test('a 404 response throws LessonApiException with lesson_not_found', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error_code': 'lesson_not_found', 'message': 'no such lesson'}),
          404,
        ),
      );
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      await expectLater(
        api.startLesson('does-not-exist'),
        throwsA(isA<LessonApiException>().having((e) => e.errorCode, 'errorCode', 'lesson_not_found')),
      );
    });
  });

  group('completeLesson', () {
    test('posts the correct request body and parses the full response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/lessons/lesson-a1/complete');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['attempt_id'], 'attempt-xyz');
        expect(body['correct_count'], 4);
        expect(body['total_count'], 4);
        expect(body['time_spent_seconds'], 30.0);
        // Bolt 008 made this required backend-side; sent as an ISO 8601
        // string so it round-trips through `DateTime.parse` unambiguously.
        expect(body['client_completed_at'], isA<String>());
        expect(DateTime.tryParse(body['client_completed_at'] as String), isNotNull);
        return http.Response(
          jsonEncode({
            'xp_earned': 20,
            'daily_xp_total': 20,
            'daily_xp_target': 40,
            'streak_count': 3,
            'streak_increased_today': true,
            'accuracy_percent': 100,
            'correct_count': 4,
            'total_count': 4,
            'time_spent_seconds': 30.0,
            'skill_unlocked_title': 'Food & Drink',
            'crown_level': 1,
            'crown_leveled_up': false,
            'streak_freeze_unlocked': false,
          }),
          200,
        );
      });
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      final result = await api.completeLesson(
        lessonId: 'lesson-a1',
        attemptId: 'attempt-xyz',
        correctCount: 4,
        totalCount: 4,
        timeSpent: const Duration(seconds: 30),
        beansRemainingAtEnd: 5,
        clientCompletedAt: DateTime.now().toUtc(),
      );

      expect(result.xpEarned, 20);
      expect(result.skillUnlockedTitle, 'Food & Drink');
      expect(result.crownLevel, 1);
    });

    test('a 422 beans_exhausted response throws LessonApiException', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error_code': 'beans_exhausted', 'message': 'not enough beans'}),
          422,
        ),
      );
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      await expectLater(
        api.completeLesson(
          lessonId: 'lesson-a1',
          attemptId: 'attempt-1',
          correctCount: 0,
          totalCount: 4,
          timeSpent: const Duration(seconds: 10),
          beansRemainingAtEnd: 0,
          clientCompletedAt: DateTime.now().toUtc(),
        ),
        throwsA(isA<LessonApiException>().having((e) => e.errorCode, 'errorCode', 'beans_exhausted')),
      );
    });
  });

  group('getBeansStatus', () {
    test('parses next_bean_at when present', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'beans': 2,
            'beans_max': 5,
            'next_bean_at': '2026-09-16T13:00:00+00:00',
            'regen_minutes_per_bean': 30,
            'amole_balance': 200,
            'refill_cost_amole': 350,
          }),
          200,
        ),
      );
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      final result = await api.getBeansStatus();

      expect(result.beans, 2);
      expect(result.nextBeanAt, DateTime.parse('2026-09-16T13:00:00+00:00'));
    });
  });

  group('refillBeansWithAmole', () {
    test('a 200 response parses into RefillSuccess', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'beans': 5, 'amole_balance': 150}),
          200,
        ),
      );
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      final result = await api.refillBeansWithAmole();

      expect(result, isA<RefillSuccess>());
      expect((result as RefillSuccess).newBeans, 5);
      expect(result.newAmoleBalance, 150);
    });

    test('a 422 insufficient_amole response maps to RefillFailure', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'error_code': 'insufficient_amole', 'message': 'not enough'}),
          422,
        ),
      );
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      final result = await api.refillBeansWithAmole();

      expect(result, isA<RefillFailure>());
      expect((result as RefillFailure).reason, RefillFailureReason.insufficientAmole);
    });

    test('an unexpected error status throws LessonApiException', () async {
      final client = MockClient(
        (request) async => http.Response('Internal Server Error', 500),
      );
      final api = HttpLessonApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionRepository: await _signedInSessionRepository(),
      );

      await expectLater(api.refillBeansWithAmole(), throwsA(isA<LessonApiException>()));
    });
  });
}
