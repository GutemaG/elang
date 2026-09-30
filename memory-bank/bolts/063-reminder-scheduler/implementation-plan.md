---
stage: plan
bolt: 063-reminder-scheduler
created: '2026-09-30T08:55:00Z'
---

## Implementation Plan: reminder-scheduler

### Objective

Stories 001-003 (FR-1, FR-2, FR-3): the phone shows one reminder at 8 pm
local time on days not yet practised, for the next week, naming the
streak. The Settings switch and the permission request are bolt 064; this
bolt schedules only when the switch is on and permission is already given,
and never asks.

### What the code says (checked before planning)

- **F1: Packages.** `flutter pub add --dry-run` resolves
  `flutter_local_notifications` 22.3.1, `timezone` 0.11.1 and
  `flutter_timezone` 5.1.0 with Flutter 3.47.4. Nothing else changes
  version.
- **F2: Android** (`android/app/build.gradle.kts`, `AndroidManifest.xml`):
  no desugaring, no notification permission, no receivers. The plugin
  needs core library desugaring and its two receivers (scheduled and boot)
  declared by the app.
- **F3: iOS** (`AppDelegate.swift`, iOS 15): uses Flutter's implicit
  engine; no notification delegate yet.
- **F4: Where things happen.**
  - The dashboard's `_load` fetches the skill tree online or reads the
    saved copy, and runs on start, after a lesson, after Practice and on a
    course change.
  - `LessonController` finishes a lesson online (`completeLesson`, whose
    result says `isReview`) or queues it offline (`_queueForSync`, where
    the controller's own `isReview` applies). Practice has its own branch.
- **F5: The switch's value** comes from the session check
  (`notificationEnabled`, default on). The dashboard doesn't have it.
- **F6: Storage.** `SoundPreferenceRepository` keeps a device-only value in
  the app's secure storage; the same pattern fits here.

### Decisions

- **D1: Pieces** (`lib/shared/services/reminders/`):
  - `reminder_plan.dart`: a pure function that takes now, the local time
    zone, the streak count and the last practised streak day, and returns
    the reminders (fire time, title, body). No plugin; fully unit tested.
  - `ReminderScheduler`: the interface to the phone (`replaceAll`,
    `cancelAll`, `isPermitted`). `LocalReminderScheduler` wraps the plugin;
    `FakeReminderScheduler` for tests; on the web a no-op.
  - `ReminderStore`: device-only values in secure storage: the switch as
    last known (default on; bolt 064 keeps it in step with the server) and
    the last practised streak day.
  - `ReminderService`: `refresh(streakCount, practisedToday)` and
    `lessonCounted(completedAt, streakCount)`. It checks the switch and
    permission, keeps the practised day, and asks the scheduler to replace
    everything.
- **D2: The plan.**
  - One reminder for each of the next 7 local days at 20:00 in the phone's
    time zone (`flutter_timezone` gives the zone name; `timezone` does the
    maths, including daylight saving).
  - A fire time already past is skipped.
  - A day whose streak day (the UTC date of that 8 pm) is already
    practised is skipped.
  - Each refresh cancels and schedules again, so reminders never pile up.
    The app has no other notifications, so "cancel" means all of them.
- **D3: The message** (refines FR-3). Only the **next** reminder names the
  streak: "Keep your 12-day streak going" / "A quick lesson is enough."
  (with "1-day" for 1). Every later one, and any with a streak of 0, says
  "Time for today's lesson" / "A quick lesson keeps you going." If the next
  reminder's day passes without a lesson, the streak is gone, so naming
  it on the days after would be wrong.
- **D4: When it refreshes.**
  - Dashboard loaded from the network: with `streak_count` and
    `practised_today`.
  - Dashboard from the saved copy: with the streak count only; the saved
    `practised_today` may be from another day, so it is not used.
  - A lesson that counts finishes (online and not a review by the
    server's answer; or queued offline and not a review): it marks today's
    streak day practised. Practice never counts.
- **D5: Android setup.** Core library desugaring; `POST_NOTIFICATIONS`
  and `RECEIVE_BOOT_COMPLETED` permissions; the plugin's two receivers.
  Inexact scheduling (`inexactAllowWhileIdle`), so no exact-alarm
  permission; a few minutes' drift is fine. The launcher icon as the small
  icon for now. One channel, "Daily reminder".
- **D6: iOS setup.** The notification centre delegate in `AppDelegate`,
  and the plugin initialised with every "request permission" flag off, so
  starting the app never shows a prompt (FR-5).
- **D7: Tapping it** just opens the app, which starts on the dashboard; no
  extra routing.
- **D8: App model.** `SkillTree.practisedToday` (read with a default of
  false; kept in the saved copy but not trusted from it, D4).
- **D9: Wiring.** `ReminderService` is built in `main.dart` and passed as
  an optional value to the dashboard and the lesson screen, so existing
  tests that don't pass it are untouched.

### Out of scope

- The switch, the permission prompt and sign-out (bolt 064).
- A notification-specific icon; a time picker; server push.

### Tests

- `reminder_plan`: 7 reminders at 20:00 local in Addis Ababa; one past 8 pm
  skips today; a practised day skipped; a zone behind UTC (New York),
  where 8 pm is the next UTC day; a daylight-saving change (Europe/London
  in late October); message rules (next only, 1-day, 0).
- `ReminderService` with the fake scheduler: switch off, no permission →
  nothing scheduled and all cancelled; `practisedToday` from the network;
  a counted lesson; a review and Practice don't count; the practised day
  survives a new service (stored).
- `SkillTree` JSON: `practised_today` read, missing → false, kept in
  `toJson`.
- Dashboard and lesson flow with the fake: a network load refreshes with
  the right values; a saved-copy load passes no `practisedToday`; a
  finished lesson marks the day; a review and an offline review don't.
- `flutter build apk --debug` succeeds (Android setup compiles).

### Acceptance criteria

- [ ] Reminders at 8 pm local for the next 7 days; none past; no
  duplicates (story 001).
- [ ] A practised day is skipped, from a finished lesson or from the
  server; later days stay (story 002).
- [ ] The next reminder names the streak; later ones are plain (story 003).
- [ ] Nothing scheduled without the switch or permission; no prompt ever.
- [ ] Android builds; `flutter analyze` clean; `flutter test` passes.
- [ ] On a phone: a reminder arrives at 8 pm; after a lesson, none that
  day (left for a person; iOS needs a Mac).

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-30, with the message change (D3).

### New (`lib/shared/services/reminders/`)

- **`reminder_plan.dart`**: `planReminders(now, streakCount,
  practisedDay)` and `reminderMessage(streak)`; ids are the local date as
  a number (20261001).
- **`reminder_scheduler.dart`**: the `ReminderScheduler` interface,
  `NoReminderScheduler` (the web) and `LocalReminderScheduler` (the
  plugin: one "Daily reminder" channel, inexact scheduling, every iOS
  permission flag off at start, the phone's zone from `flutter_timezone`
  with UTC if the name is unknown).
- **`reminder_service.dart`**: `ReminderStore` (switch, practised day,
  last streak, in secure storage) and `ReminderService` (`refresh`,
  `lessonCounted`, `reschedule`; one rebuild at a time; failures
  swallowed).

### Changed

- **Packages**: `flutter_local_notifications` ^22.3.1, `timezone`
  ^0.11.1, `flutter_timezone` ^5.1.0. `pub get` also regenerated the
  Linux, macOS and Windows plugin registrants.
- **Android**: core library desugaring (`desugar_jdk_libs` 2.1.4);
  `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED`; the plugin's two
  receivers.
- **iOS**: `AppDelegate` sets the notification centre delegate.
- **App**: `SkillTreeResponse.practisedToday` (HTTP and saved copy);
  `LessonController.onLessonCounted` (online when the server says it is
  not a review; queued offline when not a review; never Practice);
  `LessonScreen.reminders`; the dashboard refreshes on each load (the
  saved copy passes only the streak) and hands `reminders` to lessons;
  `LessonDependencies.reminders`, built in `main.dart`.

### Not in the plan

- **The full time zone database** (`latest_all`, about 450 KB). The
  default set left out `Africa/Addis_Ababa` (an old name for Nairobi's
  zone), which is what an Ethiopian phone reports: the reminder would have
  fallen back to UTC and come at 11 pm. Found by the first test run.
- `ReminderService.reschedule()` (rebuild from what is stored), used by
  the restart test and ready for bolt 064's switch.

### Tests (+30)

- `test/shared/services/reminders/reminder_plan_test.dart` (9): the week
  in Addis Ababa; past 8 pm; a practised day; a lesson at 01:30 in Addis;
  New York, where 8 pm is the next UTC day; London across the clock
  change; next-only streak message; 1 and 0; ids across a year end.
- `test/shared/services/reminders/reminder_service_test.dart` (11): the
  week; switch off; no permission (and no asking); `practised_today`; a
  counted lesson with and without a new streak; a later "false" never
  clears a marked day; survives a restart; yesterday's mark; a failure
  swallowed; the switch default.
- `test/features/lesson/lesson_counted_test.dart` (5): online counts with
  the new streak; the server's review doesn't; offline counts; an offline
  review doesn't; Practice doesn't.
- `test/features/lesson/screens/dashboard_reminder_test.dart` (3): a
  network load; the saved copy; a lesson from the dashboard.
- `http_lesson_api_test.dart` (+1), `course_cache_store_test.dart` (+1):
  `practised_today` read, missing, and kept in the saved copy.

## Checks (Stage 2)

- `flutter analyze`: no issues.
- `flutter test --exclude-tags e2e`: 1520 passed (was 1490).
- `flutter build apk --debug`: built.
- iOS: not built (needs a Mac).

---

## Test Report (Stage 3)

Implement approved 2026-09-30.

### Runs

| Suite | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test --exclude-tags e2e` | 1520 passed |
| This bolt's test files, plus the review and stats-sheet dashboard tests, repeated | 76 passed, 3 of 3 runs |
| Design rules (`test/design`) | 211 passed |
| `flutter build apk --debug` | built |

### Acceptance criteria

- [x] Reminders at 8 pm local for the next 7 days; none past; no
  duplicates (story 001: `reminder_plan_test`, and each refresh replaces
  the whole schedule).
- [x] A practised day is skipped, from a finished lesson or from the
  server; later days stay (story 002: `reminder_service_test`,
  `lesson_counted_test`, `dashboard_reminder_test`).
- [x] The next reminder names the streak; later ones are plain (story 003:
  `reminder_plan_test`).
- [x] Nothing scheduled without the switch or permission; no prompt ever
  (`reminder_service_test`; every iOS request flag is off at start, and
  Android only asks when the app calls for it, which nothing does yet).
- [x] Android builds; `flutter analyze` clean; `flutter test` passes.
- [ ] On a phone: a reminder arrives at 8 pm; after a lesson, none that
  day. Not tried yet.

### Not covered here

- The plugin itself (`LocalReminderScheduler`): only on a device. Tests
  use the fake.
- iOS: not built; the `AppDelegate` line follows the plugin's README.
- Turning reminders on: until bolt 064, a phone only gets reminders if
  notifications are already allowed for the app (Android 12 and older
  allow them by default; Android 13+ and iOS need the switch's prompt).

### Left for a person

- Android 12 or older (or allow notifications in the phone's settings):
  open the app, then check the pending reminder fires at 8 pm; finish a
  lesson before 8 pm, and none comes that day.
- Restart the phone: the next reminder still comes.
- iOS, on a Mac, after bolt 064: build and repeat.
