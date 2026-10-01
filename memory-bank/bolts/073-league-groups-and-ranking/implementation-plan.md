---
stage: plan
bolt: 073-league-groups-and-ranking
created: '2026-10-01T06:24:57Z'
---

## Implementation Plan: league-groups-and-ranking

### Objective

Stories 001-004 (FR-1 to FR-4, FR-6 and FR-7 backend, FR-8 for an open
week): learners join a group of their tier with the week's first XP, the
group is ranked by the week's XP through `GET /api/v1/leagues/current`,
Google first names are stored at sign-in, and "Show me in leagues" is the
first account setting. Closing a week (moves, rewards, last-week result)
is bolt 074; this bolt's migration already holds its columns, so the
intent needs only one migration.

### What the code says (checked before planning)

- **F1 Sign-in.** `AuthenticationService._authenticate` writes an existing
  user only through `UserRepository.set_email`, and only on change.
  `GoogleTokenVerifier` returns `VerifiedIdentity(subject, email)`; the
  verified claims also hold `given_name`. Apple's token has no name.
- **F2 Completions.** `POST /lessons/{id}/complete` and
  `POST /practice/complete` call `complete_lesson` /
  `complete_practice_session`, which know only `user_id`; the routers have
  the full `User` (with `settings`). Both are idempotent: a retry returns
  the stored outcome. Lesson XP is stored with the phone's
  `client_completed_at`; practice with server `now`. A review awards 0 XP.
- **F3 One transaction per request** (`get_db_session` commits at the end).
  An `IntegrityError` would fail the whole completion. The codebase's style
  is check-then-write with the unique constraint as a backstop
  (`add_if_new`).
- **F4 XP sums** already exist per day (`sum_xp_by_user_between`, lessons
  only); both attempt tables are indexed on (`user_id`, `completed_at`).
- **F5 Amole sources** are a CHECK constraint
  (`ck_amole_transactions_source`), so bolt 074's `league_reward` needs a
  schema change: it goes in this bolt's migration (like
  `c29bf2c53433` did for `practice_session`).
- **F6 Settings.** `ACCOUNT_SETTINGS` is empty; `PATCH /users/me/settings`
  runs `update_account_settings`; the router has the `User`.
- **F7 Head** is `c8e1f4a7b2d5` (bolt 071).

### Decisions

- **D1 Tables** (one migration, revising `c8e1f4a7b2d5`):
  - `league_groups`: `id`, `week_start` (date, a Monday), `tier`
    (string, CHECK of the five keys), `created_at`, `closed_at`
    (nullable, set by 074). Index (`week_start`, `tier`).
  - `league_members`: `id`, `group_id` (FK), `user_id` (FK), `week_start`
    (copied from the group so it can be unique), `joined_at`; for 074,
    nullable `final_xp`, `final_rank`, `tier_after`, `reward_amole`,
    `result_seen_at`. **UNIQUE (`user_id`, `week_start`)**: one group per
    learner per week, enforced by the database. Index (`group_id`).
  - `users.first_name` (nullable, 100 chars). No backfill.
  - `ck_amole_transactions_source` gains `league_reward`, and
    `AmoleSource.LEAGUE_REWARD` is added (used in 074).
  - Downgrade drops both tables and the column and restores the old CHECK.
- **D2 Domain** (`app/domain/league.py`, pure Python):
  - `LeagueTier` (StrEnum, ordered): `green_bean`, `light_roast`,
    `medium_roast`, `dark_roast`, `golden_cup`; display names live in the
    app.
  - Constants: `LEAGUE_GROUP_SIZE = 30`, `LEAGUE_MOVE_SHARE = 0.2`,
    `LEAGUE_SMALL_GROUP = 5`, `LEAGUE_REWARDS = (100, 60, 40)`.
  - `week_start(t)` (the Monday 00:00 UTC on or before `t`) and
    `week_end(t)`.
  - `zone_sizes(n, tier)`: up = ceil(20%), down = ceil(20%); under 5
    members, up 1 and down 0; none up from Golden Cup, none down from
    Green Bean. Used by the endpoint now and by closing in 074.
  - `rank(members)`: by weekly XP desc, then earlier last completion,
    then earlier join.
  - `shown_name(first_name, user_id)` and `avatar_colour(user_id)`:
    the first name, else "Learner" plus four digits from a SHA-256 of the
    id; the colour is an index 0-7 from the same hash, which the app maps
    to palette roles (no hex from the backend).
- **D3 First name** (story 001): `VerifiedIdentity` gains `first_name`
  (Google `given_name`, trimmed, cut to 100 chars, empty means none; Apple
  always none). `_authenticate` writes it with a new
  `UserRepository.set_first_name`, only when it changed, next to the email
  (same "only on change" rule, User invariant 6 documented). New accounts
  get it at creation. Apple sign-ins never overwrite a stored Google name
  (they are separate accounts anyway).
- **D4 Joining** (story 002), `app/application/league_use_cases.py`
  `join_league_week(user, xp_earned, completed_at, now, league_repo)`,
  called by both completion routers after the use case returns:
  - Does nothing when `xp_earned` is 0 (reviews), when `completed_at` is
    not in the current week (an old offline lesson synced now), or when
    `show_in_leagues` resolves to false.
  - One query when already a member this week (the common case), so a
    lesson costs at most one extra query.
  - Otherwise: the learner's tier (the `tier_after` of their latest closed
    membership, else their latest membership's tier, else Green Bean; 074
    closes an ended group first), the oldest group of that tier and week
    with fewer than 30 members, else a new group; insert the membership.
  - A simultaneous second join is stopped by the UNIQUE constraint: the
    insert is an `INSERT ... ON CONFLICT DO NOTHING` (both SQLite and
    Postgres have it), so the lesson still completes. The size cap is checked, not locked: two learners
    joining the last seat at the same moment can make a group of 31,
    which is harmless and documented.
  - Retried completions (same `attempt_id`) are already members: no-op.
- **D5 Ranking and endpoint** (story 003): `get_current_league(user, now,
  league_repo)` returns the tier, a status (`joined`, `not_joined`,
  `hidden`), the week's end, the zone sizes, the rewards, and members in
  rank order. Weekly XP and last completion come from two grouped queries
  (lesson and practice attempts, `user_id IN` the group, inside the week),
  never stored while the week is open. Members whose `show_in_leagues` is
  now false are left out (a second guard after D6).
  `GET /api/v1/leagues/current` (signed in) returns:
  `{tier, status, week_ends_at, promote_count, demote_count, rewards,
  members: [{name, initial, avatar_colour, weekly_xp, rank, is_me}],
  last_result: null}` (`last_result` is filled by 074). No ids, no email.
- **D6 Show me in leagues** (story 004): `Setting("show_in_leagues",
  "bool", True)` in `ACCOUNT_SETTINGS` (no migration). The settings router,
  after saving, calls `apply_league_visibility(user, settings, now,
  league_repo)`: when it is false, the current week's membership is
  deleted (the tier is kept, since it comes from closed weeks).
- **D7 Repository** `LeagueRepository` protocol (domain) and
  `SqlAlchemyLeagueRepository`: `get_membership(user_id, week_start)`,
  `latest_tier(user_id)`, `find_open_group(week_start, tier, size)`,
  `add_group`, `add_member_if_new` (on conflict do nothing), `remove_member`,
  `list_members(group_id)` (joined with users for first name and settings),
  `weekly_xp(user_ids, start, end)`. A fake for unit tests.

### Out of scope (bolt 074 and later)

- Closing weeks, moves, rewards, `last_result` and its acknowledgement.
- The app (bolts 075, 076). Older apps ignore the new endpoint.

### Tests

- Unit: week boundaries (Sunday 23:59:59 vs Monday 00:00 UTC, time zones),
  `zone_sizes` for 1-30 members and the end tiers, ranking ties, shown
  name and colour stable and in range, `given_name` parsing.
- Sign-in: a Google sign-in stores and updates the first name; Apple
  doesn't; nothing written when unchanged.
- Joining: first XP joins, a second completion doesn't add a row, a
  review or an old-week offline lesson doesn't join, switched off doesn't
  join, the 31st learner starts a new group, tiers are kept apart, a
  duplicate insert (simulated race) is ignored and the lesson completes.
- Endpoint: 401 without sign-in; not joined; joined with ranking, XP from
  lessons and practice, ties, zones; hidden members left out; no ids or
  emails in the body.
- Setting: `show_in_leagues` defaults to true in the session check and the
  PATCH; turning it off removes this week's membership; a wrong type is
  422.
- Migration: upgrade from `c8e1f4a7b2d5` keeps users and gives null first
  names; the unique constraint holds; `league_reward` is accepted;
  downgrade restores the old state; single head.
- Full backend suite, ruff, mypy (only the 4 known errors elsewhere); API
  notes. Local `dev.db` backed up, then upgraded. Neon only with your
  go-ahead, after the bolt.

---

## Implement (stage 2)

### What was built

- **Domain** `app/domain/league.py` (new): `LeagueTier` (five, lowest
  first), `LeagueStatus`, the constants (`LEAGUE_GROUP_SIZE` 30,
  `LEAGUE_MOVE_PERCENT` 20, `LEAGUE_SMALL_GROUP` 5, `LEAGUE_REWARDS`
  100/60/40, `AVATAR_COLOURS` 8), `week_start`/`week_end`,
  `tier_above`/`tier_below` (for 074), `zone_sizes`, `rank`, `shown_name`,
  `avatar_colour`, and the `LeagueRepository` protocol with its small
  value types.
- **First name** (story 001): `VerifiedIdentity.first_name`;
  `first_name_from_claims` in `google_verifier.py` (trimmed, at most 100
  characters, blank or non-text is none); `User.first_name` (invariant 6);
  `UserRepository.set_first_name`; `_authenticate` writes it only when it
  changed, and new accounts get it at creation.
- **Tables** `app/infrastructure/db/league_models.py` (new) and migration
  `d3a7f2b9c6e1_add_weekly_leagues.py` (revises `c8e1f4a7b2d5`):
  `league_groups`, `league_members` (unique `user_id` + `week_start`),
  `users.first_name`, and `league_reward` in the Amole source check
  (`AmoleSource.LEAGUE_REWARD`). The downgrade deletes any
  `league_reward` rows before restoring the old check, then drops the
  tables and the column.
- **Repository** `app/infrastructure/db/league_repository.py` (new).
  `add_member_if_new` is an `INSERT ... ON CONFLICT DO NOTHING` (Postgres
  or SQLite form, picked from the session's dialect). `weekly_xp` is two
  grouped queries (lessons, practice) counting only rows with XP.
- **Use cases** `app/application/league_use_cases.py` (new):
  `join_league_week`, `apply_league_visibility`, `get_current_league`,
  `shows_in_leagues`.
- **API**: `GET /api/v1/leagues/current` (`league_routers.py`,
  `league_schemas.py`), registered in `main.py` and the test app. The
  lesson and practice completion endpoints call `join_league_week` after
  recording; `PATCH /users/me/settings` calls `apply_league_visibility`.
- **Setting**: `Setting("show_in_leagues", "bool", True)` in
  `ACCOUNT_SETTINGS`.

### API notes

`GET /api/v1/leagues/current` (signed in; 401 otherwise):

```json
{
  "tier": "green_bean",
  "status": "joined",
  "week_ends_at": "2026-10-05T00:00:00Z",
  "promote_count": 1,
  "demote_count": 0,
  "rewards": [100, 60, 40],
  "members": [
    {"name": "Abebe", "initial": "A", "avatar_colour": 1,
     "weekly_xp": 10, "rank": 1, "is_me": true}
  ],
  "last_result": null
}
```

- `status` is `joined`, `not_joined` (no XP yet this week) or `hidden`
  (switched off); `members` is empty unless `joined`.
- `tier` is one of `green_bean`, `light_roast`, `medium_roast`,
  `dark_roast`, `golden_cup`; the app owns the display names.
- `avatar_colour` is 0-7; the app maps it to palette roles.
- `last_result` stays `null` until bolt 074.
- The session check now lists `"settings": {"show_in_leagues": true}`.

### Changes from the plan

- **No fake league repository**: the use cases read and write through
  real SQL (joins, conflicts, sums), so they are tested against SQLite
  through the endpoints and the repository instead.
- **`shows_in_leagues` reads with a default of true** even if the key is
  missing, so tests that swap the registry's keys (bolt 071's) keep
  working.
- **Two bolt 071 tests updated**: the account registry is no longer empty
  (`show_in_leagues`), and the single-head check moved to the new
  `tests/integration/test_league_migration.py`.

### Checked so far

- Full backend suite: 1373 passed (before the new tests).
- ruff clean; mypy shows only the 4 known errors in files not touched.
- A throwaway end-to-end run: not joined → two practice sessions → joined
  with 10 XP, "Abebe", 1 up / 0 down (a group under 5 in the lowest tier)
  → switched off → hidden.
- Local `dev.db` backed up to `dev.db.bak-20261001T064030Z`, then upgraded
  to `d3a7f2b9c6e1`.

---

## Test (stage 3)

### Results

- Full backend suite: **1438 passed** (65 new), about 5 minutes.
- ruff clean, formatting clean. mypy on `app`: only the 4 known errors in
  files not touched; no errors in any new or changed test file.

### New and changed tests

- `tests/unit/test_league_rules.py` (new, 27): five tiers in order and
  moving stops at both ends; every moment from Monday 00:00 to Sunday
  23:59:59 UTC is one week, Monday midnight starts the next, a phone time
  zone (Addis Ababa) doesn't move it, a time with no zone is UTC; zone
  sizes for 0-31 members and both end tiers; ranking by XP, then the
  earlier last XP, then the earlier join; first name shown, else a stable
  "Learner ####"; avatar colours stable and covering 0-7.
- `tests/unit/test_google_verifier_email.py` (+6): `given_name` is
  trimmed and passed on; missing, blank, non-text gives none; a long one
  is cut to 100; the full `name` is never used.
- `tests/unit/test_authentication_service.py` (+4): a new account gets the
  first name; it follows the latest sign-in without touching preferences;
  unchanged, it isn't rewritten; Apple sign-in has none.
- `tests/integration/test_league_service.py` (new, 15), against the real
  repository on SQLite:
  - joining: the first XP joins the lowest tier; a second completion adds
    nothing; no XP, an earlier week's XP synced now, or switched off never
    joins; earlier-this-week XP synced now does; the 31st learner starts a
    new group; a learner joins the tier their last week left them in, in a
    different group from a newcomer; a simultaneous second join returns
    false, adds nothing and leaves the transaction usable; closed groups
    are never joined;
  - weekly XP: lessons and practice in the week add up, reviews and the
    week's edges are left out, the last XP time is the latest;
  - current league: not joined and hidden; a group of six ranked with a
    tie, names, initials, 2 up / 0 down in the lowest tier, rewards;
    members who switched off are left out;
  - visibility: switching off leaves this week and keeps the tier from
    past weeks; switching on changes nothing.
- `tests/integration/test_league_endpoints.py` (new, 10), through HTTP:
  401 without sign-in; not joined before any XP, with the week's end;
  practice joins and two learners are ranked with names and colours;
  members carry only the six listed fields, and no id or email of anyone
  appears in the body; an offline lesson from last week and a later review
  don't join, a lesson this week does (20 XP); `show_in_leagues` is on in
  the session check; switching it off hides the league, removes the
  learner from the other's ranking and keeps them out with more practice;
  switching back on rejoins with the next XP, counting only XP from then
  on in the group (both sessions, 10 XP); a wrong type is 422.
- `tests/integration/test_league_migration.py` (new, 4): single head
  `d3a7f2b9c6e1`; upgrade from `c8e1f4a7b2d5` keeps users with a null
  first name, starts both tables empty and accepts `league_reward`; one
  membership per learner per week and only known tiers (database
  constraints); downgrade keeps users, removes the tables, the column and
  any `league_reward` rows, and the old check refuses it again.
- Updated from bolt 071: the registry test (`show_in_leagues` is the
  first account setting) and the settings endpoint test (the session check
  lists it); the single-head test moved to the league migration test.

### Not tested here

- The endpoint's speed on Neon (NFR: p95 under 300 ms for 30). It is three
  small queries plus two grouped sums on indexed columns; to be checked
  after the Neon migration.
- The migration on Postgres: it runs in the Neon step, with your
  go-ahead, with checks before and after.
- A real Google sign-in returning `given_name` (covered with the verifier's
  claims replaced, as for the email in bolt 034).
