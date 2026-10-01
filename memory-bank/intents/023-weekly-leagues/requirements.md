---
intent: 023-weekly-leagues
phase: inception
status: complete
created: '2026-10-01T06:05:26Z'
updated: '2026-10-01T06:18:42Z'
---

# Requirements: Weekly Leagues

## Intent Overview

Give XP a purpose beyond the daily goal: each week, learners are placed in
a small group and ranked by the XP they earn that week. When the week
ends, the top of each group moves up a league tier, the bottom moves
down, and the top three earn a little Amole, so there is always a reason
to come back before Sunday night.

This is the "weekly leaderboard league" that `docs/PLANNING.md` lists in
the core loop (sections 2, 4 and 8). The Amole shop and the paid tier are
later intents; this one is designed so both can plug in without rework
(for example an XP boost would simply be more XP in the week).

Type: new feature; backend (new tables, endpoints, one migration) and
mobile (a league screen, a dashboard entry and a Settings switch).

To keep the file count small, this file also holds the system context, and
the unit briefs will hold their stories (as in intents 021 and 022).

### Verified against the source (2026-10-01)

- **XP already has timestamps.** XP is never stored as a total: it is
  `lesson_attempts.xp_awarded` (5 per correct answer) plus
  `practice_attempts.xp_awarded`, each row with `completed_at`, and both
  tables are indexed on (`user_id`, `completed_at`). A learner's XP for a
  week is a sum over a date range; no new XP bookkeeping is needed.
- **Offline completions carry the phone's completion time.**
  `complete_lesson` stores the validated `client_completed_at`
  (intent 003), so XP earned offline and synced later still belongs to the
  day it was earned.
- **Days are UTC today.** The streak compares `completed_at` dates in UTC.
- **Learners have no stored name.** `users` holds the provider id, the
  email (admin check only) and settings. The backend's
  `GoogleTokenVerifier` reads only `sub` and `email` from the verified
  token; Google's token also carries `given_name`. Apple's identity token
  carries no name at all. The app reads `name` from the token for its own
  Settings screen only (`ProviderProfile`, never sent to the backend).
- **No background jobs.** There is no Redis, Celery or scheduler in the
  backend (PLANNING.md suggested them; neither was built). A week has to be
  closed without one.
- **Amole has an idempotent ledger.** `amole_transactions` with a unique
  (`source`, `reference_id`) (intent 007), so a reward can be posted
  exactly once.
- **The settings store has no settings yet.** `ACCOUNT_SETTINGS` (backend)
  and `AccountSettings` (app) are empty (intent 022); "Show me in leagues"
  is their first entry.

## System Context

- **Actors:** the learner; the other learners in their group; the clock
  (the end of the week).
- **Mobile app:** the league screen, the dashboard entry, the last-week
  result, the "Show me in leagues" switch in Settings, a saved copy for
  offline.
- **Backend:** league tiers, weekly groups and members, the week's XP read
  from the existing attempt tables, closing a week (moves and rewards),
  the stored first name; the league endpoint. One migration.
- **Out of the picture:** the admin site, R2, push notifications.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Learners come back every week | Share of learners active in one week who are active again the next, compared for the 4 weeks before and after launch | Must |
| XP means something | Every active learner who is in leagues sees their rank and tier on the dashboard | Must |
| Fair and correct | Moves and rewards are computed once per group and week, never twice, and match the XP in the attempt tables | Must |
| Private by default | Other learners see only a first name and an initial; anyone can stay out | Must |
| No new infrastructure | Runs on the current backend and Neon, with no scheduler, cache or queue | Must |

---

## Functional Requirements

### FR-1: League Tiers
- **Description**: Five tiers, lowest to highest: **Green Bean, Light
  Roast, Medium Roast, Dark Roast, Golden Cup**.
- **Acceptance Criteria**:
  - Every learner has a current tier; a learner who has never joined a
    league starts in Green Bean.
  - Tier names, order and count are defined once in the backend domain;
    the app shows what the backend sends, with its own icon and colour per
    tier from the palette (both themes).
- **Priority**: Must
- **Related Stories**: 002

### FR-2: The League Week
- **Description**: A league week runs from Monday 00:00 to the following
  Monday 00:00 **UTC**, the same clock as the streak.
- **Acceptance Criteria**:
  - XP counts in the week that contains its `completed_at` (the phone's
    completion time for offline lessons).
  - The app shows the time left in the week.
- **Priority**: Must
- **Related Stories**: 002, 006

### FR-3: Joining a Group
- **Description**: A learner joins the current week's league with their
  first XP of the week, if "Show me in leagues" is on.
- **Acceptance Criteria**:
  - Joining happens when a lesson or practice session that awards XP is
    recorded for the current week (online, or on sync of an offline one
    still inside the current week).
  - The learner is placed in a group of their tier for this week that has
    fewer than **30** members; if none has room, a new group is started.
    With few learners a group is simply smaller.
  - A learner is in at most one group per week (enforced by the database),
    also when two completions arrive at the same time.
  - Learners who earn no XP in a week do not join, so inactive accounts
    never fill a group; their tier is kept.
- **Priority**: Must
- **Related Stories**: 002

### FR-4: Ranking
- **Description**: A group is ranked by each member's XP for the week.
- **Acceptance Criteria**:
  - Weekly XP = the sum of `xp_awarded` from lesson and practice attempts
    with `completed_at` in the week; it is computed, never stored, while
    the week is open.
  - Ties are broken by who reached their total first (the earlier last
    completion ranks higher), then by join time.
  - The ranking always matches the attempt tables; a lesson completed a
    moment ago shows up the next time the league is opened.
- **Priority**: Must
- **Related Stories**: 003

### FR-5: Closing a Week
- **Description**: When a week has ended, each of its groups is closed
  once: the final ranking is stored, members move up or down, and the top
  three are rewarded.
- **Acceptance Criteria**:
  - A week is closed on the first league request after it ends (no
    scheduler). Closing is idempotent and safe when several requests
    arrive at once: each group is closed exactly once.
  - The final XP and rank of each member are stored when the group
    closes; XP synced later (an offline lesson from that week) does not
    change a closed result.
  - **Moves**: the top 20% of a group (rounded up) move up a tier and the
    bottom 20% (rounded up) move down, never below Green Bean or above
    Golden Cup. In a group of fewer than 5, only first place moves up and
    nobody moves down. The percentages and the threshold are named
    constants.
  - **Rewards**: 1st, 2nd and 3rd place receive **100, 60 and 40 Amole**
    (named constants) through the Amole ledger with source `league_reward`
    and a reference per group and member, so a reward can never be paid
    twice. A group of fewer than three pays only the places it has.
  - A learner who missed the next week entirely still has their moved
    tier waiting when they come back.
- **Priority**: Must
- **Related Stories**: 005, 008

### FR-6: Names Other Learners See
- **Description**: Learners in a group see each other's **first name** and
  an initial avatar; nothing else about another learner.
- **Acceptance Criteria**:
  - The first name comes from Google's verified `given_name` claim, read
    by the backend's `GoogleTokenVerifier` and stored on the user at each
    sign-in (updated if it changed). The app never sends a name of its own.
  - Learners without one (Apple sign-in, a Google account with no given
    name, or an account that hasn't signed in again since this ships) are
    shown as **"Learner"** followed by four digits derived from their id,
    stable from week to week.
  - The avatar is the name's first letter on a coloured circle whose
    colour is derived from the id; no photo, last name or email is ever
    sent to another learner.
  - The first time a learner opens the league, the screen says that
    others in their group see their first name, with a link to the switch
    in FR-7.
- **Priority**: Must
- **Related Stories**: 001, 007

### FR-7: "Show Me in Leagues"
- **Description**: A switch in Settings, on by default, stored as the
  first account setting (`show_in_leagues`, a bool defaulting to true)
  in the JSON settings store of intent 022.
- **Acceptance Criteria**:
  - It is one line in the backend's `ACCOUNT_SETTINGS` and one in the
    app's `AccountSettings`, and is written with
    `PATCH /api/v1/users/me/settings`. No migration.
  - When it is off, the learner does not join new weeks, is removed from
    the current week's group (others no longer see them) and receives no
    reward for it; their tier is kept for when they turn it back on.
  - When it is off, the league screen explains why the learner isn't in a
    league and offers to turn it on.
- **Priority**: Must
- **Related Stories**: 004, 007

### FR-8: League Endpoint
- **Description**: One signed-in endpoint returns everything the league
  screen and the dashboard entry need.
- **Acceptance Criteria**:
  - `GET /api/v1/leagues/current` returns: the learner's tier; whether
    they are in this week's league (and why not: no XP yet, or switched
    off); the week's end time; their group's members in rank order, each
    with first name, initial, avatar colour, weekly XP, rank and whether
    it is the learner; the promotion and demotion zone sizes; and the
    learner's result of the last closed week they took part in, until
    they have seen it.
  - Showing the last-week result is acknowledged by the app so it is shown
    once (a small endpoint, or a field in the next request; settled in
    design).
  - Calling it closes any ended week first (FR-5).
  - Member ids are not exposed; no field of another learner other than
    those listed above.
- **Priority**: Must
- **Related Stories**: 003, 005

### FR-9: League Screen
- **Description**: A screen showing the learner's tier, the time left,
  and their group's ranking with the move-up and move-down zones.
- **Acceptance Criteria**:
  - Rows show rank, avatar, first name and weekly XP; the learner's own
    row is highlighted; the zones are marked with dividers ("moving up",
    "moving down"); the top three show their Amole reward.
  - Not yet joined this week: an empty state ("Earn XP this week to join
    the league") with a button to start a lesson.
  - Switched off: the FR-7 explanation and a button to turn it on.
  - After a week closes: a one-time result sheet ("You moved up to Light
    Roast", "You finished 2nd and earned 60 Amole", or "You stayed in
    Medium Roast").
  - Offline: the last saved copy, marked as not up to date; never an
    error screen.
  - Both themes, built from the design system's components and palette
    roles, with no fixed colours.
- **Priority**: Must
- **Related Stories**: 006, 007, 008

### FR-10: Dashboard Entry
- **Description**: The home dashboard shows the learner's tier and rank
  this week, opening the league screen.
- **Acceptance Criteria**:
  - Shows tier and rank ("Light Roast · 4th"), or "Join this week's
    league" before the first XP of the week, or nothing when switched off.
  - Updates after a lesson is completed, without a restart.
- **Priority**: Must
- **Related Stories**: 009

---

## Non-Functional Requirements

| Area | Requirement | Target |
|------|-------------|--------|
| Performance | `GET /api/v1/leagues/current` with an open week | p95 under 300 ms for a group of 30 on Neon |
| Performance | Lesson completion with joining | No more than one extra query when the learner already joined this week |
| Correctness | Joining, closing and rewards under concurrent requests | Exactly one group per learner per week, each group closed once, each reward posted once (database constraints, not only code) |
| Both databases | Behaviour on SQLite (dev, tests) and Postgres (Neon) | Same results; tested on SQLite like intent 022 |
| Privacy | What another learner can see | First name, initial, avatar colour, weekly XP, rank; nothing else |
| Offline | League screen without a connection | Last saved copy, never an error screen |
| Infrastructure | New services | None: no scheduler, cache or queue |
| Compatibility | Older app versions | Unaffected; the endpoint and the name field are additions |

## Constraints

- One migration: league tables (groups, members, closed results) and the
  user's first name column; existing accounts start in Green Bean with no
  backfill.
- XP rules do not change (`XP_PER_CORRECT_ANSWER`, practice XP).
- The Amole ledger is used as is, with one new source.
- Week and tier constants live in the backend domain, like the Amole and
  bean constants.

## Decisions

- **D1 First name from Google** (owner, 2026-10-01): other learners see the
  verified Google first name; Apple and nameless accounts get a stable
  "Learner 1234". No nickname editing in this intent.
- **D2 Five coffee tiers** (owner accepted recommendation): Green Bean to
  Golden Cup.
- **D3 Groups up to 30, top and bottom 20% move**, small groups (under 5)
  only promote first place (owner accepted recommendation).
- **D4 Join with the first XP of the week** (owner accepted
  recommendation).
- **D5 Top-three Amole rewards** of 100, 60 and 40 (owner accepted
  recommendation).
- **D6 Weeks in UTC**, Monday 00:00 (owner accepted recommendation).
- **D7 "Show me in leagues"**, on by default, as the first account setting
  (owner accepted recommendation).
- **D8 Close weeks on demand**, on the first league request after the week
  ends, since there is no scheduler.
- **D9 Weekly XP computed from attempts**, not stored, until the week
  closes; then the final result is stored.

## Out of Scope

- Amole shop, XP boosts, paid tier, ads (later intents).
- Friend leaderboards and following learners.
- League notifications (the daily reminder of intent 021 stays as is).
- Editing the shown name, profile photos.
- Separate leagues per course: one league per account, across courses.

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| What name do other learners see? | User | **Resolved** (2026-10-01): Google first name (D1) |
| Tiers, group size, how many move | User | **Resolved** (2026-10-01): D2, D3 |
| Rewards for finishing high | User | **Resolved** (2026-10-01): D5 |
| Week end and time zone | User | **Resolved** (2026-10-01): D6 |
| Can a learner stay out? | User | **Resolved** (2026-10-01): D7 |
