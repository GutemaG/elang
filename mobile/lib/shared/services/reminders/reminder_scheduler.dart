import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// The phone's side of the daily reminder (021-daily-reminder, bolt 063):
/// what time zone it is in, whether it may show notifications, and the
/// reminders it has scheduled. Kept behind an interface so tests use a fake
/// and never touch the plugin.
abstract class ReminderScheduler {
  /// Whether this platform can show reminders at all (not the web).
  bool get supported;

  /// The phone's time zone.
  Future<tz.Location> localLocation();

  /// Whether notifications are allowed. Never asks.
  Future<bool> isPermitted();

  /// Asks the phone to allow notifications (bolt 064: only from the
  /// Settings switch), and whether they are allowed afterwards.
  Future<bool> requestPermission();

  /// Opens the phone's notification settings for this app.
  Future<void> openSettings();

  /// Cancels every reminder and schedules [reminders] instead.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  Future<void> cancelAll();
}

/// Where nothing can be scheduled (the web): never permitted, and every
/// call does nothing.
class NoReminderScheduler implements ReminderScheduler {
  const NoReminderScheduler();

  @override
  bool get supported => false;

  @override
  Future<tz.Location> localLocation() async => tz.UTC;

  @override
  Future<bool> isPermitted() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Local notifications scheduled on the phone with
/// `flutter_local_notifications`. They fire with the app closed and
/// offline, and survive a restart (the plugin's boot receiver on Android).
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder',
      'Daily reminder',
      channelDescription: "A reminder at 8 pm if you haven't practised",
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Loads the time zone data and starts the plugin once. Every "request
  /// permission" flag is off, so starting never shows a prompt (FR-5).
  Future<void> _init() => _ready ??= () async {
    // The full set, with the old names: an Ethiopian phone reports
    // "Africa/Addis_Ababa", which the smaller sets only know as Nairobi.
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }();

  @override
  Future<tz.Location> localLocation() async {
    await _init();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(zone.identifier);
    } on Object {
      // An unknown zone name: UTC keeps the reminder coming, if at the
      // wrong hour, rather than not at all.
      return tz.UTC;
    }
  }

  @override
  Future<bool> isPermitted() async {
    await _init();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.areNotificationsEnabled() ?? false;
      case TargetPlatform.iOS:
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final options = await ios?.checkPermissions();
        return options?.isEnabled ?? false;
      default:
        return false;
    }
  }

  @override
  bool get supported => true;

  @override
  Future<bool> requestPermission() async {
    await _init();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        // Android 12 and older have nothing to ask and answer true.
        return await android?.requestNotificationsPermission() ?? false;
      case TargetPlatform.iOS:
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      default:
        return false;
    }
  }

  @override
  Future<void> openSettings() async {
    await _init();
    await _plugin.openAppNotificationSettings();
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _init();
    // The app shows no other notifications, so "all" is only reminders.
    await _plugin.cancelAll();
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        scheduledDate: reminder.at,
        notificationDetails: _details,
        // Inexact: a few minutes' drift is fine, and it needs no
        // exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: reminder.title,
        body: reminder.body,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }
}
