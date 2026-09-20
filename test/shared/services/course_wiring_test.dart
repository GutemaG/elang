// Small wiring tests for 010-multi-language-courses (bolt 026): the skill
// tree's `course`, the session user's `active_course_id`, and the pending
// onboarding selection carrying both languages through storage and to the
// sign-in request.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/shared/models/pending_onboarding_selection.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/auth_api.dart';
import 'package:elang/shared/services/http_auth_api.dart';
import 'package:elang/shared/services/http_lesson_api.dart';
import 'package:elang/shared/services/onboarding_repository.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

Future<SessionRepository> _signedIn() async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: 'tok',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    ),
  );
  return repo;
}

Map<String, dynamic> _treeBody({Map<String, dynamic>? course}) => {
  'unit_title': 'U',
  'unit_subtitle': 's',
  'categories': [
    {'id': 'cat', 'title': 'Foundations', 'subtitle': 's', 'order_index': 1},
  ],
  if (course != null) 'course': course,
  'skills': [
    {
      'id': 'skill',
      'title': 'Greetings',
      'order_index': 1,
      'category_id': 'cat',
      'state': 'active',
      'crown_level': 0,
      'lesson_id': 'lesson',
    },
  ],
  'streak_count': 1,
  'beans': 5,
  'beans_max': 5,
  'total_xp': 3,
};

void main() {
  group('skill tree course', () {
    test('is parsed from the tree response', () async {
      final api = HttpLessonApi(
        sessionRepository: await _signedIn(),
        baseUrl: 'http://x',
        client: MockClient(
          (_) async => _json(
            _treeBody(
              course: {
                'id': 'c-om',
                'learning_language': 'om',
                'from_language': 'am',
                'title': 'Amharic to Afaan Oromo',
              },
            ),
          ),
        ),
      );

      final tree = await api.getSkillTree();

      expect(tree.course?.id, 'c-om');
      expect(tree.course?.learningLanguage, 'om');
      expect(tree.course?.fromLanguage, 'am');
    });

    test('is null for an older backend that sends none', () async {
      final api = HttpLessonApi(
        sessionRepository: await _signedIn(),
        baseUrl: 'http://x',
        client: MockClient((_) async => _json(_treeBody())),
      );

      expect((await api.getSkillTree()).course, isNull);
    });
  });

  group('session user active course', () {
    Future<SessionCheckResult> check(Map<String, dynamic> user) {
      return SessionApi(
        baseUrl: 'http://x',
        client: MockClient((_) async => _json({'valid': true, 'user': user})),
      ).checkSession('tok');
    }

    test('is read when the backend sends it', () async {
      final result = await check({
        'id': 'u',
        'selected_language': 'om',
        'daily_xp_target': 40,
        'notification_enabled': true,
        'active_course_id': 'c-om',
      });

      expect(result.user?.activeCourseId, 'c-om');
    });

    test('is null when an older backend does not', () async {
      final result = await check({
        'id': 'u',
        'selected_language': 'am',
        'daily_xp_target': 40,
        'notification_enabled': true,
      });

      expect(result.status, SessionCheckStatus.valid);
      expect(result.user?.activeCourseId, isNull);
    });
  });

  group('onboarding pair to sign-in', () {
    test('both languages persist and are read back', () async {
      final repo = OnboardingRepository(
        storage: InMemorySecureStorageService(),
      );

      await repo.selectLanguage('om', fromLanguageCode: 'am');
      expect(await repo.loadPendingSelection(), isNull); // goal still unknown
      await repo.selectDailyGoal(15);

      final pending = (await repo.loadPendingSelection())!;
      expect(pending.languageCode, 'om');
      expect(pending.fromLanguageCode, 'am');
      expect(pending.dailyGoalMinutes, 15);
    });

    test('a selection without a from-language defaults to English', () async {
      final repo = OnboardingRepository(
        storage: InMemorySecureStorageService(),
      );

      await repo.selectLanguage('am');
      await repo.selectDailyGoal(10);

      expect((await repo.loadPendingSelection())!.fromLanguageCode, 'en');
    });

    test('the sign-in request carries the chosen from-language', () async {
      Map<String, dynamic>? sent;
      final api = HttpAuthApi(
        baseUrl: 'http://x',
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({
            'session_token': 't',
            'expires_at': '2026-10-01T00:00:00.000Z',
          });
        }),
      );

      final result = await api.signInWithGoogle(
        idToken: 'g',
        pendingSelection: const PendingOnboardingSelection(
          languageCode: 'om',
          fromLanguageCode: 'am',
          dailyGoalMinutes: 10,
        ),
      );

      expect(result, isA<AuthSuccess>());
      expect(sent!['pending_selection'], {
        'language': 'om',
        'from_language': 'am',
        'daily_goal_minutes': 10,
      });
    });
  });
}
