// Keeping the phone's reminders in step (021-daily-reminder, bolt 063):
// the switch and permission gate everything; a practised day is kept on the
// device; a failure never escapes.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:elang/shared/services/reminders/reminder_plan.dart';
import 'package:elang/shared/services/reminders/reminder_scheduler.dart';
import 'package:elang/shared/services/reminders/reminder_service.dart';

import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/in_memory_secure_storage_service.dart';

// 9 am in Addis Ababa on 30 September.
final _morning = DateTime.utc(2026, 9, 30, 6);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  late InMemorySecureStorageService storage;
  late FakeReminderScheduler scheduler;

  setUp(() {
    storage = InMemorySecureStorageService();
    scheduler = FakeReminderScheduler(
      location: tz.getLocation('Africa/Addis_Ababa'),
    );
  });

  ReminderService service({DateTime? now}) => ReminderService(
    scheduler: scheduler,
    store: ReminderStore(storage: storage),
    clock: () => now ?? _morning,
  );

  test('schedules the week, naming the streak', () async {
    await service().refresh(streakCount: 5, practisedToday: false);

    expect(scheduler.scheduled, hasLength(7));
    expect(scheduler.scheduled.first.id, 20260930);
    expect(scheduler.scheduled.first.title, 'Keep your 5-day streak going');
  });

  test('switch off: everything cancelled, nothing scheduled', () async {
    await ReminderStore(storage: storage).setEnabled(false);

    await service().refresh(streakCount: 5, practisedToday: false);

    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancelAllCount, 1);
  });

  test('no permission: everything cancelled, and it never asks', () async {
    scheduler.permitted = false;

    await service().refresh(streakCount: 5, practisedToday: false);

    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancelAllCount, 1);
  });

  test("the server's practised_today skips today's", () async {
    await service().refresh(streakCount: 5, practisedToday: true);

    expect(scheduler.scheduled.first.id, 20261001);
    expect(scheduler.scheduled, hasLength(6));
  });

  test('a counted lesson skips its day, with the new streak', () async {
    final reminders = service();
    await reminders.refresh(streakCount: 5, practisedToday: false);

    await reminders.lessonCounted(
      _morning.add(const Duration(hours: 1)),
      streakCount: 6,
    );

    expect(scheduler.scheduled.first.id, 20261001);
    expect(scheduler.scheduled.first.title, 'Keep your 6-day streak going');
  });

  test('an offline lesson keeps the streak last seen', () async {
    final reminders = service();
    await reminders.refresh(streakCount: 5, practisedToday: false);

    await reminders.lessonCounted(_morning);

    expect(scheduler.scheduled.first.id, 20261001);
    expect(scheduler.scheduled.first.title, 'Keep your 5-day streak going');
  });

  test(
    'a later "not practised" never clears a day this phone marked',
    () async {
      // The offline lesson hasn't reached the server yet.
      final reminders = service();
      await reminders.lessonCounted(_morning);

      await reminders.refresh(streakCount: 5, practisedToday: false);

      expect(scheduler.scheduled.first.id, 20261001);
    },
  );

  test('the practised day and streak survive a restart', () async {
    await service().lessonCounted(_morning, streakCount: 3);
    scheduler.scheduled = const [];

    await service().reschedule();

    expect(scheduler.scheduled.first.id, 20261001);
    expect(scheduler.scheduled.first.title, 'Keep your 3-day streak going');
  });

  test("yesterday's practised day doesn't skip today", () async {
    await service(now: DateTime.utc(2026, 9, 29, 12))
        .lessonCounted(DateTime.utc(2026, 9, 29, 12));

    await service().reschedule();

    expect(scheduler.scheduled.first.id, 20260930);
  });

  test(
    'a scheduler failure is swallowed, and the next change still runs',
    () async {
      final failing = _FailingOnceScheduler(scheduler);
      final reminders = ReminderService(
        scheduler: failing,
        store: ReminderStore(storage: storage),
        clock: () => _morning,
      );

      await expectLater(reminders.refresh(streakCount: 1), completes);
      await reminders.refresh(streakCount: 2);

      expect(scheduler.scheduled.first.title, 'Keep your 2-day streak going');
    },
  );

  group('bolt 064', () {
    test('setEnabled off cancels; on schedules again', () async {
      final reminders = service();
      await reminders.refresh(streakCount: 2);

      await reminders.setEnabled(false);
      expect(scheduler.scheduled, isEmpty);

      await reminders.setEnabled(true);
      expect(scheduler.scheduled, hasLength(7));
    });

    test('signing out cancels, forgets, and stays off until a dashboard '
        'loads signed in', () async {
      final reminders = service();
      await reminders.lessonCounted(_morning, streakCount: 9);
      await ReminderStore(storage: storage).setEnabled(false);

      await reminders.signedOut();
      expect(scheduler.scheduled, isEmpty);
      await reminders.reschedule();
      expect(scheduler.scheduled, isEmpty);

      final store = ReminderStore(storage: storage);
      expect(await store.practisedDay(), isNull);
      expect(await store.streakCount(), 0);
      expect(await store.enabled(), isTrue); // the default again

      await reminders.refresh(streakCount: 0, practisedToday: false);
      expect(scheduler.scheduled, hasLength(7));
      expect(scheduler.scheduled.first.id, 20260930); // today not skipped
    });

    test('asking and opening settings go to the phone', () async {
      scheduler
        ..permitted = false
        ..grantOnRequest = false;
      final reminders = service();

      expect(await reminders.isPermitted(), isFalse);
      expect(await reminders.requestPermission(), isFalse);
      await reminders.openSettings();

      expect(scheduler.requestCount, 1);
      expect(scheduler.openSettingsCount, 1);
    });

    test('the web: unsupported, never permitted', () async {
      final reminders = ReminderService(
        scheduler: const NoReminderScheduler(),
        store: ReminderStore(storage: storage),
      );

      expect(reminders.supported, isFalse);
      expect(await reminders.requestPermission(), isFalse);
      await expectLater(reminders.refresh(streakCount: 3), completes);
    });
  });

  group('bolt 065: asking on first launch', () {
    test('asks once, then schedules the week', () async {
      scheduler.permitted = false;
      final reminders = service();
      await reminders.refresh(streakCount: 5);

      await reminders.askOnFirstLaunch();
      await reminders.askOnFirstLaunch();

      expect(scheduler.requestCount, 1);
      expect(scheduler.scheduled, hasLength(7));
    });

    test('already allowed: no prompt', () async {
      final reminders = service();
      await reminders.refresh(streakCount: 5);

      await reminders.askOnFirstLaunch();

      expect(scheduler.requestCount, 0);
      expect(scheduler.scheduled, hasLength(7));
    });

    test('a refusal is not asked again', () async {
      scheduler
        ..permitted = false
        ..grantOnRequest = false;
      await service().askOnFirstLaunch();
      await service().askOnFirstLaunch();

      expect(scheduler.requestCount, 1);
      expect(scheduler.scheduled, isEmpty);
    });

    test('not with the switch off', () async {
      scheduler.permitted = false;
      await ReminderStore(storage: storage).setEnabled(false);

      await service().askOnFirstLaunch();

      expect(scheduler.requestCount, 0);
    });

    test('not on the web', () async {
      scheduler
        ..permitted = false
        ..supported = false;

      await service().askOnFirstLaunch();

      expect(scheduler.requestCount, 0);
    });

    test('signing out keeps the phone asked', () async {
      scheduler.permitted = false;
      final reminders = service();
      await reminders.askOnFirstLaunch();

      await reminders.signedOut();
      await reminders.refresh(streakCount: 1);
      await reminders.askOnFirstLaunch();

      expect(scheduler.requestCount, 1);
    });
  });

  test('the switch reads on when never set', () async {
    expect(await ReminderStore(storage: storage).enabled(), isTrue);
  });
}

class _FailingOnceScheduler implements ReminderScheduler {
  _FailingOnceScheduler(this._inner);

  final FakeReminderScheduler _inner;
  bool _failed = false;

  @override
  Future<tz.Location> localLocation() => _inner.localLocation();

  @override
  bool get supported => _inner.supported;

  @override
  Future<bool> requestPermission() => _inner.requestPermission();

  @override
  Future<void> openSettings() => _inner.openSettings();

  @override
  Future<bool> isPermitted() => _inner.isPermitted();

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    if (!_failed) {
      _failed = true;
      throw StateError('plugin failed');
    }
    await _inner.replaceAll(reminders);
  }

  @override
  Future<void> cancelAll() => _inner.cancelAll();
}
