---
id: 002-timestamped-completion-for-streak-attribution
unit: 001-offline-sync-service
intent: 003-offline-caching-and-sync
status: done
priority: must
created: '2026-09-16T20:45:00Z'
assigned_bolt: 008-offline-sync-service
implemented: true
---

# Story: 002-timestamped-completion-for-streak-attribution

## User Story

**As a** Buna user who completed a lesson offline
**I want** that completion attributed to the day I actually did it, not the day my phone happened to reconnect
**So that** my streak stays accurate regardless of when sync runs

## Acceptance Criteria

- [ ] **Given** a completion call includes a `client_completed_at` timestamp, **When** the server processes it, **Then** streak/daily-XP attribution uses that timestamp's calendar day instead of the server's request-arrival time
- [ ] **Given** two offline completions whose `client_completed_at` values fall on different calendar days, **When** both sync, **Then** the streak increments once per distinct day represented, not once per lesson
- [ ] **Given** a `client_completed_at` value that is implausible (e.g. far in the future, or absurdly far in the past relative to the account's creation date), **When** the server validates it, **Then** the request is rejected with a clear error rather than silently trusted
- [ ] **Given** a streak freeze active on the day a delayed completion's `client_completed_at` falls on, **When** that completion syncs, **Then** the freeze still protects that day correctly

## Technical Notes

- Exact validation bound for "implausible" timestamps (e.g. reject anything more than N days old, or any future timestamp beyond a small clock-skew allowance) is a Technical Design decision — the requirement here is that *some* bound exists, not a specific number.
- This changes existing streak-computation logic from `002-core-lesson-loop`'s bolt 005 — must be re-verified against that bolt's existing streak tests, not just new tests added in isolation.
- `client_completed_at` is additive on the existing `LessonAttempt`/completion payload; online completions can simply pass the current time, keeping one code path for both online and offline.

## Dependencies

### Requires
- None (amends existing completion endpoint)

### Enables
- `002-offline-caching-and-sync-ui` story 003-pending-sync-queue-and-auto-sync (the client needs this field to exist before it can rely on correct day attribution)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Device clock is wrong (user manually set it incorrectly) while offline | Server-side plausibility bound catches egregious cases; minor clock skew is accepted as a known limitation, not solved by this story |
| Multiple offline completions with the exact same `client_completed_at` (e.g. batched at once) | All are accepted; streak still increments at most once for that day |
| A completion's `client_completed_at` falls on a day that already has an online completion recorded | No double-increment — streak logic is idempotent per calendar day, same as `002`'s existing rule |

## Out of Scope

- Multi-device timestamp conflicts (explicit non-goal per `requirements.md`)
- Changing how streak freezes are earned/acquired (unchanged from `002`)
