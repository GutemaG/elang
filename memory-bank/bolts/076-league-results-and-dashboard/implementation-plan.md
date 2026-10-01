---
stage: plan
bolt: 076-league-results-and-dashboard
created: '2026-10-01T08:51:05Z'
---

## Implementation Plan: league-results-and-dashboard

### Objective

Stories 008 and 009 (FR-9's result sheet, FR-10): when a league week has
closed, the learner sees how it went once, in a sheet; the dashboard
shows their tier and rank and opens the league; and the Amole history
names league rewards. This is the intent's last bolt.

### What the code says (checked before planning)

- **F1 The result is already parsed.** `CurrentLeague.lastResult` (bolt
  075) holds the tier before and after, the place, the group size, the XP
  and the Amole; the backend offers it until
  `POST /api/v1/leagues/last-result/seen` (bolt 074), which returns 204
  and is safe to repeat.
- **F2 The dashboard** loads the tree, beans and due count together in
  `_load()` (with a saved copy first) and calls it again after every
  lesson and practice session (`_reload`) and when offline completions
  finish syncing. Under the header it has a sync banner and the Practice
  card, then the path.
- **F3 Sheets** use `showAppSheet` and the library's sheet frame, like the
  level-up and out-of-beans sheets.
- **F4 Amole history** names each source in `AmoleEntry.reason`
  (`stat_history.dart`); an unknown one reads "Amole", so today a league
  reward shows as "Amole".
- **F5 The league comes from `LeagueDependencies`**, which the dashboard
  already receives (optional), with the saved copy in `LeagueStore`.

### Decisions

- **D1 The dashboard card** ("League", under the Practice card), only
  when the dashboard has league dependencies:
  - joined: the tier badge, "Light Roast" and "4th of 12 · 120 XP this
    week";
  - not joined: "Join this week's league" and "Earn XP to join";
  - switched off: no card;
  - tapping it opens the league screen; coming back reloads it.
- **D2 Loading it** separately from the tree, so a league problem never
  holds up or breaks the dashboard: the saved copy at once, then
  `LeagueApi.current()` (saved in turn); offline the saved copy stays,
  and with none there is no card. It is fetched again by every `_reload`
  (after a lesson, practice or a sync), so a first lesson of the week
  turns "Join" into a rank without a restart.
- **D3 The result sheet** (`showLeagueResultSheet`):
  - moved up: "You moved up to Light Roast!", with the new tier's badge;
  - stayed: "You stayed in Medium Roast";
  - moved down: "You dropped to Light Roast. Climb back this week!";
  - a line with the place ("You finished 2nd of 12 with 140 XP") and,
    with a reward, "+60 Amole";
  - one button, "Continue".

  Shown by the dashboard when a fetched league carries a result, and by
  the league screen if it gets one first; once closed (any way), the app
  calls `markResultSeen()`. If that fails (offline), the backend still
  has it unseen and it is shown again next time, which is what "waits for
  the next time" means; within one app run it is shown once (the screen
  and dashboard share a flag in `LeagueDependencies`).
- **D4 API**: `LeagueApi.markResultSeen()` (POST, throws
  `LeagueApiException`); the fake gains it.
- **D5 Amole label**: `'league_reward' => 'League reward'`.

### Out of scope

- League notifications, the Amole shop, friends.

### Tests

- Card: joined (tier, place, XP), not joined, switched off (no card),
  offline with a saved copy, offline with nothing saved (no card), no
  league dependencies (no card); tapping opens the league screen; a
  reload after a lesson updates it.
- Sheet: up, stayed and down texts; reward shown only when there is one;
  no place when the learner had switched off; "Continue" closes it and
  marks it seen; shown once per run; marked again next time when marking
  failed.
- Amole history: "League reward".
- Screen sweep: the dashboard with the card (joined and not joined) and
  the three sheets, in both themes, sizes and text scales.
- Full app suite, `flutter analyze`, a debug APK.

---

## Implement (stage 2)

### What was built

- **Result sheet** (`lib/features/league/widgets/league_result_sheet.dart`,
  new): `LeagueResultSheet` on `SheetHero` with the new tier's icon and
  tone; titles "You moved up to X!", "You stayed in X", "You dropped to
  X"; the body "You finished 2nd of 12 with 140 XP." (or "You had left
  the league before the week ended." with no place), plus "Climb back
  this week!" after a drop; a "+60 Amole" badge when there is a reward;
  "Continue". `ordinal(n)` and `showLeagueResultSheet`.
- **API**: `LeagueApi.markResultSeen()` (`POST
  /api/v1/leagues/last-result/seen`, 204 or 200 is fine); the token
  lookup is shared by both calls.
- **Once per run**: `LeagueDependencies.showResultOnce(context, league)`
  shows the sheet if the league carries a result and it hasn't been shown
  this run, then marks it seen; a failed mark is ignored, so the backend
  offers it again next run.
- **League screen**: `onLeague` is called with every fresh league; the
  dashboard passes `showResultOnce`.
- **Dashboard**: `_loadLeague()` (saved copy, then a fetch saved in turn,
  then `showResultOnce`), run at start, by every `_reload` and after
  coming back from the league screen; `LeagueCard` under the Practice card
  (joined: tier, "4th of 12 · 120 XP this week"; not joined: "Join this
  week's league" and "Earn XP to join · <tier>"; switched off or nothing
  loaded: no card). It is public, so tests and the sweep can find it.
- **Amole history**: `'league_reward' => 'League reward'`.

### Changes from the plan

- **The not-joined subtitle names the tier** ("Earn XP to join · Light
  Roast"), so a learner who moved up sees it before their first lesson.

### Checked so far

- `flutter analyze`: no issues. Full app suite: 1906 passed (no new tests
  yet; the fake league API gained `markResultSeen`).

---

## Test (stage 3)

### Results

- Full app suite (`flutter test --exclude-tags e2e`): **1959 passed** (53
  new). `flutter analyze`: no issues. Debug APK built.
- The sweep found nothing to fix.

### New tests

- `test/features/league/league_results_and_card_test.dart` (13):
  - card: joined shows the tier and "3rd of 12 · 70 XP this week" and
    opens the league screen; not joined invites with the tier named;
    switched off, offline with nothing saved, and no league dependencies
    show no card; offline with a saved copy shows it; coming back from
    the league screen reloads the card (a first lesson of the week turns
    the invitation into a place);
  - sheet: titles and bodies for up, stayed, down and "had left";
    ordinals (1st to 30th, the teens); shown on the dashboard with
    "+60 Amole", "Continue" closes it and marks it seen, and the league
    screen doesn't show it again in the same run; no reward, no badge;
    marking seen offline brings it back on the next run; the league
    screen shows it when it gets it first; `HttpLeagueApi.markResultSeen`
    posts with the token and throws on an error;
  - Amole history: `league_reward` reads "League reward".
- `test/design/screen_sweep_test.dart` (+5 scenes, 40 runs): the dashboard
  with the league card (28th of 30 with 12,345 XP) and before joining;
  the result sheet moved up (with a reward), stayed and dropped; both
  themes, two sizes, two text scales.
- `test/helpers/fake_league_api.dart`: `markResultSeen` and `seenCalls`.

### Not tested here

- Against the live backend and on a phone: the backend needs the push
  first; then the debug APK can be checked by hand.
