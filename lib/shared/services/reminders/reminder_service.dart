import 'package:timezone/timezone.dart' as tz;

import '../../models/stat_history.dart';
import '../secure_storage_service.dart';
import 'reminder_plan.dart';
import 'reminder_scheduler.dart';
import '../../../l10n/app_localizations.dart';

/// Device-only values the daily reminder keeps (021-daily-reminder, bolt
/// 063), in the app's one key-value store, as `SoundPreferenceRepository`
/// does.
class ReminderStore {
  ReminderStore({required this._storage});

  static const _enabledKey = 'reminder_enabled';
  static const _practisedDayKey = 'reminder_practised_day';
  static const _streakKey = 'reminder_streak_count';
  static const _signedOutKey = 'reminder_signed_out';
  static const _askedKey = 'reminder_asked';

  final SecureStorageService _storage;

  /// The Notifications switch as last known on this device. On when never
  /// set, like the server's default.
  Future<bool> enabled() async => (await _storage.read(_enabledKey)) != 'false';

  Future<void> setEnabled(bool enabled) =>
      _storage.write(_enabledKey, enabled ? 'true' : 'false');

  /// The last streak day (UTC midnight) known to be practised.
  Future<DateTime?> practisedDay() async {
    final raw = await _storage.read(_practisedDayKey);
    final day = raw == null ? null : DateTime.tryParse(raw);
    return day == null ? null : utcDay(day);
  }

  Future<void> setPractisedDay(DateTime day) =>
      _storage.write(_practisedDayKey, utcDay(day).toIso8601String());

  Future<int> streakCount() async =>
      int.tryParse(await _storage.read(_streakKey) ?? '') ?? 0;

  Future<void> setStreakCount(int count) =>
      _storage.write(_streakKey, '$count');

  /// Signed out: nothing is scheduled until the next dashboard load, which
  /// only happens signed in.
  Future<bool> signedOut() async =>
      (await _storage.read(_signedOutKey)) == 'true';

  /// Forgets the account (a new install's values) and marks it signed out.
  Future<void> clearForSignOut() async {
    await _storage.delete(_practisedDayKey);
    await _storage.delete(_streakKey);
    await _storage.delete(_enabledKey);
    await _storage.write(_signedOutKey, 'true');
  }

  Future<void> markSignedIn() => _storage.delete(_signedOutKey);

  /// Whether this install has asked for notification permission on first
  /// launch (bolt 065). Kept across sign-out: it belongs to the phone.
  Future<bool> askedOnFirstLaunch() async =>
      (await _storage.read(_askedKey)) == 'true';

  Future<void> markAskedOnFirstLaunch() => _storage.write(_askedKey, 'true');
}

/// Keeps the phone's reminders in step with what the app knows: the
/// switch, the permission, the streak and whether today is practised
/// (021-daily-reminder, bolt 063).
///
/// Every change rebuilds the whole schedule. A failure is swallowed: a
/// missed reminder must never break the dashboard or a lesson.
class ReminderService {
  ReminderService({
    required this._scheduler,
    required this._store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ReminderScheduler _scheduler;
  final ReminderStore _store;
  final DateTime Function() _clock;

  /// The words the reminders are written in: the app language
  /// (024-app-localization, FR-7). English when unset. Call [reschedule]
  /// after the language changes so pending reminders use the new words.
  AppLocalizations Function()? words;

  /// Runs one rebuild at a time, in order.
  Future<void> _last = Future.value();

  /// After a dashboard load. [practisedToday] only ever marks today; a
  /// `false` never clears a day a lesson on this phone already marked (it
  /// may not have reached the server yet).
  Future<void> refresh({int? streakCount, bool? practisedToday}) =>
      _run(() async {
        await _store.markSignedIn();
        if (streakCount != null) await _store.setStreakCount(streakCount);
        if (practisedToday == true) await _store.setPractisedDay(_clock());
      });

  /// After a lesson that counts for the streak, finished at [completedAt]
  /// (online, or queued offline). [streakCount] is the server's new count
  /// when it answered.
  Future<void> lessonCounted(DateTime completedAt, {int? streakCount}) =>
      _run(() async {
        await _store.setPractisedDay(completedAt);
        if (streakCount != null) await _store.setStreakCount(streakCount);
      });

  /// Rebuilds the schedule from what is stored.
  Future<void> reschedule() => _run(() async {});

  /// Whether this platform can show reminders (not the web).
  bool get supported => _scheduler.supported;

  /// Whether the phone allows notifications. Never asks.
  Future<bool> isPermitted() async {
    try {
      return await _scheduler.isPermitted();
    } on Object {
      return false;
    }
  }

  /// Asks the phone to allow notifications, from the Settings switch
  /// (bolt 064). Whether they are allowed afterwards.
  Future<bool> requestPermission() async {
    try {
      return await _scheduler.requestPermission();
    } on Object {
      return false;
    }
  }

  /// Opens the phone's notification settings for the app.
  Future<void> openSettings() async {
    try {
      await _scheduler.openSettings();
    } on Object {
      // Nothing more to offer; the blocked line stays.
    }
  }

  /// Asks for notification permission once per install, after the first
  /// dashboard (bolt 065, FR-5): only on a phone, with the switch on and
  /// signed in, and only if the phone doesn't allow them yet.
  Future<void> askOnFirstLaunch() => _run(() async {
    if (!_scheduler.supported ||
        await _store.askedOnFirstLaunch() ||
        await _store.signedOut() ||
        !await _store.enabled()) {
      return;
    }
    await _store.markAskedOnFirstLaunch();
    if (await _scheduler.isPermitted()) return;
    await _scheduler.requestPermission();
  });

  /// The Notifications switch's value, from the server or the learner.
  Future<void> setEnabled(bool enabled) =>
      _run(() => _store.setEnabled(enabled));

  /// Cancels every reminder and forgets this account's streak and
  /// practised day, so the next one starts clean. Nothing is scheduled
  /// again until a dashboard loads signed in; the switch is back to its
  /// default until the next session check.
  Future<void> signedOut() => _run(_store.clearForSignOut);

  Future<void> _run(Future<void> Function() update) {
    return _last = _last.then((_) async {
      try {
        await update();
        await _apply();
      } on Object {
        // See the class comment.
      }
    });
  }

  Future<void> _apply() async {
    if (await _store.signedOut() ||
        !await _store.enabled() ||
        !await _scheduler.isPermitted()) {
      await _scheduler.cancelAll();
      return;
    }
    final location = await _scheduler.localLocation();
    await _scheduler.replaceAll(
      planReminders(
        now: tz.TZDateTime.from(_clock(), location),
        streakCount: await _store.streakCount(),
        practisedDay: await _store.practisedDay(),
        words: words?.call(),
      ),
    );
  }
}
