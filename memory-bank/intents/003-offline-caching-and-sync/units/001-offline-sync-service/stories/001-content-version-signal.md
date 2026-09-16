---
id: 001-content-version-signal
unit: 001-offline-sync-service
intent: 003-offline-caching-and-sync
status: done
priority: must
created: '2026-09-16T20:45:00Z'
assigned_bolt: 008-offline-sync-service
implemented: true
---

# Story: 001-content-version-signal

## User Story

**As a** mobile client with a downloaded lesson pack
**I want** to compare my cached pack's version against the server's current version
**So that** I know whether to re-download without needing to fetch the full content just to check

## Acceptance Criteria

- [ ] **Given** a request for skill-tree or lesson content, **When** the server responds, **Then** the response includes a version signal (int or hash) for each skill/lesson returned
- [ ] **Given** the same skill/lesson content unchanged since last fetch, **When** fetched again, **Then** the version signal is identical
- [ ] **Given** the content is edited server-side (e.g. a typo fix), **When** next fetched, **Then** the version signal changes

## Technical Notes

- Cheapest implementation: derive the version from an existing `updated_at` column (e.g. its epoch millis) rather than introducing a new versioning table/column — confirm feasibility in Technical Design before assuming a new column is needed.
- This story only adds the signal to the response; the client-side comparison/re-download decision lives in `002-offline-caching-and-sync-ui` story 001.

## Dependencies

### Requires
- None (additive to existing `001-lesson-service` endpoints)

### Enables
- `002-offline-caching-and-sync-ui` story 001-download-lesson-packs (needs this signal to implement the 14-day staleness check)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Skill/lesson has never been updated since creation | Version signal is still present and stable (e.g. derived from `created_at`) |
| Two lessons in the same skill updated at different times | Each carries its own version signal, not one shared per skill |

## Out of Scope

- Any client-side caching/comparison logic
- A dedicated content-versioning/audit table (only if the `updated_at`-derived approach proves insufficient)
