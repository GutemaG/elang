---
intent: 021-daily-reminder
phase: inception
status: complete
created: '2026-09-30T08:33:43Z'
updated: '2026-09-30T12:52:24Z'
---

# Requirements: Daily Reminder

## Intent Overview

Remind the learner once a day, at 8 pm on their phone's clock, to practise
before the streak day ends, but only if they have not practised yet that
day. This turns on the Notifications switch that intent 005 stored but left
unused. Type: mobile feature, plus one small backend field.

To keep the file count small, this file also holds the system context, and
the unit briefs will hold their stories (as in intent 013).

### Verified against the source (2026-09-30)

- **The switch exists but does nothing.** Settings has a "Notifications"
  switch (`settings_screen.dart`); `SettingsController.updateNotificationEnabled`
  saves `notification_enabled` on the server (intent 005, FR-4: "stored, not
  yet wired"). New users start with it **on**.
- **No notification code anywhere.** There is no notification package in
  `pubspec.yaml` and nothing in the Android manifest or iOS `Info.plist`.
- **The streak day is UTC.** A day counts when a lesson (not a review) is
  completed on it, by the UTC date of `completed_at`. In Ethiopia (UTC+3)
  the day runs from 3 am to 3 am local, so 8 pm local is always inside the
  same streak day.
- **The app can't tell whether today is practised.** The dashboard's skill
  tree carries only `streak_count`. The lesson result carries
  `streakIncreasedToday` and `isReview`, so the app does know when a lesson
  it just finished counted.
- **The app also runs on the web** (`web/`), where these notifications
  won't work.

## System Context

- **Actors:** the learner; the phone's notification system.
- **Mobile app:** schedules, cancels and reschedules the reminder on the
  phone; asks for permission; wires the Settings switch.
- **Backend:** the skill tree answer gains `practised_today` (true when a
  non-review lesson was completed on today's UTC date). No new table, no
  migration.
- **Out of the picture:** Firebase and server push, the admin site, Neon
  data, R2.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Fewer lost streaks | A learner who hasn't practised by 8 pm gets one reminder | Must |
| Don't nag | No reminder on a day already practised, and at most one a day | Must |
| The switch means what it says | Off means no reminders; on asks for permission | Must |

## Functional Requirements

### FR-1: One Evening Reminder
- **Description**: At 8:00 pm in the phone's own time zone, the phone
  shows one reminder, unless that day is already practised or reminders are
  off.
- **Acceptance Criteria**:
  - Fires at 8:00 pm local, following the phone's time zone (travel and
    daylight saving included).
  - At most one reminder a day.
  - Works with the app closed and offline: the phone schedules it, not the
    server.
  - Tapping it opens the app on the dashboard.

### FR-2: Skip a Practised Day
- **Description**: A day already practised gets no reminder.
- **Acceptance Criteria**:
  - Finishing a lesson that counts for the streak (not a review, not
    Practice) cancels that day's reminder, online or offline.
  - When the dashboard loads with `practised_today: true`, that day's
    reminder is cancelled too (practised on another device).
  - "That day" is the streak day (UTC) containing that evening's 8 pm, so
    the reminder and the streak always agree.
  - The following days' reminders stay scheduled, so the reminder still
    comes if the app isn't opened for days.

### FR-3: The Message
- **Description**: The reminder names the streak at stake.
- **Acceptance Criteria**:
  - With a streak: "Keep your 12-day streak going" / "A quick lesson is
    enough." (singular for 1: "1-day streak").
  - With no streak: "Time for today's lesson" / "A quick lesson keeps you
    going."
  - The number is the last streak the app saw; it is refreshed whenever
    the dashboard loads or a lesson finishes.

### FR-4: The Settings Switch
- **Description**: The existing Notifications switch controls the
  reminder.
- **Acceptance Criteria**:
  - Turning it on asks the phone for notification permission (Android 13+
    and iOS) if not yet given; if refused, the switch goes back to off and
    a line says it can be allowed in the phone's settings.
  - Turning it off cancels every scheduled reminder.
  - The switch's subtitle says what it does: "A reminder at 8 pm if you
    haven't practised".
  - The server-side value stays the source of truth across devices; on
    sign-in the app schedules or cancels to match it.
  - Signing out cancels every reminder.

### FR-5: Ask Once on First Launch
- **Description** (changed 2026-09-30 at the learner's request; it used to
  be "never asks on its own"): reminders are on by default, and the app
  asks for permission once, the first time a signed-in learner reaches the
  dashboard after installing.
- **Acceptance Criteria**:
  - The first dashboard after install asks for notification permission
    once (Android 13+ and iOS), if the saved value is on and permission is
    not given yet. It never asks again on its own.
  - The switch shows the saved value (the one in the database), on by
    default. If it is on but the phone blocks notifications, the switch
    stays on and the FR-4 line appears under it.
  - Turning the switch on also asks, if permission is still missing.

### FR-6: Backend `practised_today`
- **Description**: The skill tree answer says whether today's streak day
  is already practised.
- **Acceptance Criteria**:
  - `practised_today` is true exactly when a non-review lesson was
    completed on today's UTC date (the same rule as the streak).
  - Costs no extra query beyond what the skill tree already reads, or one
    at most.
  - The saved offline dashboard keeps it.

## Non-Functional Requirements

- **NFR-1 Reliability**: reminders survive a phone restart and an app
  update (Android boot receiver; exact-alarm permission not required, a
  few minutes' drift is fine).
- **NFR-2 Battery**: no background task or polling; only scheduled
  notifications.
- **NFR-3 Web**: on the web the switch still saves, but nothing is
  scheduled and nothing crashes.
- **NFR-4 Testability**: the scheduler sits behind an interface with a fake,
  so widget tests don't touch the plugin.
- **NFR-5 Accessibility**: the switch and its explanation line are one
  readable node; the notification text is plain.

## Decisions

- **D1 Delivery on the phone** (answered 2026-09-30): local scheduled
  notifications (`flutter_local_notifications` plus `timezone`), not server
  push. It follows the phone's time zone for free and needs no Firebase.
- **D2 Time** (answered): fixed 8 pm in the phone's time zone; no time
  picker.
- **D3 Message** (answered): mentions the streak.
- **D4 Permission** (answered): asked only when the switch is turned on.
- **D5 Schedule 7 days ahead**: one reminder per day for the next 7 days,
  refreshed whenever the app opens, so a closed app still reminds for a
  week and then stops (a learner gone for over a week isn't nagged).
- **D6 The streak day stays UTC.** Making the streak day follow the
  learner's own time zone is a separate, larger change to the backend.

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Should the reminder also appear on iOS now, or Android only first? | User | **Resolved** (2026-09-30): both now; the iOS check is left for a person with a Mac |
| Should the streak number in the message be shown as 0 after a missed day (bolt 059's Q1)? | User | **Resolved** (2026-09-30): no; it uses the stored streak, same as the dashboard |
