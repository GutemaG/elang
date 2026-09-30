---
stage: plan
bolt: 065-reminder-first-launch-prompt
created: '2026-09-30T12:52:24Z'
---

## Implementation Plan: reminder-first-launch-prompt

### Objective

Story 005 (FR-5 as changed on 2026-09-30): reminders are on by default,
the app asks for permission once on the first dashboard after install, and
the Settings switch shows the value saved in the database.

### What the code says (checked before planning)

- **F1: The database already defaults to on.** `users.notification_enabled`
  defaults to true, and `PATCH /api/v1/users/me` saves the switch (the
  local database's only account has it on).
- **F2: Why it looked off and unsaved.** Bolt 064 shows the switch as
  "saved on **and** the phone allows it". Android 13+ starts with
  notifications not allowed and the app never asked, so the switch showed
  off while the database said on. Tapping it only asked the phone; the
  database already held "on", so nothing seemed to change.
- **F3: The dashboard's first load** is where a signed-in learner lands
  after sign-in or onboarding; it already calls `reminders.refresh(...)`.
- **F4: The device copy of the switch** (`ReminderStore.enabled`, default
  on) is set from the server at every launch and in Settings.

### Decisions

- **D1: Ask once, on the first dashboard after install.** After the first
  dashboard load, `ReminderService.askOnFirstLaunch()`:
  - does nothing on the web, or if it has asked before on this install;
  - does nothing if the device copy of the switch is off;
  - otherwise asks the phone (Android 13+ prompt, iOS alert), remembers it
    asked (`reminder_asked`, kept across sign-out so a second account on
    the same phone isn't asked again), and rebuilds the week.
  Asking on the dashboard rather than on the sign-in screen ties the
  prompt to a signed-in learner, who is the only one who gets reminders.
- **D2: The switch shows the saved value.** `notificationEnabled` is the
  database value again. `notificationsBlocked` stays "saved on but the
  phone blocks it", and the "Blocked in your phone's settings" row shows
  under a switch that is **on**.
- **D3: Turning it on** still asks the phone first when permission is
  missing, then saves on. **Off** saves off and cancels, as before.
- **D4: Nothing else changes**: the subtitle, the blocked row opening the
  phone's settings, rechecking when the app comes back, sign-out.

### Out of scope

- Asking before sign-in. Android stops showing the prompt after two
  refusals; after that only the phone's settings can allow it (the
  blocked row).

### Tests

- `ReminderService.askOnFirstLaunch`: asks once and schedules; a second
  call does not ask; not with the switch off; not on the web; the "asked"
  mark survives sign-out.
- Dashboard: the first load asks; a second load does not.
- Settings: saved on but blocked → the switch on and the blocked row;
  saved off → off, no row; turning it on asks and saves; turning it off
  saves off. The bolt 064 tests that expected "off when blocked" are
  updated.

### Acceptance criteria

- [ ] The first dashboard after install asks once; never again on its own.
- [ ] The switch shows the saved value; on but blocked shows on with the
  blocked line.
- [ ] Turning on asks if needed; off saves off and cancels.
- [ ] `flutter analyze` clean; `flutter test` passes.
- [ ] On a phone: the prompt on first launch after a fresh install (left
  for a person).

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-30.

### Changed

- **`ReminderStore`**: `askedOnFirstLaunch()` and
  `markAskedOnFirstLaunch()` (key `reminder_asked`). Sign-out does not
  clear it: it belongs to the phone, not the account.
- **`ReminderService.askOnFirstLaunch()`**: in the same one-at-a-time
  queue as every other change. Returns without asking on the web, if
  asked before, when signed out, or with the switch off. Otherwise marks
  the phone asked, asks only if notifications aren't allowed yet, and
  rebuilds the week.
- **Dashboard**: calls it after each load, fresh or from the saved copy
  (the service makes sure it asks once).
- **`SettingsController.notificationEnabled`** is the saved value again;
  `notificationsBlocked` is unchanged, so the blocked row now sits under a
  switch that is on. Comments updated.

### Not in the plan

- Nothing.

### Tests (+7)

- `reminder_service_test.dart` (+6): asks once and schedules; already
  allowed, no prompt; a refusal isn't asked again; not with the switch
  off; not on the web; signing out keeps the phone asked.
- `settings_notifications_test.dart` (+1): saved off shows off with no
  row. Updated: blocked shows the switch on; a refusal leaves it on with
  the row.
- `settings_reminders_test.dart` (updated): on but blocked loads as on;
  a refusal saves on and shows the row.
- `dashboard_reminder_test.dart` (updated): a fresh load and a saved-copy
  load each offer the prompt.

## Checks (Stage 2)

- `flutter analyze`: no issues.
- `flutter test --exclude-tags e2e`: 1549 passed (was 1542).
- No backend, Android or iOS project files changed.

---

## Test Report (Stage 3)

Implement approved 2026-09-30.

### Runs

| Suite | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test --exclude-tags e2e` | 1549 passed |
| Reminder service, Settings, dashboard reminder, lesson counted and app boot tests, repeated | 108 passed, 3 of 3 runs |
| Design rules (`test/design`) | 211 passed |
| `flutter build apk --debug` | built |

### Acceptance criteria

- [x] The first dashboard after install asks once; never again on its own
  (`reminder_service_test`: once, refusal, sign-out; the dashboard test).
- [x] The switch shows the saved value; on but blocked shows on with the
  blocked line (`settings_reminders_test`, `settings_notifications_test`).
- [x] Turning on asks if needed; off saves off and cancels.
- [x] `flutter analyze` clean; `flutter test` passes.
- [ ] On a phone: the prompt on first launch after a fresh install. Not
  tried yet.

### Not covered here

- The real system prompt (a plugin call; only on a device). iOS: not
  built.
- A phone updated from a build that never asked also gets the prompt
  once, on its next dashboard (it has no "asked" mark yet); this is
  intended.

### Left for a person

- Android 13+, fresh install: sign in → the dashboard → the prompt.
  Allow → Settings shows on, no blocked row.
- Refuse instead → no second prompt on later launches; Settings shows on
  with "Blocked in your phone's settings".
- Turn the switch off → reopen Settings → still off (saved).
