// `HttpLessonApi`'s streak and Amole reads (013-stat-pill-interactions,
// bolt 061), against `MockClient` at the network boundary, as the other
// HTTP tests do.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/models/stat_history.dart';
import 'package:elang/shared/services/http_lesson_api.dart';
import 'package:elang/shared/services/lesson_api_exception.dart';
import 'package:elang/shared/services/session_repository.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

Future<HttpLessonApi> _api(MockClient client) async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: 'session-token-abc',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    ),
  );
  return HttpLessonApi(
    client: client,
    baseUrl: 'http://localhost:8000',
    sessionRepository: repo,
  );
}

void main() {
  group('getStreakHistory', () {
    test('asks for the UTC days and parses the answer', () async {
      final api = await _api(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/streak/history');
          expect(request.url.queryParameters, {
            'from': '2026-04-01',
            'to': '2026-09-30',
          });
          expect(request.headers['Authorization'], 'Bearer session-token-abc');
          return http.Response(
            jsonEncode({
              'from': '2026-04-01',
              'to': '2026-09-30',
              'practised_days': ['2026-09-28', '2026-09-29'],
              'current_streak': 2,
              'longest_streak': 9,
              'joined_on': '2026-03-14',
            }),
            200,
          );
        }),
      );

      final history = await api.getStreakHistory(
        from: DateTime.utc(2026, 4, 1),
        // A moment late in the day still asks for that day.
        to: DateTime.utc(2026, 9, 30, 23, 59),
      );

      expect(history.practised(DateTime.utc(2026, 9, 28)), isTrue);
      expect(history.practised(DateTime.utc(2026, 9, 29, 18)), isTrue);
      expect(history.practised(DateTime.utc(2026, 9, 27)), isFalse);
      expect(history.currentStreak, 2);
      expect(history.longestStreak, 9);
      expect(history.joinedOn, DateTime.utc(2026, 3, 14));
    });

    test('an error answer throws', () async {
      final api = await _api(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'error_code': 'invalid_range', 'message': 'x'}),
            422,
          ),
        ),
      );

      expect(
        api.getStreakHistory(
          from: DateTime.utc(2026, 9, 2),
          to: DateTime.utc(2026, 9, 1),
        ),
        throwsA(isA<LessonApiException>()),
      );
    });
  });

  group('getAmoleHistory', () {
    test('asks for the limit and parses each entry', () async {
      final api = await _api(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/amole/transactions');
          expect(request.url.queryParameters, {'limit': '5'});
          return http.Response(
            jsonEncode({
              'entries': [
                {
                  'amount': -350,
                  'source': 'bean_refill',
                  'created_at': '2026-09-30T06:00:00+00:00',
                },
                {'amount': 'broken'},
                {
                  'amount': 10,
                  'source': 'lesson_completion',
                  'created_at': '2026-09-29T06:00:00+00:00',
                },
              ],
            }),
            200,
          );
        }),
      );

      final entries = await api.getAmoleHistory(limit: 5);

      expect([for (final e in entries) e.amount], [-350, 10]);
      expect(entries.first.reason, 'Bean refill');
      expect(entries.first.createdAt, DateTime.utc(2026, 9, 30, 6));
    });

    test('a network failure throws', () async {
      final api = await _api(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      expect(api.getAmoleHistory(), throwsA(isA<LessonApiException>()));
    });
  });

  group('models', () {
    test('every ledger source has a reason, and a new one reads "Amole"', () {
      AmoleEntry entry(String source) =>
          AmoleEntry(amount: 1, source: source, createdAt: DateTime.utc(2026));
      expect(entry('wallet_created').reason, 'Welcome bonus');
      expect(entry('migration_backfill').reason, 'Starting balance');
      expect(entry('lesson_completion').reason, 'Lesson finished');
      expect(entry('perfect_lesson').reason, 'Perfect lesson');
      expect(entry('streak_milestone_7').reason, '7-day streak');
      expect(entry('streak_milestone_30').reason, '30-day streak');
      expect(entry('bean_refill').reason, 'Bean refill');
      expect(entry('practice_session').reason, 'Practice session');
      expect(entry('from_the_future').reason, 'Amole');
    });

    test('malformed shapes read as null', () {
      expect(StreakHistory.fromJson(null), isNull);
      expect(
        StreakHistory.fromJson(<String, dynamic>{'current_streak': 1}),
        isNull,
      );
      expect(AmoleEntry.fromJson('x'), isNull);
    });

    test('a bad day in the list is skipped, not fatal', () {
      final history = StreakHistory.fromJson(<String, dynamic>{
        'practised_days': ['2026-09-01', 'not a day', 3],
        'current_streak': 1,
        'longest_streak': 1,
        'joined_on': '2026-01-01',
      })!;
      expect(history.practisedDays, {DateTime.utc(2026, 9, 1)});
    });
  });
}
