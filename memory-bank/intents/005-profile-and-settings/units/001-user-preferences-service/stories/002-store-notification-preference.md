---
id: 002-store-notification-preference
unit: 001-user-preferences-service
intent: 005-profile-and-settings
status: complete
priority: must
created: '2026-09-17T07:55:00Z'
assigned_bolt: null
implemented: true
---

# Story: 002-store-notification-preference

## User Story

**As a** Buna learner
**I want** my notification on/off choice to be saved
**So that** it's ready and correct whenever real notifications eventually ship

## Acceptance Criteria

- [ ] **Given** a signed-in user, **When** they submit a `notification_enabled` value via the new endpoint (same endpoint as story 001, or an adjacent one — Technical Design decision), **Then** it persists and is returned on subsequent reads
- [ ] **Given** an existing user from before this migration, **When** their row is read post-migration, **Then** `notification_enabled` has a sensible backfilled default (not null, not an error)
- [ ] **Given** any value of `notification_enabled`, **When** the app runs, **Then** no notification is ever sent as a result — there is no delivery system to trigger yet, by design

## Technical Notes

- New `notification_enabled: bool` column on `users`, default `true` seems like the sensible product default (opt-out, not opt-in) but confirm with the user during Technical Design rather than assuming silently
- Migration must use a fixed constant default if combined with `NOT NULL` on SQLite — see the documented `ADD COLUMN` gotcha in `memory-bank/intents/003-offline-caching-and-sync/units/001-offline-sync-service/construction-log.md`'s errata before writing this migration

## Dependencies

### Requires
- None (can share a bolt/implementation pass with story 001 given how small it is, but is tracked separately since it's a distinct FR)

### Enables
- `002-profile-and-settings-ui`'s story `001-settings-screen`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A future notification system is added later | Reads this existing field as-is; this story's job is only to make sure the field and its value are trustworthy by then |

## Out of Scope

- Building any notification-delivery system
- Any UI (see `002-profile-and-settings-ui`)
