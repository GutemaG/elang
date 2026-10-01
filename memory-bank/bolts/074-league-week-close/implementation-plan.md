---
stage: plan
bolt: 074-league-week-close
created: '2026-10-01T07:16:08Z'
---

## Implementation Plan: league-week-close

### Objective

Story 005 (FR-5, and FR-8's `last_result`): when a league week has ended,
each of its groups is closed exactly once, on demand: the final XP and
rank of every member are stored, the top moves up a tier, the bottom moves
down, 1st to 3rd get 100, 60 and 40 Amole, and each learner sees their
result once. No migration: bolt 073's already holds every column and the
`league_reward` source, and it is on Neon.

### What the code says (checked before planning)

- **F1 Columns ready.** `league_groups.closed_at` and, on
  `league_members`, `final_xp`, `final_rank`, `tier_after`,
  `reward_amole`, `result_seen_at` exist, all null so far.
  `latest_tier` already prefers `tier_after`.
- **F2 Rules ready.** `zone_sizes`, `rank`, `tier_above`, `tier_below` and
  `LEAGUE_REWARDS` are in `app/domain/league.py`; `weekly_xp` sums the
  attempt tables for any range.
- **F3 Amole.** `AmoleTransactionRepository.add_if_new` posts a row unless
  (`source`, `reference_id`) exists, with the unique constraint as a
  backstop; `reference_id` is at most 64 characters, so a group id plus a
  user id (73) doesn't fit, but a membership id (36) does.
- **F4 The app labels Amole sources**, and an unknown one reads as
  "Amole", so older apps are fine; bolt 076 adds "League reward".
- **F5 One transaction per request**, committed at the end.

### Decisions

- **D1 What gets closed, and when.** Only the learner's own ended groups
  (their memberships from weeks before this one whose group has no
  `closed_at`), oldest first, closing each whole group. This runs:
  - at the start of `GET /api/v1/leagues/current`;
  - in `join_league_week`, just before the tier is looked up, so a
    learner's first lesson of a new week starts them in the right tier.

  A request never closes other people's groups, so its cost stays small; a
  group whose members never come back is never closed, which changes
  nothing for anyone.
- **D2 Exactly once.** Closing claims the group first with
  `UPDATE league_groups SET closed_at = now WHERE id = ? AND closed_at IS
  NULL`. Only the request whose update changed a row goes on to write the
  results, in the same transaction; on Postgres a simultaneous second
  request waits on the row lock and then changes nothing. If the request
  fails, the claim rolls back with it. The reward's unique
  (`source`, `reference_id`) is a second guard.
- **D3 The result of a group** (pure, `close_group` in the domain): rank
  the members who still show in leagues by the week's XP (as the screen
  does); the top `promote` move up and the bottom `demote` move down
  (`zone_sizes`, which already handles small groups and the end tiers),
  everyone else stays; places 1-3 get `LEAGUE_REWARDS`. Members who
  switched leagues off after the week ended get their XP and no rank,
  stay in their tier, and get no reward.
- **D4 Writing it.** Each member row gets `final_xp`, `final_rank`,
  `tier_after` and `reward_amole` (0 when none). Rewards are posted as
  `league_reward` rows with the membership id as `reference_id`, dated
  when the week ended.
- **D5 Late XP.** A lesson from that week synced after the group closed is
  stored as usual (its streak, Amole and XP history are unchanged) but
  doesn't change the stored result.
- **D6 The last-week result** in the endpoint: the learner's latest closed
  membership with no `result_seen_at`, as
  `{week_start, tier, tier_after, movement: up|down|stayed, rank,
  group_size, weekly_xp, reward_amole}`, else `null`.
  `POST /api/v1/leagues/last-result/seen` sets `result_seen_at` on all of
  the learner's closed memberships, so it is shown once and older unseen
  results never pop up later. It returns 204 and is safe to repeat.
- **D7 Code**: the domain gets `close_group` and its result type; the
  repository gets `ended_open_groups(user_id, week)`, `claim_group`,
  `save_results`, `last_unseen_result` and `mark_results_seen`;
  `app/application/league_use_cases.py` gets `close_ended_weeks` and
  `mark_last_result_seen`; `get_current_league` returns `last_result`.

### Out of scope

- Closing other learners' groups in the background (no scheduler).
- The app's result sheet and the "League reward" label (bolt 076).

### Tests

- Domain: `close_group` for groups of 1, 4, 5, 6 and 30; the end tiers;
  ties; rewards only for the places that exist; hidden members.
- Repository and use cases (SQLite): a learner's ended group closes on
  their next league read and on their first XP of a new week, and they
  join the next week in the tier it gave them; only their own groups are
  closed; closing twice changes nothing and pays nothing twice; XP synced
  after closing doesn't change the result; a learner away for weeks comes
  back in the tier their last closed week gave them.
- Rewards: the Amole balance and history show them with source
  `league_reward`.
- Endpoint: `last_result` after the week ends, then `null` after
  `POST .../last-result/seen`; repeating it is fine; 401 without sign-in.
- Full backend suite, ruff, mypy. No migration, so nothing to run on Neon.

---

## Implement (stage 2)

### What was built

- **Domain** (`app/domain/league.py`): `Movement` (`up`, `down`,
  `stayed`) and `movement(tier, tier_after)`; `MemberResult` and
  `close_group(tier, standings, hidden)`, the pure result of a group
  (D3); `EndedGroup` and `LastResult`; `GroupMember.member_id` (the
  membership id, used as the reward's reference); five new
  `LeagueRepository` methods.
- **Repository** (`league_repository.py`): `ended_open_groups`,
  `claim_group` (a conditional `UPDATE ... WHERE closed_at IS NULL`, true
  only for the request that changed the row), `save_results`,
  `last_unseen_result` (with the group size counted from ranked members),
  `mark_results_seen`; `list_members` now returns the membership id.
- **Use cases** (`league_use_cases.py`):
  - `close_ended_weeks(user_id, now, league_repo, amole_repo)`: for each of
    the learner's ended open groups, oldest first: claim it, sum the
    week's XP for every member, `close_group`, save, and post rewards as
    `league_reward` rows (`reference_id` = membership id, dated when the
    week ended);
  - `join_league_week` closes the learner's ended weeks before looking up
    their tier (only on their first XP of a week, so lessons after that
    cost nothing extra);
  - `get_current_league` closes them first and returns `last_result`;
  - `mark_last_result_seen`.
- **API**: `last_result` is now a typed object; new
  `POST /api/v1/leagues/last-result/seen` (204). The lesson and practice
  completion endpoints pass their Amole repository to the join.

### API notes

`last_result` in `GET /api/v1/leagues/current`, until marked seen:

```json
{
  "week_start": "2026-10-05",
  "tier": "green_bean",
  "tier_after": "light_roast",
  "movement": "up",
  "rank": 1,
  "group_size": 6,
  "weekly_xp": 30,
  "reward_amole": 100
}
```

- `rank` is `null` if the learner had switched leagues off by the time
  the week closed; `group_size` counts the ranked members.
- `POST /api/v1/leagues/last-result/seen` (signed in, no body): 204,
  safe to repeat; marks every closed week of the learner as seen.
- The reward appears in `GET /amole/transactions` with source
  `league_reward` (older apps show it as "Amole").

### Changes from the plan

- **One 073 test updated**: switching off after joining now also keeps
  the tier from last week as closed by the join (alone in the group, so
  moved up), instead of the unclosed group's own tier.

### Checked so far

- Full backend suite: 1438 passed; ruff and formatting clean; mypy shows
  only the 4 known errors elsewhere.
- A throwaway end-to-end run: six learners with 5 to 30 XP; a week later
  the top learner's read closed the group: 1st moved up to Light Roast
  with 100 Amole, 6th stayed (lowest tier), balances 100/60/40 for 1st to
  3rd and 0 for the rest; after marking it seen, `last_result` was null.

---

## Test (stage 3)

### Results

- Full backend suite: **1458 passed** (20 new), about 5 minutes.
- ruff and formatting clean; mypy on `app` shows only the 4 known errors
  elsewhere, and none in any league file or test.

### New tests

- `tests/unit/test_league_rules.py` (+8, `TestCloseGroup`): alone, first
  place moves up and earns 100; under five only first moves and only the
  places that exist are paid; five move one up and one down; thirty move
  six and six, paying 200 in all; nobody moves above Golden Cup or below
  Green Bean; a tie goes to whoever reached it first; a member who
  switched off keeps their XP with no place, move or reward;
  `movement`.
- `tests/integration/test_league_closing.py` (new, 12):
  - reading the league after the week closes the group: the right
    places, the top two of six moving up from the lowest tier, nobody
    down, 100/60/40 to 1st to 3rd, and the last result for a learner who
    came 6th;
  - an open week is never closed;
  - the first XP of the next week closes it and joins the new tier;
  - closing twice changes nothing and pays once, and a late claim returns
    false;
  - only the learner's own groups are closed;
  - XP synced after closing doesn't change the result;
  - a learner away for four weeks returns in the tier their last week
    gave them;
  - a learner who switched off after the week gets no place and no
    reward, and the others are ranked without them;
  - the result is offered until marked seen; marking twice is fine;
  - the reward is in the Amole history and balance as `league_reward`,
    dated when the week ended;
  - `POST /api/v1/leagues/last-result/seen` needs sign-in, returns 204 and
    is safe to repeat.

### Not tested here

- Two requests closing the same group at the same moment on Postgres. The
  conditional update is the guard; the tests show a second claim changes
  nothing, and the reward's unique constraint is the backstop.
- No migration in this bolt, so nothing to run on Neon. Everything goes
  live when the backend is deployed.
