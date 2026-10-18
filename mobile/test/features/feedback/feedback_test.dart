// "Send feedback" (027-learner-feedback): the request the app sends, the
// screen that writes it, and the Settings row that opens it.

import 'dart:convert';

import 'package:elang/features/feedback/feedback_api.dart';
import 'package:elang/features/feedback/feedback_screen.dart';
import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:elang/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_user_preferences_api.dart';
import '../../helpers/in_memory_secure_storage_service.dart';

Future<SessionRepository> _signedIn() async {
  final sessions = SessionRepository(storage: InMemorySecureStorageService());
  await sessions.saveSession(
    SessionState(
      token: 'tok',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      authProvider: 'google',
    ),
  );
  return sessions;
}

class _FakeFeedbackApi implements FeedbackApi {
  final sent = <Map<String, Object?>>[];
  FeedbackApiException? failWith;

  @override
  Future<void> send({
    required FeedbackCategory category,
    required String message,
    int? rating,
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    sent.add({'category': category, 'message': message, 'rating': rating});
  }
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

/// Scrolls [finder] into view first: the form is taller than the test
/// screen.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

AppButton _sendButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.byKey(FeedbackScreen.sendKey));

void main() {
  group('HttpFeedbackApi', () {
    test('posts the category, message, rating and platform', () async {
      late http.Request seen;
      final api = HttpFeedbackApi(
        sessionRepository: await _signedIn(),
        baseUrl: 'https://api.test',
        platform: 'android',
        client: MockClient((request) async {
          seen = request;
          return http.Response('{"id": "f1"}', 201);
        }),
      );

      await api.send(
        category: FeedbackCategory.content,
        message: 'Wrong word',
        rating: 4,
      );

      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://api.test/api/v1/feedback');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(seen.body), {
        'category': 'content',
        'message': 'Wrong word',
        'rating': 4,
        'platform': 'android',
      });
    });

    test('offline, an error or too many throws, and says which', () async {
      final sessions = await _signedIn();
      Future<FeedbackApiException> failure(MockClient client) async {
        final api = HttpFeedbackApi(
          sessionRepository: sessions,
          baseUrl: 'https://api.test',
          client: client,
        );
        try {
          await api.send(category: FeedbackCategory.bug, message: 'x');
        } on FeedbackApiException catch (e) {
          return e;
        }
        fail('did not throw');
      }

      expect(
        (await failure(
          MockClient((_) async => throw http.ClientException('offline')),
        )).tooMany,
        isFalse,
      );
      expect(
        (await failure(MockClient((_) async => http.Response('{}', 422))))
            .tooMany,
        isFalse,
      );
      expect(
        (await failure(MockClient((_) async => http.Response('{}', 429))))
            .tooMany,
        isTrue,
      );
    });
  });

  group('FeedbackScreen', () {
    testWidgets('sends once a kind is picked and a message written', (
      tester,
    ) async {
      final api = _FakeFeedbackApi();
      await tester.pumpWidget(_app(FeedbackScreen(api: api)));

      expect(_sendButton(tester).onPressed, isNull);
      await _tap(tester, find.text('A lesson mistake'));
      await tester.pump();
      expect(
        find.text(
          'Which lesson, and what is wrong: a word, a translation, the audio?',
        ),
        findsOneWidget,
      );
      expect(_sendButton(tester).onPressed, isNull);

      await tester.ensureVisible(find.byKey(FeedbackScreen.messageKey));
      await tester.enterText(
        find.byKey(FeedbackScreen.messageKey),
        '  "Selam" is spelt wrong  ',
      );
      await _tap(tester, find.byTooltip('Rate 4 out of 5'));
      await tester.pump();
      expect(find.text('4 / 5'), findsOneWidget);

      await tester.tap(find.byKey(FeedbackScreen.sendKey));
      await tester.pumpAndSettle();

      expect(api.sent, [
        {
          'category': FeedbackCategory.content,
          'message': '"Selam" is spelt wrong',
          'rating': 4,
        },
      ]);
      expect(find.text('Thank you!'), findsOneWidget);
    });

    testWidgets('the rating is optional and can be taken back', (tester) async {
      final api = _FakeFeedbackApi();
      await tester.pumpWidget(_app(FeedbackScreen(api: api)));

      await _tap(tester, find.text('An idea'));
      await _tap(tester, find.byTooltip('Rate 2 out of 5'));
      await tester.pump();
      await _tap(tester, find.byTooltip('Rate 2 out of 5'));
      await tester.pump();
      expect(find.text('2 / 5'), findsNothing);
      await tester.ensureVisible(find.byKey(FeedbackScreen.messageKey));
      await tester.enterText(find.byKey(FeedbackScreen.messageKey), 'Tigrinya');
      await tester.pump();
      await tester.tap(find.byKey(FeedbackScreen.sendKey));
      await tester.pumpAndSettle();

      expect(api.sent.single['rating'], isNull);
      expect(api.sent.single['category'], FeedbackCategory.idea);
    });

    testWidgets('a failed send says so and keeps the message', (tester) async {
      final api = _FakeFeedbackApi()
        ..failWith = const FeedbackApiException('offline');
      await tester.pumpWidget(_app(FeedbackScreen(api: api)));

      await _tap(tester, find.text('Something broke'));
      await tester.ensureVisible(find.byKey(FeedbackScreen.messageKey));
      await tester.enterText(find.byKey(FeedbackScreen.messageKey), 'Crash');
      await tester.pump();
      await tester.tap(find.byKey(FeedbackScreen.sendKey));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't send. Check your connection and try again."),
        findsOneWidget,
      );
      expect(find.text('Crash'), findsOneWidget);
      expect(find.text('Thank you!'), findsNothing);

      api.failWith = const FeedbackApiException('busy', tooMany: true);
      await tester.tap(find.byKey(FeedbackScreen.sendKey));
      await tester.pumpAndSettle();
      expect(
        find.text("That's plenty for today. Thank you! Try again tomorrow."),
        findsOneWidget,
      );
    });
  });

  testWidgets('Settings opens Send feedback', (tester) async {
    final storage = InMemorySecureStorageService();
    final sessions = SessionRepository(storage: storage);
    await sessions.saveSession(
      SessionState(
        token: 'session-token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        authProvider: 'google',
      ),
    );
    await tester.pumpWidget(
      _app(
        SettingsScreen(
          sessionApi: SessionApi(
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'valid': true,
                  'user': {
                    'id': 'user-1',
                    'selected_language': 'am',
                    'daily_xp_target': 40,
                    'notification_enabled': true,
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          ),
          courseApi: FakeCourseApi(),
          userPreferencesApi: FakeUserPreferencesApi(),
          soundPreferenceRepository: SoundPreferenceRepository(
            storage: storage,
          ),
          sessionRepository: sessions,
          feedbackApi: _FakeFeedbackApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(SettingsScreen.sendFeedbackKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(SettingsScreen.sendFeedbackKey));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(find.text('What is it about?'), findsOneWidget);
  });
}
