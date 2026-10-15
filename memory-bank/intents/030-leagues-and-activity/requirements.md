---
intent: 030-leagues-and-activity
phase: construction
status: complete
created: '2026-10-15T00:00:00Z'
updated: '2026-10-15T15:00:00Z'
---

# Requirements: Leagues and Activity log

## Intent Overview

Two new admin pages, for super admins only:

- **Leagues**: see this week's groups and past weeks, take a learner
  out of this week's league (cheating), and correct a member's weekly
  XP. Today leagues run with no admin view at all.
- **Activity log**: who changed what, and when, across the whole admin
  site. With several admins (intent 028) a change can't be traced or
  explained today; the `admin_write` lines only reach the server logs.

Everything works without a new app release: the app already shows what
`GET /leagues/current` returns, so removals and XP corrections apply on
the next open.

By the owner's choice the intent is built straight from these
requirements, without units, stories or bolts.

## Current state (2026-10-15)

| Topic | What is there |
|---|---|
| Leagues | Intent 023: `league_groups` (week, tier, `closed_at`) and `league_members` (one per learner and week; `final_xp`, `final_rank`, `tier_after`, `reward_amole` written on closing). Weekly XP is never stored while the week is open: it is summed from `lesson_attempts` and `practice_attempts`. |
| Closing | Lazy: `close_ended_weeks` runs when a member opens their league or earns XP, ranks with `close_group`, pays Amole through `amole_transactions`. A group stays "ended, not closed" until one of its members comes back. |
| Joining | A learner's first XP of the week joins them (`join_league_week`); switching "Show me in leagues" off removes this week's membership. |
| Admin writes | About 50 admin write routes (`tests/integration/admin_route_rules.py`). Use cases log one `admin_write action=… entity=… id=… admin=…` line, to the server log only. |
| Roles | Intent 028: `require_super_admin`; the route sweep test needs every admin route in `admin_route_rules.py`. |
| Admin sign-in | Learners can't use the admin site: an account that isn't an owner or on the team gets 403 `not_admin` on every admin route, and the site shows "Not authorised". Unchanged here. |

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| See how leagues are going | Every group of this week, with its ranked members, and every past week's results, on one page | Must |
| Keep leagues fair | A cheater can be taken out of this week's league, and wrong XP corrected, without touching the database | Must |
| Trace every admin change | Each successful admin change is recorded with who, when, what and where it opens | Must |

## Scope

In scope: the Leagues page and its API; the two league corrections and
their effect on the app's league screen and on closing; the activity
log for every admin write route.

Out of scope:

- Push notifications and in-app announcements (#6). They need a new app
  release, which waits until the app is published. A later intent.
- Learner actions (disable, delete, reset). Not wanted.
- Keeping a learner out of all future leagues. A removal is for one
  week; repeat it the next week if needed.
- Closing a week from the admin site. Closing stays lazy, as today.
- Logging sign-ins and reads.

---

## Functional Requirements

### Leagues — backend

#### FR-1: Removal and XP correction are stored
- **Description**: Two new nullable columns on `league_members`, one
  migration.
- **Acceptance Criteria**:
  - `removed_at` (timestamp) and `removed_reason` (text): set when a
    super admin takes the member out of the week.
  - `xp_adjustment` (integer, default 0, may be negative) and
    `xp_adjustment_reason` (text).
  - A member's **league XP** is their summed XP plus `xp_adjustment`,
    never below 0. It is used everywhere XP ranks: the learner's league
    screen and `close_group`.
- **Priority**: Must

#### FR-2: What a removed member gets
- **Description**: Out of this week, without a new app release.
- **Acceptance Criteria**:
  - Other learners no longer see them in the group.
  - The membership row stays, so their next XP doesn't put them back in
    this week.
  - Their own league screen shows `not_joined` for the rest of the week
    (the app's existing "Earn XP this week to join" state).
  - On closing they get no place, no move and no reward; their tier
    stays as it was. Next week they join as usual.
  - Members ranked behind them move up a place at once.
- **Priority**: Must

#### FR-3: This week's leagues
- **Description**: `GET /api/v1/admin/leagues?week=YYYY-MM-DD`, super
  admin only. Without `week`: the current week.
- **Acceptance Criteria**:
  - Returns the week (start, end, `is_current`, `closes_in` for the
    current one), totals (groups, members, removed, XP earned), and the
    weeks that have groups (newest first), for the week picker.
  - Each group: id, tier, member count, status (`open`, `ended`
    (waiting to close), `closed`), promote and demote counts.
  - Each member: user id, first name and the name others see, email,
    rank, league XP, earned XP, adjustment and its reason, last XP time,
    joined time, and whether hidden (switched leagues off) or removed
    (with the reason). For a closed group: final XP, final rank, tier
    after, movement and Amole reward, as stored.
  - Ranking for open and ended groups is exactly what the app computes
    (`rank`, `zone_sizes`), so the page and the app agree.
  - Groups by tier, highest tier first. A bad `week` → 422
    `invalid_content`, `field: week`.
- **Priority**: Must

#### FR-4: Remove a member
- **Description**: `POST /api/v1/admin/leagues/members/{member_id}/remove`
  `{reason}`, and `…/restore`, super admin only.
- **Acceptance Criteria**:
  - Only a membership of the current week, whose group isn't closed;
    otherwise 409 `league_week_closed`. Unknown → 404
    `league_member_not_found`.
  - `reason` is required, 3 to 200 characters, else 422
    `invalid_content`, `field: reason`.
  - Restore clears `removed_at` and the reason, in the same week only.
- **Priority**: Must

#### FR-5: Correct weekly XP
- **Description**: `PUT /api/v1/admin/leagues/members/{member_id}/xp`
  `{adjustment, reason}`, super admin only.
- **Acceptance Criteria**:
  - Sets the adjustment (it replaces the old one, it doesn't add to it),
    between -100000 and 100000; 0 clears it and its reason.
  - A reason, 3 to 200 characters, is required for a non-zero value.
  - Current week, group not closed, as FR-4.
  - The response is the member as FR-3 returns them, with the new rank.
- **Priority**: Must

### Leagues — admin site

#### FR-6: Leagues page
- **Description**: `/leagues`, in the Learners area of the nav (next to
  Dashboard and Feedback), super admin only.
- **Acceptance Criteria**:
  - A week picker (this week first, then past weeks) and, for this
    week, how long until it ends.
  - Totals: groups, members, removed, XP this week.
  - Groups grouped by tier (Golden Cup first), each one a table: Rank,
    Learner (name and email), XP (with a note when adjusted), Last XP,
    and the promote and demote zones marked as the app marks them.
    Filters: tier and search by name or email.
  - Removed and hidden members are listed at the end of their group,
    greyed, with a badge.
  - Past weeks: the stored results (final rank, XP, moved up / down /
    stayed, Amole). A group still waiting to close says so and shows the
    live ranking.
- **Priority**: Must

#### FR-7: Corrections on the page
- **Description**: Only in the current week.
- **Acceptance Criteria**:
  - Each member has "Adjust XP" and "Remove from this week" (or
    "Restore") in a row menu, each in a dialog that asks for the reason.
  - Adjust XP shows the earned XP, the new total and the rank it would
    give.
  - Errors stay in the dialog; the group reloads after each change.
- **Priority**: Must

### Activity log — backend

#### FR-8: Every admin change is recorded
- **Description**: One `admin_activity` table, written for every
  successful admin write.
- **Acceptance Criteria**:
  - Each entry: id, time, admin email and role, method and route, a
    short action label ("Published lesson", "Moved audio to trash"),
    area (Curriculum, Vocabulary, Workbook, Sounds, Voices, Audio
    library, Languages, Team, App updates, Feedback, Leagues), the
    target's id and, where known, its name (lesson title, letter,
    email…), the course it belongs to, and a few details (for
    example the number of files trashed, an XP change and its reason).
  - Recorded only after the change succeeded (2xx). A failed or refused
    request isn't recorded.
  - Content text, request bodies, audio, secrets and session tokens are
    never stored.
  - If writing the entry fails, the change still succeeds and the
    failure is logged.
  - Every admin route that isn't `GET` has an action label; a test fails
    when a new write route has none (like the role sweep).
  - Entries are kept for 2 years.
- **Priority**: Must

#### FR-9: Activity API
- **Description**: `GET /api/v1/admin/activity`, super admin only.
- **Acceptance Criteria**:
  - Filters: admin email, area, course, from and to dates, search (in
    the action, target name and id).
  - Newest first, 50 per page, with a cursor for the next page.
  - Also returns the admins and areas that appear, for the filters.
- **Priority**: Must

### Activity log — admin site

#### FR-10: Activity log page
- **Description**: `/activity`, under Configuration next to Team,
  super admin only.
- **Acceptance Criteria**:
  - A table: When (relative, exact on hover), Admin, Area, Action,
    Target, Course. Details expand in the row.
  - Filters for admin, area, course, dates and search, with "Clear
    filters". "Load more" for older entries.
  - A target that still exists has "Open", going to the same place the
    rest of the site uses (lesson, Workbook lesson, letter, team…).
- **Priority**: Must

---

## Non-Functional Requirements

### Security
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Super admin only | Every new route behind `require_super_admin`, added to `SUPER_ONLY` | A course admin gets 403 `super_admin_only` |
| Learner privacy | Emails only on super-admin routes; the app's league response is unchanged | |

### Performance
| Requirement | Metric | Target |
|-------------|--------|--------|
| Leagues page | One week, a few hundred members | One request, under 1 s |
| Activity log | Recording | One insert per write, in the same request |

### Reliability
| Requirement | Metric | Target |
|-------------|--------|--------|
| Closing | Removals and adjustments on closing | Same results as the page showed at the end of the week |

---

## Constraints

- No app release: the app's league response keeps its shape.
- Production database changes (the migration on Neon) need the owner's
  go-ahead.

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| Showing a removed learner `not_joined` is acceptable | They may think they still have to earn XP | Repeat only for real cheating; a clear "removed" state can come with a later app release |
| A few hundred league members per week | Page gets slow | Paging per group can come later |

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Announcements and push (#6) | Owner | After the app is published | Deferred to a later intent |

---

## Implementation notes (2026-10-15)

Built straight from these requirements (no units, stories or bolts).

| Part | Where |
|------|-------|
| Migration `d7b3e9a2c5f1` | `admin_activity` table; `league_members.removed_at`, `removed_reason`, `xp_adjustment` (default 0), `xp_adjustment_reason` |
| League XP | `league_xp()` in `app/domain/league.py`, used by `_standings` (app screen and closing) and the admin page |
| Removal | `get_current_league` returns `not_joined` for a removed member and leaves them out of others' groups; closing treats them like a hidden member; `last_unseen_result` skips them |
| Leagues API | `admin_league_routers.py`, `admin_league_use_cases.py`; admin queries on `SqlAlchemyLeagueRepository` |
| Activity log | `require_admin` is now a `yield` dependency: it names the target before the route runs and writes the entry after it succeeded, in the same transaction (a savepoint, so a failed entry never fails the change). Labels in `ADMIN_ACTIONS` (`app/domain/activity.py`); `None` marks upload links and link checks, which aren't recorded. Use cases add counts and reasons with `note_activity`. Entries older than 2 years are pruned on each write. |
| Activity API | `activity_routers.py`, `activity_use_cases.py`, `activity_repository.py`; cursor paging, 50 a page |
| Admin site | `src/leagues/` (`/leagues`, under Learners) and `src/activity/` (`/activity`, under Configuration) |

Decisions made while building:

- A non-delete change is named again after it ran, so a renamed lesson
  shows its new title; a delete keeps the name read before it and has no
  Open link.
- Groups come from the server highest tier first; the page keeps that
  order.

Tests: `test_admin_leagues.py` (24), `test_admin_activity.py` (15),
`test_admin_activity_migration.py` (3); the single-head check moved there
from `test_admin_members_migration.py`. Admin: `leagues.test.tsx` (10),
`activity.test.tsx` (9).

Not done here: `alembic upgrade head` on Neon (now two revisions behind:
`c4e8a1f6d2b7` from intent 028 and `d7b3e9a2c5f1`), which needs the
owner's go-ahead.
