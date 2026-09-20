import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/auth_config.dart';
import '../models/course.dart';
import 'course_api.dart';
import 'session_repository.dart';

/// Real, HTTP-backed [CourseApi] calling `GET /api/v1/courses/catalog`
/// (public), `GET /api/v1/courses` and `PUT /api/v1/users/me/active-course`.
///
/// The catalog needs no session; the other two read the token fresh from
/// [SessionRepository] on every call, like [HttpLessonApi]. Never logs
/// tokens, request bodies, or response bodies.
class HttpCourseApi implements CourseApi {
  HttpCourseApi({
    required SessionRepository sessionRepository,
    http.Client? client,
    String? baseUrl,
  }) : _sessionRepository = sessionRepository,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AuthConfig.apiBaseUrl;

  final SessionRepository _sessionRepository;
  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final session = await _sessionRepository.getSessionState();
    final token = session.token;
    if (token == null || token.isEmpty) {
      throw const CourseApiException(
        'No session token available',
        errorCode: 'missing_credentials',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  @override
  Future<List<Course>> getCatalog() async {
    final json = _decodeOrThrow(
      await _send(() => _client.get(_uri('/catalog'))),
    );
    return _parseCourses(json['courses']);
  }

  @override
  Future<CourseList> getCourses() async {
    final headers = await _authHeaders();
    final json = _decodeOrThrow(
      await _send(() => _client.get(_uri(''), headers: headers)),
    );
    final activeCourseId = json['active_course_id'];
    if (activeCourseId is! String) {
      throw const CourseApiException('Malformed response body');
    }
    return CourseList(
      activeCourseId: activeCourseId,
      courses: _parseCourses(json['courses']),
    );
  }

  @override
  Future<Course> switchCourse(String courseId) async {
    final headers = await _authHeaders();
    final json = _decodeOrThrow(
      await _send(
        () => _client.put(
          Uri.parse('$_baseUrl/api/v1/users/me/active-course'),
          headers: headers,
          body: jsonEncode({'course_id': courseId}),
        ),
      ),
    );
    final raw = json['course'];
    final course = raw is Map<String, dynamic> ? Course.fromJson(raw) : null;
    if (course == null) {
      throw const CourseApiException('Malformed response body');
    }
    return course.copyWith(isActive: true);
  }

  Uri _uri(String suffix) => Uri.parse('$_baseUrl/api/v1/courses$suffix');

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on Object {
      throw const CourseApiException('Network request failed');
    }
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    if (response.statusCode != 200) {
      throw _errorFrom(response);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Fall through to the malformed-body exception below.
    }
    throw const CourseApiException('Malformed response body');
  }

  List<Course> _parseCourses(Object? raw) {
    if (raw is! List) {
      throw const CourseApiException('Malformed response body');
    }
    final courses = <Course>[];
    for (final item in raw) {
      final course = item is Map<String, dynamic>
          ? Course.fromJson(item)
          : null;
      if (course == null) {
        throw const CourseApiException('Malformed response body');
      }
      courses.add(course);
    }
    return courses;
  }

  CourseApiException _errorFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final errorCode = decoded['error_code'];
        final message = decoded['message'];
        return CourseApiException(
          message is String
              ? message
              : 'Request failed (${response.statusCode})',
          errorCode: errorCode is String ? errorCode : null,
        );
      }
    } on FormatException {
      // Fall through to the generic exception below.
    }
    return CourseApiException('Request failed (${response.statusCode})');
  }
}
