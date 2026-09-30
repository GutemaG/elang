// The Notifications switch controls the 8 pm reminder (021-daily-reminder,
// bolts 064 and 065): it shows the saved value, with a blocked line when the
// phone doesn't allow notifications; turning it on asks if needed, and
// turning it off or logging out cancels.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:elang/features/settings/state/settings_controller.dart';
import 'package:elang/shared/models/session_state.dart';
import 'package:elang/shared/services/fake_course_api.dart';
import 'package:elang/shared/services/reminders/reminder_service.dart';
import 'package:elang/shared/services/session_api.dart';
import 'package:elang/shared/services/session_repository.dart';
import 'package:elang/shared/services/sound_preference_repository.dart';
import 'package:elang/shared/services/user_preferences_api.dart';
import 'package:elang/shared/services/user_preferences_api_exception.dart';

import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/fake_user_preferences_api.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

SessionApi _sessionApi({required bool notificationEnabled}) => SessionApi(
  client: MockClient(
    (request) async => http.Response(
      jsonEncode({
        'valid': true,
        'user': {
          'id': 'user-1',
          'selected_language': 'am',
          'daily_xp_target': 40,
          'notification_enabled': notificationEnabled,
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    ),
  ),
);

UpdatedPreferences _saved(bool on) => UpdatedPreferences(
  selectedLanguage: 'am',
  dailyXpTarget: 40,
  notificationEnabled: on,
);

class _Rig {
  _Rig({
    this.serverOn = true,
    bool permitted = true,
    bool grant = true,
    bool supported = true,
  }) : scheduler = FakeReminderScheduler(
         permitted: permitted,
         grantOnRequest: grant,
         supported: supported,
       );

  final bool serverOn;
  final FakeReminderScheduler scheduler;
  final storage = InMemorySecureStorageService();
  final preferences = FakeUserPreferencesApi();
  late final store = ReminderStore(storage: storage);
  late final reminders = ReminderService(scheduler: scheduler, store: store);
  late final SessionRepository session;
  late final SettingsController controller;

  Future<SettingsController> load() async {
    session = SessionRepository(storage: InMemorySecureStorageService());
    await session.saveSession(
      SessionState(
        token: 'session-token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      ),
    );
    controller = SettingsController(
      sessionApi: _sessionApi(notificationEnabled: serverOn),
      courseApi: FakeCourseApi(),
      userPreferencesApi: preferences,
      soundPreferenceRepository: SoundPreferenceRepository(
        storage: InMemorySecureStorageService(),
      ),
      sessionRepository: session,
      reminders: reminders,
    );
    await controller.load();
    // Let the reminder's queued rebuild finish.
    await reminders.reschedule();
    return controller;
  }
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('load', () {
    test('saved on and allowed: on, and the week is scheduled', () async {
      final rig = _Rig();
      final controller = await rig.load();

      expect(controller.notificationEnabled, isTrue);
      expect(controller.notificationsBlocked, isFalse);
      expect(rig.scheduler.scheduled, isNotEmpty);
    });

    test('saved on but not allowed: on, blocked, and never asks', () async {
      final rig = _Rig(permitted: false);
      final controller = await rig.load();

      expect(controller.notificationEnabled, isTrue);
      expect(controller.notificationsBlocked, isTrue);
      expect(rig.scheduler.requestCount, 0);
      expect(rig.scheduler.scheduled, isEmpty);
    });

    test('saved off: off, not blocked, and kept off on this device', () async {
      final rig = _Rig(serverOn: false);
      final controller = await rig.load();

      expect(controller.notificationEnabled, isFalse);
      expect(controller.notificationsBlocked, isFalse);
      expect(await rig.store.enabled(), isFalse);
      expect(rig.scheduler.scheduled, isEmpty);
    });
  });

  group('turning it on', () {
    test('asks, then saves and schedules when allowed', () async {
      final rig = _Rig(serverOn: false, permitted: false);
      final controller = await rig.load();
      rig.preferences.nextResult = _saved(true);

      await controller.updateNotificationEnabled(true);
      await rig.reminders.reschedule();

      expect(rig.scheduler.requestCount, 1);
      expect(rig.preferences.calls.single.notificationEnabled, isTrue);
      expect(controller.notificationEnabled, isTrue);
      expect(rig.scheduler.scheduled, isNotEmpty);
    });

    test('a refusal saves on, and shows the blocked line', () async {
      final rig = _Rig(serverOn: false, permitted: false, grant: false);
      final controller = await rig.load();
      rig.preferences.nextResult = _saved(true);

      await controller.updateNotificationEnabled(true);
      await rig.reminders.reschedule();

      expect(rig.scheduler.requestCount, 1);
      expect(rig.preferences.calls.single.notificationEnabled, isTrue);
      expect(controller.notificationEnabled, isTrue);
      expect(controller.notificationsBlocked, isTrue);
      expect(rig.scheduler.scheduled, isEmpty);
    });

    test('allowed in the phone settings afterwards: unblocked', () async {
      final rig = _Rig(permitted: false);
      final controller = await rig.load();

      await controller.openNotificationSettings();
      rig.scheduler.permitted = true;
      await controller.recheckNotificationPermission();
      await rig.reminders.reschedule();

      expect(rig.scheduler.openSettingsCount, 1);
      expect(controller.notificationEnabled, isTrue);
      expect(controller.notificationsBlocked, isFalse);
      expect(rig.scheduler.scheduled, isNotEmpty);
    });

    test('a failed save reverts it, and nothing is scheduled', () async {
      final rig = _Rig(serverOn: false);
      final controller = await rig.load();
      rig.preferences.nextException = const UserPreferencesApiException('no');

      await controller.updateNotificationEnabled(true);
      await rig.reminders.reschedule();

      expect(controller.notificationEnabled, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(rig.scheduler.scheduled, isEmpty);
    });
  });

  test('turning it off saves and cancels every reminder', () async {
    final rig = _Rig();
    final controller = await rig.load();
    rig.preferences.nextResult = _saved(false);

    await controller.updateNotificationEnabled(false);
    await rig.reminders.reschedule();

    expect(rig.preferences.calls.single.notificationEnabled, isFalse);
    expect(controller.notificationEnabled, isFalse);
    expect(rig.scheduler.requestCount, 0);
    expect(rig.scheduler.scheduled, isEmpty);
  });

  test('logging out cancels every reminder', () async {
    final rig = _Rig();
    final controller = await rig.load();
    expect(rig.scheduler.scheduled, isNotEmpty);

    await controller.logout();

    expect(rig.scheduler.scheduled, isEmpty);
  });

  test('the web: the saved value alone, and no permission calls', () async {
    final rig = _Rig(permitted: false, supported: false);
    final controller = await rig.load();
    rig.preferences.nextResult = _saved(false);

    expect(controller.notificationEnabled, isTrue);
    expect(controller.notificationsBlocked, isFalse);

    await controller.updateNotificationEnabled(false);
    rig.preferences.nextResult = _saved(true);
    await controller.updateNotificationEnabled(true);

    expect(controller.notificationEnabled, isTrue);
    expect(rig.scheduler.requestCount, 0);
  });
}
