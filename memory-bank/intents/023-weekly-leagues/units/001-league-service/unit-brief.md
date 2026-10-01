---
unit: 001-league-service
intent: 023-weekly-leagues
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-01T06:14:45Z'
updated: '2026-10-01T08:02:11Z'
---

# Unit Brief: League Service

## Purpose

Own every league rule on the backend: who is in which group, how a group
is ranked, and what happens when a week ends, so the app only has to show
one endpoint's answer.

## Scope

### In Scope
- One migration: league groups (week, tier), members (group, user, joined
  at; unique per user and week), closed results (final XP, rank, move,
  reward); `users.first_name` (nullable); existing accounts need no
  backfill
- The tier list, week boundaries and all league constants in the domain
- `given_name` from Google's verified token, stored at each sign-in
- Joining on XP-awarding lesson and practice completions
- Ranking from `lesson_attempts` and `practice_attempts`
- Closing ended weeks on demand: stored results, moves, Amole rewards
- `show_in_leagues` (bool, default true) in `ACCOUNT_SETTINGS`
- `GET /api/v1/leagues/current` and acknowledging the last-week result
- Tests on SQLite; API notes

### Out of Scope
- Any scheduler, cache or queue
- Nickname editing, photos
- Per-course leagues

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | League tiers | Must |
| FR-2 | The league week | Must |
| FR-3 | Joining a group | Must |
| FR-4 | Ranking | Must |
| FR-5 | Closing a week | Must |
| FR-6 | Names other learners see (backend) | Must |
| FR-7 | "Show me in leagues" (backend) | Must |
| FR-8 | League endpoint | Must |

---

## Domain Concepts

| Concept | Description |
|---------|-------------|
| Tier | One of five ordered leagues, Green Bean to Golden Cup. A learner's current tier is the one their last closed week left them in. |
| League week | Monday 00:00 to the next Monday 00:00 UTC. |
| Group | Up to 30 learners of one tier in one week. |
| Weekly XP | The sum of attempt XP with `completed_at` in the week; computed while open, stored when the group closes. |
| Closing | Turning an ended week's groups into stored results, tier moves and rewards, exactly once. |
| Shown name | The stored Google first name, else "Learner" and four digits from the id. |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-first-name-from-google | Store the Google first name at sign-in | Must | Complete (bolt 073) |
| 002-join-a-weekly-group | Join a group of your tier with the week's first XP | Must | Complete (bolt 073) |
| 003-ranking-and-league-endpoint | See your group ranked by the week's XP | Must | Complete (bolt 073) |
| 004-show-in-leagues-setting | Stay out of leagues with one setting | Must | Complete (bolt 073) |
| 005-close-a-week | Close an ended week with moves and rewards | Must | Complete (bolt 074) |

### 001-first-name-from-google (FR-6)

**As a** learner, **I want** others in my group to see my first name,
**so that** the league feels like real people.

- [x] `GoogleTokenVerifier` returns `given_name` (trimmed, empty treated as
  none) with the identity it already verifies.
- [x] Each Google sign-in stores it on the user, replacing an older value;
  Apple sign-in leaves it empty.
- [x] The shown name is the first name, else "Learner" and four digits
  derived from the id, the same every week; the avatar colour is derived
  from the id.
- [x] The first name is never returned anywhere except the league
  endpoint, and the email never there.

### 002-join-a-weekly-group (FR-1, FR-2, FR-3)

**As a** learner, **I want** my first XP of the week to put me in a
league, **so that** I compete without doing anything extra.

- [x] Tiers, the week boundaries (UTC Monday), the group size (30) and
  every other league constant are defined once in the domain.
- [x] A lesson or practice completion that awards XP with `completed_at`
  in the current week joins the learner if they aren't in this week's
  league and `show_in_leagues` is on; a synced offline completion from an
  earlier week does not join them now.
- [x] They are placed in a group of their tier for this week with fewer
  than 30 members, else in a new group; a learner never in a league is in
  Green Bean.
- [x] One membership per learner per week is enforced by the database;
  two simultaneous completions still give one.
- [x] Completing a lesson after joining costs at most one extra query.

### 003-ranking-and-league-endpoint (FR-4, FR-8)

**As a** learner, **I want** to see my group ranked by this week's XP,
**so that** I know where I stand.

- [x] Weekly XP sums lesson and practice attempt XP in the week; it is
  computed, not stored, while the week is open.
- [x] Ties go to the earlier last completion, then the earlier join.
- [x] `GET /api/v1/leagues/current` (signed in) returns the tier, whether
  the learner is in this week's league and why not, the week's end, the
  members in rank order (shown name, initial, avatar colour, weekly XP,
  rank, is-me), the zone sizes and the reward per place.
- [x] No member ids or other fields of other learners are returned.
- [x] p95 under 300 ms for a group of 30.

### 004-show-in-leagues-setting (FR-7)

**As a** learner, **I want** to stay out of leagues, **so that** nobody
sees my name if I don't want them to.

- [x] `show_in_leagues` (bool, default true) is one line in
  `ACCOUNT_SETTINGS`; no migration.
- [x] Off: the learner doesn't join new weeks, leaves the current week's
  group at once (others stop seeing them) and gets no reward for it; the
  tier is kept.
- [x] The endpoint says when the learner is out because of the setting.

### 005-close-a-week (FR-5)

**As a** learner, **I want** the week's result to be final and fair,
**so that** moving up and the rewards mean something.

- [x] The first league request after a week ends closes its groups; no
  scheduler.
- [x] Each group is closed exactly once, also under simultaneous
  requests (enforced by the database).
- [x] Final XP and rank are stored; XP synced later for that week doesn't
  change them.
- [x] Top 20% (rounded up) move up, bottom 20% (rounded up) move down,
  within Green Bean and Golden Cup; groups under 5 move only first place
  up. All named constants.
- [x] 1st to 3rd receive 100, 60 and 40 Amole through the ledger
  (`league_reward`, unique per group and member); a smaller group pays
  only its places.
- [x] The endpoint returns the learner's last closed result until it is
  acknowledged, then never again.
- [x] A learner away for several weeks returns to the tier their last
  closed week gave them.

---

## Dependencies

### Depends On
None (uses the settings store of intent 022 and the Amole ledger of
intent 007).

### Depended On By
- `002-league-ui`
