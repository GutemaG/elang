// The Licences row in settings (019-image-choice-exercise-types, bolt 054,
// story 005): it opens Flutter's licence page, which lists the picture
// credits.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/licences/picture_credits.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/widgets/app_card.dart';

import '../../../helpers/fake_user_preferences_api.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

Future<Widget> _settings() async {
  final sessions = SessionRepository(storage: InMemorySecureStorageService());
  await sessions.saveSession(
    SessionState(
      token: 'session-token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      authProvider: 'google',
    ),
  );
  return MaterialApp(
    home: SettingsScreen(
      sessionApi: SessionApi(
        client: MockClient(
          (request) async => http.Response(
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
        storage: InMemorySecureStorageService(),
      ),
      sessionRepository: sessions,
    ),
  );
}

void main() {
  tearDown(LicenseRegistry.reset);

  testWidgets('settings has a Licences row, after Sound', (tester) async {
    await tester.pumpWidget(await _settings());
    await tester.pumpAndSettle();

    final licences = find.widgetWithText(ListRow, 'Licences');
    expect(licences, findsOneWidget);
    expect(
      find.descendant(
        of: licences,
        matching: find.text('Open-source software and picture credits'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(licences).dy,
      greaterThan(tester.getTopLeft(find.text('Sound')).dy),
    );
  });

  testWidgets('tapping it opens the licence page for Buna, listing the '
      'picture credits', (tester) async {
    LicenseRegistry.addLicense(
      () => Stream.fromIterable(
        pictureCreditEntries(
          jsonEncode({
            'pictures': [
              {
                'file': 'dog.webp',
                'subject': 'Dog',
                'author': 'Vanessa Boutzikoudi',
                'source': 'OpenMoji',
                'licence': 'CC BY-SA 4.0',
              },
            ],
          }),
        ),
      ),
    );
    await tester.pumpWidget(await _settings());
    await tester.pumpAndSettle();

    final licences = find.text('Licences');
    await tester.ensureVisible(licences);
    await tester.tap(licences);
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('Buna'), findsWidgets);

    // The licence page gathers the registry off the first frame.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    // The heading the plan names, not just whatever the constant holds.
    expect(find.text('Sample pictures'), findsOneWidget);

    await tester.tap(find.text('Sample pictures'));
    await tester.pumpAndSettle();
    expect(find.text('By Vanessa Boutzikoudi, from OpenMoji'), findsOneWidget);
    expect(find.text('Licence: CC BY-SA 4.0'), findsOneWidget);
  });
}
