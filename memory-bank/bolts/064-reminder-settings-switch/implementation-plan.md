---
stage: plan
bolt: 064-reminder-settings-switch
created: '2026-09-30T12:30:00Z'
---

## Implementation Plan: reminder-settings-switch

### Objective

Story 004 (FR-4, FR-5): the Settings "Notifications" switch controls the
8 pm reminder. Turning it on asks the phone for permission; a refusal
leaves it off with a way to the phone's settings; off and sign-out cancel
every reminder; the app never asks on its own.

### What the code says (checked before planning)

- **F1: The switch today.** `SettingsController.updateNotificationEnabled`
  saves `notification_enabled` on the server optimistically and reverts on
  failure. `load()` reads it from the session check. The row is a
  `SwitchRow`, which already takes a `subtitle`.
- **F2: Settings is opened from the dashboard**, which builds
  `SettingsScreen` with its services; it has `widget.reminders` (bolt 063).
- **F3: Two ways out.** "Log out" in Settings
  (`SettingsController.logout`) and "Please sign in again" on the
  dashboard (`_signInAgain`) both call `clearSession()` and go to sign-in.
- **F4: The server value reaches the phone** only through the session
  check: in Settings, and in the background at every launch
  (`SessionRenewer.renew`, which drops the user it gets back). Signing in
  returns no preferences.
- **F5: The plugin** asks with `requestNotificationsPermission()`
  (Android 13+) and `requestPermissions(alert, badge, sound)` (iOS), and
  opens the phone's settings for the app with
  `openAppNotificationSettings()`. Android stops showing the prompt after
  two refusals, so from then on only the phone's settings can allow it.

### Decisions

- **D1: What the switch shows** = the server value **and** the phone's
  permission. So a learner whose value is on (the default) but who never
  allowed notifications sees it off, with no prompt (FR-5). On the web,
  where nothing is scheduled, it shows the server value alone (NFR-3).
- **D2: Turning it on**
  1. Asks the phone (does nothing if already allowed).
  2. Allowed: saves on the server (as today, reverting on failure), keeps
     it on this device and schedules the week.
  3. Refused: saves nothing; the switch stays off; the blocked line
     appears (D4).
- **D3: Turning it off** saves on the server, keeps it on this device and
  cancels every reminder.
- **D4: The blocked line.** When the server value is on but the phone
  blocks notifications, a row under the switch: "Blocked in your phone's
  settings", tapping it opens the phone's notification settings for the
  app. When the learner comes back to the app, Settings checks again, so
  allowing them there turns the switch on without another tap.
- **D5: Subtitle** on the switch: "A reminder at 8 pm if you haven't
  practised".
- **D6: Keeping this device in step with the server.**
  - Settings load: the server value is kept on the device and the
    schedule rebuilt.
  - Every launch: `SessionRenewer` passes the checked user on, and the
    device keeps its `notification_enabled`. So a switch turned off on
    another phone stops this phone's reminders from the next launch.
- **D7: Signing out** (both ways, F3) cancels every reminder and forgets
  the practised day and the streak, so the next account starts clean.
- **D8: Where the code goes.**
  - `ReminderScheduler` gains `supported`, `requestPermission()` and
    `openSettings()` (the plugin, the fake and the web no-op).
  - `ReminderService` gains `supported`, `isPermitted()`,
    `requestPermission()`, `setEnabled(bool)`, `openSettings()` and
    `signedOut()`.
  - `SettingsController` and `SettingsScreen` take an optional
    `reminders` (the dashboard passes it); `null` keeps today's
    behaviour, so existing tests are untouched.
  - `SessionRenewer` takes an optional `onChecked(SessionUser)`;
    `AuthDependencies` passes it through. `main.dart` builds the storage
    first so the reminders and auth share it.

### Out of scope

- A time picker; asking after the first lesson (FR-5 says never on its
  own).
- Signing in on a new Android 12 phone with the switch off elsewhere: it
  may schedule until the next launch's session check (D6). No prompt is
  involved, and it corrects itself.

### Tests

- `ReminderService`: `setEnabled` on and off; `signedOut` cancels and
  forgets; `requestPermission` passes through; unsupported.
- `SettingsController` with the fake scheduler:
  - load: on + allowed → on; on + blocked → off and blocked; off → off.
  - on, allowed → saved and scheduled; on, refused → nothing saved, off,
    blocked; on, allowed, server fails → reverted and not scheduled.
  - off → saved and cancelled.
  - log out cancels.
  - web (unsupported): the server value, no permission calls.
  - checking again after returning from the phone's settings.
- Settings screen: the subtitle; the blocked row appears and opens the
  settings; tapping the switch on a blocked phone asks.
- `SessionRenewer`: passes the user on; nothing on a failure.
- Dashboard: "sign in again" cancels.

### Acceptance criteria

- [ ] Turning on asks when needed; a refusal leaves it off with the
  blocked line.
- [ ] Turning off, or signing out, cancels every reminder.
- [ ] Never asks on its own; on but not allowed shows off with the line.
- [ ] The subtitle reads "A reminder at 8 pm if you haven't practised".
- [ ] This device follows the server value at launch and in Settings.
- [ ] `flutter analyze` clean; `flutter test` passes; Android builds.
- [ ] On a phone: the prompt, a refusal, allowing it in the phone's
  settings, and the reminder arriving (left for a person; iOS needs a Mac).

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-30.

### Changed

- **`ReminderScheduler`**: `supported`, `requestPermission()` (Android
  13+ prompt; Android 12 and older answer yes; iOS alert, badge and
  sound) and `openSettings()` (the plugin's
  `openAppNotificationSettings`). The web no-op is unsupported.
- **`ReminderService`**: `supported`, `isPermitted()`,
  `requestPermission()`, `openSettings()` (each swallowing a plugin
  failure), `setEnabled(bool)` and `signedOut()`.
- **`ReminderStore`**: `clearForSignOut()` and a signed-out mark;
  `refresh()` (a dashboard load, so signed in) clears the mark.
- **`SettingsController`** (optional `reminders`):
  `notificationEnabled` is now saved-on **and** allowed;
  `notificationsBlocked`; turning on asks first; the device keeps the
  saved value (load and each change); `recheckNotificationPermission()`;
  `openNotificationSettings()`; `logout()` cancels.
- **`SettingsScreen`** (optional `reminders`): the subtitle; the
  "Blocked in your phone's settings" row (tap opens them); checks again
  when the app comes back to the front.
- **Dashboard**: passes `reminders` to Settings; "sign in again" cancels.
- **Launch**: `SessionRenewer.onChecked`, through
  `AuthDependencies(onSessionChecked:)`; `main.dart` builds the storage
  first and keeps the checked `notification_enabled` on the device.

### Not in the plan

- **A refusal saves "on"** (the plan said it saves nothing). The switch
  still shows off with the blocked line, exactly as planned; saving the
  learner's "on" is what lets allowing it in the phone's settings turn the
  switch on by itself, with no second tap. Saving nothing would have left
  the server "off" behind a switch that then showed on.
- **The signed-out mark.** Forgetting the account puts the switch back to
  its default (on), which would have scheduled reminders for nobody right
  after logging out; the mark keeps everything cancelled until a
  dashboard loads signed in.
- `dart format` also rewrapped one existing line in
  `settings_controller.dart` (the daily-goal update call).

### Tests (+22)

- `test/features/settings/state/settings_reminders_test.dart` (10, new):
  load on + allowed, on + blocked (never asks), off; on → asks, saves,
  schedules; refusal → off and blocked; allowed later → on by itself; a
  failed save reverts; off cancels; log out cancels; the web.
- `test/features/settings/screens/settings_notifications_test.dart` (5,
  new): the subtitle; the blocked row opens the phone's settings; back to
  the app, allowed → on; tapping on asks and a refusal shows the row; log
  out cancels.
- `reminder_service_test.dart` (+4): on/off; signing out (cancelled,
  forgotten, off until signed in); asking and opening settings; the web.
- `session_renewer_test.dart` (+2): the account is passed on; nothing
  offline.
- `dashboard_reminder_test.dart` (+1): "sign in again" cancels.

## Checks (Stage 2)

- `flutter analyze`: no issues.
- `flutter test --exclude-tags e2e`: 1542 passed (was 1520).
- No Android or iOS project files changed in this bolt.

---

## Test Report (Stage 3)

Implement approved 2026-09-30.

### Runs

| Suite | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test --exclude-tags e2e` | 1542 passed |
| Settings, reminders, session renewer, dashboard reminder and signed-out tests, and the app boot test, repeated | 107 passed, 3 of 3 runs |
| Design rules (`test/design`) | 211 passed |

### Acceptance criteria

- [x] Turning on asks when needed; a refusal leaves it off with the
  blocked line (`settings_reminders_test`, `settings_notifications_test`).
- [x] Turning off, or signing out, cancels every reminder (both ways out:
  Settings and "sign in again").
- [x] Never asks on its own; on but not allowed shows off with the line
  (the load tests assert no request).
- [x] The subtitle reads "A reminder at 8 pm if you haven't practised".
- [x] This device follows the server value at launch and in Settings
  (`session_renewer_test`, the load tests).
- [x] `flutter analyze` clean; `flutter test` passes. No Android files
  changed since bolt 063's build.
- [ ] On a phone: the prompt, a refusal, allowing it in the phone's
  settings, and the reminder arriving. Not tried yet.

### Not covered here

- The real prompt and the phone's settings page (plugin calls; only on a
  device).
- iOS: not built.
- A fresh sign-in on a phone where notifications are already allowed,
  with the switch off on another phone: reminders run until the next
  launch's session check (the plan's known gap).

### Left for a person

- Android 13+: Settings shows the switch off; turn it on → the prompt;
  allow → on, and a reminder at 8 pm unless a lesson is done that day.
- Refuse the prompt → off with "Blocked in your phone's settings"; tap it,
  allow notifications there, come back → the switch is on.
- Turn it off → no reminder that evening. Log out → none either.
- iOS on a Mac: build, then repeat.
