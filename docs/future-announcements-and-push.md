# Future: Announcements, Update Prompt and Push Notifications

Status: **idea, not started** (saved 2026-10-01). When it is picked up,
start an intent for part 1; part 2 waits until Firebase is set up.

## Why

Let an admin tell learners things from the admin site without an app
release (new lessons, events and challenges, maintenance notices,
surveys), prompt learners to update the app, and later reach them when
the app is closed.

## Part 1: Announcements and the update prompt (no Firebase)

Backend (tables, endpoints, one migration), admin site (an Announcements
page and the version settings) and mobile (pop-up, banner, inbox, update
prompt). Builds on the existing `app_config` table and
`GET /api/v1/config` (intent 022).

### How learners see them

All of this is inside the app, never in the phone's notification bar.

| Kind | Looks like | Used for | Interrupts? |
|---|---|---|---|
| Pop-up | Bottom sheet: icon, title, text, one button | Events, important news | Yes, so rare |
| Banner | Slim card at the top of the dashboard with an ✕ | New lessons, maintenance, surveys | No |
| Inbox | A bell on the dashboard with a dot; a "News" list | Every live announcement | No |

### Dismissing

- Pop-up: the main button does its action and closes it; "Not now",
  swiping down or tapping outside also close it. All count as dismissed.
- Banner: the ✕, or tapping the banner (opens it, counts as done).
- Inbox: reading an item clears its dot; items stay until they expire.

### Remembering dismissals

- On the server, per learner ("user X dismissed announcement Y at T"),
  like the league result's "seen": it follows the account across phones
  and survives a reinstall.
- On the phone too, so it hides instantly and offline, and is sent to the
  server when back online.

### What the admin sets per announcement

- Title, text, an icon from a fixed set, button label and action.
- Presentation: pop-up, banner or inbox only.
- Start and end time; after the end it disappears everywhere.
- Repeat rule: once; until the button is tapped; every N days up to M
  times.
- Priority: critical, high, normal.
- Audience: platform, app version range, course, new or existing learners.

Example:

```json
{
  "id": "meskel-2026",
  "title": "Meskel streak challenge",
  "body": "Keep your streak all week and earn 200 Amole.",
  "button": "Join", "action": "open:league",
  "presentation": "popup", "priority": "high",
  "audience": {"min_app_version": "1.4.0", "course": "amharic", "platform": "android"},
  "starts_at": "2026-09-27T00:00Z", "ends_at": "2026-10-04T00:00Z",
  "repeat": "once"
}
```

### When several are live

- At most one pop-up per app open (highest priority, then newest); the
  rest wait for the next open.
- No pop-ups during a lesson or on the first app open after sign-up; only
  on the dashboard.
- One banner at a time; the next shows after it is dismissed.
- Everything is also in the inbox, so nothing is lost.

### Update prompt

Set on the admin site per platform:

- **Recommended version** (soft): a pop-up with "Update" and "Later",
  repeated every 3 days, at most 3 times per version.
- **Minimum version** (forced): a full screen with only "Update", for when
  an old app cannot work with the backend. Use rarely.

### Ideas for using it

- New content ("5 new lessons on food"), holiday events (Timket, Meskel,
  Enkutatash, Ramadan), league news, maintenance notices, surveys for
  learners with 10+ lessons.
- Later, with the same `app_config`: kill switches (leagues, downloads),
  gradual rollouts, "coming soon" courses, tuning numbers (league rewards,
  XP, reminder time, shop prices).

### Out of scope for part 1

Push (part 2), email or SMS, hand-written messages to one learner,
replies, uploaded pictures, analytics beyond counts.

### Questions to answer when it starts (recommended answer first)

1. Where the update button goes: store pages with links set on the admin
   site; or a direct APK link until the app is in the stores.
2. A bell on the dashboard for the inbox: yes, with an unread dot; or no
   inbox.
3. Who writes announcements: any admin, no approval step; or drafts a
   second admin publishes.
4. What the button opens: a fixed list of places in the app plus web
   links; or app places only.
5. Languages: English only for now; or an optional Amharic text.
6. Limits: 1 pop-up per open and 2 a day, 1 banner at a time, soft update
   every 3 days up to 3 times.
7. Success: shown, tapped and dismissed counts per announcement on the
   admin site.

Rough size: one intent, 3 bolts (backend; admin site; app).

## Part 2: Push notifications (needs Firebase; after part 1)

Reach learners when the app is closed, in the phone's notification bar,
through Firebase Cloud Messaging (FCM covers Android, and iOS through
Apple's push service).

1. **Setup (by the owner):** a Firebase project, the Android
   `google-services.json`, the iOS APNs key, and a server key kept only in
   the backend's environment (never committed).
2. **Device tokens:** after sign-in the app sends its FCM token; the
   backend keeps one row per user and device, refreshes it when it
   changes, and removes it on sign-out or when FCM reports it gone.
3. **Asking permission at the right moment:** not on first launch; after
   the first finished lesson, with a short reason first ("Want a reminder
   so you keep your streak?"). Android 13+ and iOS require asking.
4. **Categories in Settings:** reminders, league, news; they extend the
   existing Notifications switch.
5. **Automatic pushes:** league ("You dropped to 4th, 2 days left", "Week
   ended: you moved up!"); the streak reminder could move to the server
   so it works on every phone (today it is a local notification, intent
   021).
6. **Admin pushes:** an "Also send as push" choice on an announcement,
   with the same audience rules.
7. **No spamming:** at most two pushes a day per learner, nothing between
   22:00 and 08:00 Ethiopia time, and a tap opens the right screen.
8. **Sending without a scheduler:** the backend has no background jobs
   today; choose one (for example a cron-triggered endpoint on the host,
   or a small worker).

Rough size: one intent, 3 bolts.
