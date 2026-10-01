---
stage: plan
bolt: 075-league-screen
created: '2026-10-01T08:04:11Z'
---

## Implementation Plan: league-screen

### Objective

Stories 006 and 007 (FR-9, FR-2's time left, FR-7's switch, FR-6's
notice): the app's league screen, showing the learner's tier, the time
left and their group's ranking with the move-up and move-down zones, from
`GET /api/v1/leagues/current`, with a saved copy for offline; the "Show
me in leagues" switch in Settings; and a one-time note that others in the
group see your first name. The result sheet and the dashboard card are
bolt 076.

### What the code says (checked before planning)

- **F1 Clients.** Signed-in calls follow `HttpUserPreferencesApi`: the
  token is read from `SessionRepository` on every request and nothing is
  logged but a status. `AppConfigApi` shows the "never throws, `null` on
  failure" style.
- **F2 Account settings in the app.** `AccountSettings` (known keys) is
  empty; `RemoteSettingsController` reads them from the session check and
  keeps a copy on the phone (keyed by account id), but has no way to write
  one: bolt 072 left `PATCH /users/me/settings` for the first setting with
  a control (its D6). That is this one.
- **F3 Settings screen** builds rows from `ListRowGroup`, `SwitchRow` and
  `ListRow`; the Notifications switch is optimistic and puts itself back
  with a snack bar when saving fails (`SettingsController._applyUpdate`).
- **F4 Navigation.** Screens are pushed with `MaterialPageRoute` from the
  dashboard. Its only menu is the course panel (course rail, "Course
  settings", "Manage downloads"); the header holds the course control and
  the stat pills, with no room to spare.
- **F5 Colours** come from `context.colors` (palette roles, both themes)
  and `AppTone`; a design rule forbids fixed colours. The backend sends an
  avatar colour as an index 0-7 and a tier as a key.
- **F6 Tests.** The screen sweep renders every screen at two phone sizes,
  two text scales and both themes; a scene list must cover every screen.

### Decisions

- **D1 Where the code goes**: `lib/features/league/`:
  - `league_models.dart`: `LeagueTier` (the five keys, display name,
    icon and tone: Green Bean `eco`, Light Roast `local_cafe`, Medium
    Roast `coffee`, Dark Roast `coffee_maker`, Golden Cup `emoji_events`),
    `LeagueStatus`, `LeagueMember`, `CurrentLeague` (with
    `lastResult` parsed but unused until 076), each with a lenient
    `fromJson` (an unknown tier or status reads as the lowest tier /
    not joined, so a newer backend never breaks an older app);
  - `league_api.dart`: `LeagueApi` with `HttpLeagueApi.current()`
    (throws `LeagueApiException`, like the lesson API);
  - `league_store.dart`: the last response saved on the phone with the
    time it was fetched (one key, `league_current`), forgotten when the
    account changes (the listener `main.dart` already uses);
  - `league_controller.dart`: loads the saved copy at once, then fetches;
    states `loading`, `ready` (fresh), `saved` (offline, with the time it
    was saved) and `unavailable` (offline with nothing saved);
  - `screens/league_screen.dart` and `widgets/league_row.dart`,
    `widgets/tier_badge.dart`.
- **D2 The screen** (`AppPage`, back button, title "Weekly league"):
  - a header card with the tier badge and name, "3 days left" (days,
    then hours under a day, then "Ends soon" under an hour), and a line
    "Top N move up · bottom N move down" from the endpoint's zone sizes
    (only the parts that apply);
  - the ranking: one `LeagueRow` per member (place, avatar, name, XP),
    the learner's own row highlighted with the primary tone and "You",
    the top three with their Amole reward; dividers labelled "Moving up"
    under the last promoted place and "Moving down" above the first
    demoted one;
  - not joined: an empty state "Earn XP this week to join" with "Start a
    lesson", which pops back to the dashboard;
  - hidden: an empty state explaining the switch is off, with a button
    that turns it on (D4) and reloads;
  - saved copy: a small "Offline · updated 2 h ago" status above the
    header, everything else as saved; nothing saved and offline: an
    offline empty state ("Connect to see your league") with Retry, not an
    error screen;
  - pull to refresh.
- **D3 Colours.** Avatars: eight (face, letter) pairs built from existing
  palette roles in one place (`leagueAvatarColours(palette)`), so both
  themes are covered without new roles; the contrast test gains these
  pairs (3:1, large text). Tiers use `AppTone`s. No fixed colours.
- **D4 The switch** (story 007):
  - `AccountSettings.showInLeagues = KnownSetting<bool>('show_in_leagues',
    true)`, one line, matching the backend;
  - `AccountSettingsApi.update(changes)` calls
    `PATCH /api/v1/users/me/settings` and returns the full map;
  - `RemoteSettingsController.updateAccount(changes, api)`: shows the
    change at once, saves the returned map (same saved copy as the
    session check), and puts it back if saving fails;
  - Settings gets a "Show me in leagues" `SwitchRow` (subtitle "Others in
    your league see your first name") in a new "League" section; a failed
    save shows "Couldn't save. Check your connection." like the others.
- **D5 The name notice**: the first time the league screen shows a
  ranking, a card above it says "Others in your league see your first
  name." with the switch inside it and a "Got it" button; "Got it" (or
  turning the switch off) hides it for good (a flag on the phone,
  `league_notice_seen`).
- **D6 How to get there for now**: a "Weekly league" row in the course
  panel's menu, next to "Course settings" and "Manage downloads". The
  dashboard card in bolt 076 becomes the main way in; the row stays.
- **D7 Wiring**: `LeagueDependencies` built in `main.dart` (API, store,
  controller factory), passed to the dashboard like the other bundles.

### Out of scope (bolt 076)

- The last-week result sheet and `POST .../last-result/seen`.
- The dashboard card and refreshing it after a lesson.
- The "League reward" label in the Amole history.

### Tests

- Models: parsing a full response; unknown tier, status or extra fields;
  missing members; `last_result` present or null.
- API: the path and the bearer token; 401 and other errors throw; a
  malformed body throws.
- Store: round trip with the time saved; a corrupt copy reads as none;
  forgotten on an account change.
- Controller: saved copy first, then fresh; offline with a copy is
  `saved`, without one `unavailable`; refresh.
- Screen (widget tests): joined (rows in order, my row marked, rewards on
  the top three, the zone dividers in the right places, time left),
  not joined, hidden (button turns the switch on), saved copy banner,
  unavailable with Retry; the notice appears once and "Got it" hides it.
- Settings: the switch reads the account setting, writes it, and puts
  itself back with a message on failure.
- Course panel: the "Weekly league" row opens the screen.
- Contrast test: the avatar pairs in both themes.
- Screen sweep: the league screen (joined, not joined, hidden, offline)
  in both themes, both sizes and text scales.
- Full `flutter test --exclude-tags e2e`, `flutter analyze`, a debug APK.

---

## Implement (stage 2)

### What was built

- **`lib/features/league/`** (new):
  - `league_models.dart`: `LeagueTier` (key, title, icon, tone),
    `LeagueStatus`, `LeagueMember`, `LeagueResult` (parsed for 076),
    `CurrentLeague` (with `rewardFor(rank)`), each with a lenient
    `fromJson` and a `toJson` for the saved copy;
    `leagueAvatarColours(palette)`: the eight avatar pairs, each tone's
    filled badge (`fill`/`onFill`) then its light face (`surface`/`ink`).
  - `league_api.dart`: `LeagueApi` and `HttpLeagueApi.current()` (token
    per request, 20 s timeout, `LeagueApiException` on any failure).
  - `league_store.dart`: the last league with its fetch time
    (`league_current`) and the notice flag (`league_notice_seen`);
    `forget()` clears both.
  - `league_controller.dart`: `loading`, `ready`, `saved`,
    `unavailable`; the saved copy first, then a fetch; a failed fetch
    keeps what is showing and marks it with its time.
  - `league_dependencies.dart`: API, store and settings API; registers
    `store.forget` as an account-changed listener.
  - `widgets/league_widgets.dart`: `TierBadge`, `LeagueAvatar`,
    `LeagueRow`, `LeagueZoneDivider`, and the texts `leagueTimeLeft`,
    `leagueZoneSummary`, `leagueUpdatedAgo`.
  - `screens/league_screen.dart`: as planned (D2), with pull to refresh.
- **Account settings writes**: `lib/shared/settings/account_settings_api.dart`
  (`HttpAccountSettingsApi.update`); `AccountSettings.showInLeagues`;
  `RemoteSettingsController.updateAccount` (shows the change at once,
  keeps the returned map, puts it back and rethrows on failure; it now
  remembers which account its copy belongs to) and
  `RemoteSettingsScope.maybeOf`.
- **Settings**: a "League" section with the "Show me in leagues" switch
  when the screen is given an `AccountSettingsApi` and a settings scope.
- **Course panel**: a "Weekly league" row when given `onLeague`.
- **Dashboard and `main.dart`**: `LeagueDependencies` built in `main`,
  passed to `BunaApp` and the dashboard (optional, so existing tests are
  unchanged); the dashboard opens the league screen and gives Settings
  the settings API.

### Changes from the plan

- **The notice has a "Stay out" button instead of a switch**: "Got it"
  and "Stay out" side by side read more clearly than a switch inside a
  card; "Stay out" turns the setting off, hides the notice and reloads
  (the screen then shows the "not in a league" state with a button to
  turn it back on).
- **Gallery**: not changed; the league widgets live in the feature and
  are covered by the screen sweep (next stage).

### Checked so far

- `flutter analyze`: no issues. Full app suite: 1812 passed (no new tests
  yet).
- A throwaway widget test rendered a joined league of eight at 360x640 in
  both themes: "Abebe (You)", "Moving up", "2 days left" and the notice
  all showed, with no overflow.

---

## Test (stage 3)

### Results

- Full app suite (`flutter test --exclude-tags e2e`): **1906 passed** (94
  new). `flutter analyze`: no issues. Debug APK built.

### Found and fixed by the sweep

- **A ranking row overflowed by 4.5 px** on a 360 px phone at 1.3x text:
  the first place's reward badge plus its XP left no room for the name.
  The reward and XP now sit together in a box of at most 132 px that
  scales down, so the name always keeps room.

### New tests

- `test/features/league/league_data_test.dart` (22):
  - parsing: a full response in rank order with `rewardFor`; unknown
    tiers, statuses, extra and missing fields; not a league is null; a
    last result survives the saved copy;
  - `HttpLeagueApi`: path, method and bearer token; offline, 401, bad JSON
    and a non-league body all throw;
  - `LeagueStore`: round trip, a corrupt copy, the notice flag, `forget`,
    and a new account forgetting it;
  - `LeagueController`: the saved copy then a fresh one (saved in turn);
    offline with a copy (`saved`, with its time); offline with none
    (`unavailable`, then a retry); a failed refresh keeps the league;
    the notice only with a ranking, until dismissed, also after a restart;
  - texts: time left, who moves, updated ago;
  - account settings: `show_in_leagues` defaults on; an update shows at
    once and keeps the saved map; a failed one is put back and rethrown;
    `HttpAccountSettingsApi` patches and reads back, and throws on a
    refusal, offline or a bad body;
  - all eight avatar letters at least 3:1 on their circle in both themes.
- `test/features/league/league_screen_test.dart` (11): header, my row,
  rewards and the two zone lines in the right places; a small group with
  no line where nobody moves; alone, no lines; not joined; switched off,
  and turning it back on (also failing offline with a message); offline
  with a saved copy and its age; offline with nothing saved and Retry; the
  note shown once until "Got it" (also after reopening); "Stay out"; a row
  read as one phrase.
- `test/features/settings/screens/settings_league_test.dart` (5): the
  switch shows the account setting and saves a change; a failed save
  puts it back with a message; no League section without the API or the
  scope; the course panel's "Weekly league" row, and none without a
  callback.
- `test/design/screen_sweep_test.dart` (+7 scenes, 56 runs): the league
  (30 members, a long name, a five-digit XP, the notice), scrolled to the
  bottom, not joined, switched off, offline with and without a saved copy,
  and Settings with the league switch; both themes, 360x640 and 430x932,
  1.0x and 1.3x.
- `test/helpers/fake_league_api.dart` (new): `leagueJson`, `league`,
  `FakeLeagueApi`, `FakeAccountSettingsApi`.

### Not tested here

- Against the real backend: it isn't deployed with leagues yet (needs a
  push). The client's requests match the backend's tested contract.
- On a phone: to check by hand with the debug APK once the backend is
  live.
