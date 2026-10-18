// The Notifications row in Settings (021-daily-reminder, bolt 064): what
// it says, the blocked line and the way back to the phone's settings.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:elang/features/auth/auth_routes.dart';
import 'package:elang/features/settings/screens/settings_screen.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/reminders/reminder_service.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/user_preferences_api.dart';
import 'package:elang/shared/widgets/app_card.dart';

import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/fake_user_preferences_api.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

final _blockedRow = find.byKey(const ValueKey('notifications-blocked'));
final _switch = find.widgetWithText(SwitchRow, 'Notifications');

Future<FakeUserPreferencesApi> _pump(
  WidgetTester tester,
  FakeReminderScheduler scheduler, {
  bool serverOn = true,
}) async {
  final session = SessionRepository(storage: InMemorySecureStorageService());
  await session.saveSession(
    SessionState(
      token: 'session-token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      authProvider: 'google',
    ),
  );
  final preferences = FakeUserPreferencesApi()
    ..nextResult = const UpdatedPreferences(
      selectedLanguage: 'am',
      dailyXpTarget: 40,
      notificationEnabled: true,
    );
  await tester.pumpWidget(
    MaterialApp(
      home: SettingsScreen(
        sessionApi: SessionApi(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'valid': true,
                'user': {
                  'id': 'user-1',
                  'selected_language': 'am',
                  'daily_xp_target': 40,
                  'notification_enabled': serverOn,
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
        courseApi: FakeCourseApi(),
        userPreferencesApi: preferences,
        soundPreferenceRepository: SoundPreferenceRepository(
          storage: InMemorySecureStorageService(),
        ),
        sessionRepository: session,
        reminders: ReminderService(
          scheduler: scheduler,
          store: ReminderStore(storage: InMemorySecureStorageService()),
        ),
      ),
      routes: {
        AuthRoutes.signIn: (context) => const Scaffold(body: Text('Sign in')),
      },
    ),
  );
  await tester.pumpAndSettle();
  return preferences;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('the switch says what it does', (tester) async {
    await _pump(tester, FakeReminderScheduler());

    expect(
      find.text("A reminder at 8 pm if you haven't practised"),
      findsOneWidget,
    );
    expect(tester.widget<SwitchRow>(_switch).value, isTrue);
    expect(_blockedRow, findsNothing);
  });

  testWidgets('blocked by the phone: on, with a row to its settings', (
    tester,
  ) async {
    final scheduler = FakeReminderScheduler(permitted: false);
    await _pump(tester, scheduler);

    expect(tester.widget<SwitchRow>(_switch).value, isTrue);
    expect(find.text("Blocked in your phone's settings"), findsOneWidget);
    expect(scheduler.requestCount, 0);

    await tester.tap(_blockedRow);
    await tester.pumpAndSettle();
    expect(scheduler.openSettingsCount, 1);
  });

  testWidgets('back from the phone settings, allowed: the row goes', (
    tester,
  ) async {
    final scheduler = FakeReminderScheduler(permitted: false);
    await _pump(tester, scheduler);

    scheduler.permitted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchRow>(_switch).value, isTrue);
    expect(_blockedRow, findsNothing);
  });

  testWidgets('turning it on asks the phone; a refusal shows the row', (
    tester,
  ) async {
    final scheduler = FakeReminderScheduler(
      permitted: false,
      grantOnRequest: false,
    );
    await _pump(tester, scheduler, serverOn: false);
    expect(_blockedRow, findsNothing);

    await tester.tap(_switch);
    await tester.pumpAndSettle();

    expect(scheduler.requestCount, 1);
    expect(tester.widget<SwitchRow>(_switch).value, isTrue);
    expect(_blockedRow, findsOneWidget);
  });

  testWidgets('saved off: off, and no blocked row', (tester) async {
    await _pump(
      tester,
      FakeReminderScheduler(permitted: false),
      serverOn: false,
    );

    expect(tester.widget<SwitchRow>(_switch).value, isFalse);
    expect(_blockedRow, findsNothing);
  });

  testWidgets('logging out cancels every reminder', (tester) async {
    final scheduler = FakeReminderScheduler();
    await _pump(tester, scheduler);
    await tester.runAsync(() async {
      // Let the load's reminder rebuild land.
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Log out').last);
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last); // the confirm
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancelAllCount, greaterThan(0));
  });
}
