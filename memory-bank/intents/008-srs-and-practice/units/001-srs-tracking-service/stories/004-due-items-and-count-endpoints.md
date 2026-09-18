---
id: 004-due-items-and-count-endpoints
unit: 001-srs-tracking-service
intent: 008-srs-and-practice
status: complete
priority: must
created: '2026-09-17T17:02:00Z'
assigned_bolt: null
implemented: true
---

# Story: 004-due-items-and-count-endpoints

## User Story

**As a** Buna learner (via the Practice UI)
**I want** to know how many words are due and fetch exactly those for a session
**So that** Practice only ever shows me what's actually due, never a stale or over-fetched set

## Acceptance Criteria

- [ ] **Given** a user with due vocab items, **When** the due-items endpoint is called with a limit, **Then** it returns up to that many items, ordered ascending by `next_review_at`, each with enough data to resolve their linked exercise(s)
- [ ] **Given** the same user, **When** the due-count endpoint is called, **Then** it returns a count matching what the due-items query would return (no `next_review_at <= now()` mismatch between the two queries)
- [ ] **Given** a user with zero due items, **When** either endpoint is called, **Then** it returns an empty list / `0`, not an error

## Technical Notes

- Both endpoints share the same `WHERE user_id = ? AND next_review_at <= now()` predicate — implement once, reuse (e.g. a shared repository method with/without a `LIMIT`), so they can't drift out of sync.
- Index `user_vocab_progress(user_id, next_review_at)` to keep the due-count cheap enough to call on every dashboard/entry-point load (NFR: Performance).

## Dependencies

### Requires
- `003-leitner-box-algorithm` (needs real `next_review_at` data to query against)

### Enables
- `002-practice-ui`'s stories

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A due vocab item has no linked exercise reachable (shouldn't happen given FR-1's linking, but verify) | Excluded from due-items results rather than returned as an unusable entry — confirm this can't actually occur given the FK relationship, and only add filtering if it genuinely can |

## Out of Scope

- Session assembly/UI (see `002-practice-ui`)
