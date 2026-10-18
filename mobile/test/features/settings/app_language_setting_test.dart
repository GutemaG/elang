// "App language" in Settings (024-app-localization, story 004): the row
// names the current language in itself, the sheet lists every app
// language, and choosing one redraws the app in it at once, offline too.

import 'dart:convert';

import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/l10n/app_language.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_user_preferences_api.dart';
import '../../helpers/in_memory_secure_storage_service.dart';
import '../../helpers/test_app_language.dart';

/// Settings in an app drawn in [appLanguage], as `BunaApp` draws it.
Future<void> _pumpSettings(
  WidgetTester tester,
  AppLanguageController appLanguage,
) async {
  final storage = InMemorySecureStorageService();
  final sessions = SessionRepository(storage: storage);
  await sessions.saveSession(
    SessionState(
      token: 'session-token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      authProvider: 'google',
    ),
  );
  final settings = SettingsScreen(
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
    soundPreferenceRepository: SoundPreferenceRepository(storage: storage),
    sessionRepository: sessions,
  );
  await tester.pumpWidget(
    AppLanguageScope(
      controller: appLanguage,
      child: ListenableBuilder(
        listenable: appLanguage,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          locale: appLanguage.language.locale,
          localizationsDelegates: AppLanguage.delegates,
          supportedLocales: AppLanguage.locales,
          home: settings,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRow(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(SettingsScreen.appLanguageRowKey),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(SettingsScreen.appLanguageRowKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the row names the current language in itself', (tester) async {
    await _pumpSettings(tester, testAppLanguage());

    final row = find.byKey(SettingsScreen.appLanguageRowKey);
    expect(
      find.descendant(of: row, matching: find.text('App language')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('English')),
      findsOneWidget,
    );
  });

  testWidgets('choosing Amharic redraws Settings in Amharic at once, and '
      'keeps it, with no network', (tester) async {
    final sent = <String>[];
    final storage = InMemorySecureStorageService();
    final appLanguage = testAppLanguage(
      storage: storage,
      // Offline: the account can't be told yet.
      send: (code) async {
        sent.add(code);
        return false;
      },
    );
    await _pumpSettings(tester, appLanguage);

    await _openRow(tester);
    expect(find.text('አማርኛ'), findsOneWidget);
    expect(find.text('Afaan Oromoo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-language-am')));
    await tester.pumpAndSettle();

    expect(appLanguage.language.code, 'am');
    expect(sent, ['am']);
    final row = find.byKey(SettingsScreen.appLanguageRowKey);
    expect(
      find.descendant(of: row, matching: find.text('የመተግበሪያ ቋንቋ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('አማርኛ')),
      findsOneWidget,
    );
    expect(storage.values['app_language'], 'am');
    expect(storage.values['app_language_unsent'], 'true');
  });

  testWidgets('the sheet marks the current language and closes on it '
      'without a change', (tester) async {
    final sent = <String>[];
    final appLanguage = testAppLanguage(
      code: 'om',
      send: (code) async {
        sent.add(code);
        return true;
      },
    );
    await _pumpSettings(tester, appLanguage);

    await _openRow(tester);
    expect(find.text('Afaan appii'), findsNWidgets(2)); // row and sheet
    await tester.tap(find.byKey(const ValueKey('app-language-om')));
    await tester.pumpAndSettle();

    expect(appLanguage.language.code, 'om');
    expect(sent, isEmpty);
  });
}
