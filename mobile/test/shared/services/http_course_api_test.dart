// Tests for `HttpCourseApi` (010-multi-language-courses, bolt 026): request
// shapes, response parsing and error mapping for the public catalog, the
// signed-in course list, and switching the active course. Mocked at the
// network boundary only.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/shared/models/course.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/course_api.dart';
import 'package:elang/shared/services/http_course_api.dart';
import 'package:elang/shared/services/session_repository.dart';

import '../../helpers/in_memory_secure_storage_service.dart';

const _base = 'http://localhost:8000';

Future<SessionRepository> _signedIn() async {
  final repo = SessionRepository(storage: InMemorySecureStorageService());
  await repo.saveSession(
    SessionState(
      token: 'tok-1',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    ),
  );
  return repo;
}

SessionRepository _signedOut() =>
    SessionRepository(storage: InMemorySecureStorageService());

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _course(
  String id,
  String learning,
  String from, {
  String status = 'available',
  bool active = false,
}) => {
  'id': id,
  'learning_language': learning,
  'from_language': from,
  'title': '$from to $learning',
  'status': status,
  'order_index': 1,
  'is_active': active,
  'completed_skills': 1,
  'total_skills': 4,
};

void main() {
  group('getCatalog', () {
    test(
      'is public: no Authorization header, and parses every course',
      () async {
        final client = MockClient((request) async {
          expect(request.url.toString(), '$_base/api/v1/courses/catalog');
          expect(request.headers.containsKey('Authorization'), isFalse);
          return _json({
            'courses': [
              _course('a', 'am', 'en'),
              _course('b', 'om', 'am', status: 'coming_soon'),
            ],
          });
        });
        final api = HttpCourseApi(
          sessionRepository: _signedOut(),
          client: client,
          baseUrl: _base,
        );

        final courses = await api.getCatalog();

        expect(courses.map((c) => c.id), ['a', 'b']);
        expect(courses[1].status, CourseStatus.comingSoon);
      },
    );

    test('a network failure becomes a CourseApiException', () async {
      final api = HttpCourseApi(
        sessionRepository: _signedOut(),
        client: MockClient((_) async => throw Exception('offline')),
        baseUrl: _base,
      );

      expect(api.getCatalog(), throwsA(isA<CourseApiException>()));
    });

    test('a malformed course entry is rejected', () async {
      final api = HttpCourseApi(
        sessionRepository: _signedOut(),
        client: MockClient(
          (_) async => _json({
            'courses': [
              {'id': 'a'},
            ],
          }),
        ),
        baseUrl: _base,
      );

      expect(api.getCatalog(), throwsA(isA<CourseApiException>()));
    });
  });

  group('getCourses', () {
    test(
      'sends the session token and parses the active course and progress',
      () async {
        final client = MockClient((request) async {
          expect(request.url.toString(), '$_base/api/v1/courses');
          expect(request.headers['Authorization'], 'Bearer tok-1');
          return _json({
            'active_course_id': 'b',
            'courses': [
              _course('a', 'am', 'en'),
              _course('b', 'om', 'am', active: true),
            ],
          });
        });
        final api = HttpCourseApi(
          sessionRepository: await _signedIn(),
          client: client,
          baseUrl: _base,
        );

        final list = await api.getCourses();

        expect(list.activeCourseId, 'b');
        expect(list.activeCourse?.isActive, isTrue);
        expect(list.courses.first.completedSkills, 1);
        expect(list.courses.first.totalSkills, 4);
      },
    );

    test('with no session it fails without calling the network', () async {
      var called = false;
      final api = HttpCourseApi(
        sessionRepository: _signedOut(),
        client: MockClient((_) async {
          called = true;
          return _json({});
        }),
        baseUrl: _base,
      );

      await expectLater(
        api.getCourses(),
        throwsA(
          isA<CourseApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'missing_credentials',
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('a response with no active course id is rejected', () async {
      final api = HttpCourseApi(
        sessionRepository: await _signedIn(),
        client: MockClient((_) async => _json({'courses': []})),
        baseUrl: _base,
      );

      expect(api.getCourses(), throwsA(isA<CourseApiException>()));
    });
  });

  group('switchCourse', () {
    test('PUTs the course id and returns the new course as active', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.toString(), '$_base/api/v1/users/me/active-course');
        expect(request.headers['Authorization'], 'Bearer tok-1');
        expect(jsonDecode(request.body), {'course_id': 'b'});
        return _json({
          'active_course_id': 'b',
          'selected_language': 'om',
          'course': {
            'id': 'b',
            'learning_language': 'om',
            'from_language': 'am',
            'title': 'Amharic to Afaan Oromo',
          },
        });
      });
      final api = HttpCourseApi(
        sessionRepository: await _signedIn(),
        client: client,
        baseUrl: _base,
      );

      final course = await api.switchCourse('b');

      expect(course.id, 'b');
      expect(course.isActive, isTrue);
      expect(course.learningLanguage, 'om');
    });

    test('a coming-soon course surfaces the backend error code', () async {
      final api = HttpCourseApi(
        sessionRepository: await _signedIn(),
        client: MockClient(
          (_) async => _json({
            'error_code': 'course_not_available',
            'message': 'Course is not available yet',
          }, 422),
        ),
        baseUrl: _base,
      );

      await expectLater(
        api.switchCourse('c'),
        throwsA(
          isA<CourseApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'course_not_available',
          ),
        ),
      );
    });

    test('an unknown course is a 404 with its code', () async {
      final api = HttpCourseApi(
        sessionRepository: await _signedIn(),
        client: MockClient(
          (_) async => _json({
            'error_code': 'course_not_found',
            'message': 'No course',
          }, 404),
        ),
        baseUrl: _base,
      );

      await expectLater(
        api.switchCourse('nope'),
        throwsA(
          isA<CourseApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'course_not_found',
          ),
        ),
      );
    });

    test('an unparseable error body still fails cleanly', () async {
      final api = HttpCourseApi(
        sessionRepository: await _signedIn(),
        client: MockClient((_) async => http.Response('oops', 500)),
        baseUrl: _base,
      );

      await expectLater(
        api.switchCourse('b'),
        throwsA(isA<CourseApiException>()),
      );
    });
  });
}
