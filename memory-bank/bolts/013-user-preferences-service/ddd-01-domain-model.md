---
stage: model
bolt: 013-user-preferences-service
created: '2026-09-17T08:15:00Z'
---

## Static Model: user-preferences-service

### Prior Decision Lookup

Scanned `memory-bank/standards/decision-index.md` (6 entries). None of the "Read when" fields match this bolt's scope (invariant amendment on `User`, new preferences endpoint). ADR-1 (session-token hashing) and ADR-2 (Apple JWT verification) concern `001-auth-service` but not this specific change; ADR-5 (client-side grading) is unrelated (lesson-exercise domain, not user preferences). No prior ADR constrains this work — noting explicitly rather than silently skipping the lookup.

### Entities

- **User** (existing, amended): `id`, `provider_identity`, `selected_language: LanguageCode`, `daily_xp_target: DailyXPTarget`, `notification_enabled: bool` (**new**), `created_at`. Business rule (amended invariant): `selected_language` and `daily_xp_target` are set once at creation; the **only** sanctioned post-creation mutation path for either is the new `UpdateUserPreferences` operation — no other code path may write them. `notification_enabled` carries no write-once restriction: it is freely mutable via the same operation and is never null (backfilled `true` for rows that predate this field).

### Value Objects

- **LanguageCode** (existing, reused unchanged): no new allowed values introduced by this bolt.
- **DailyXPTarget** (existing, reused unchanged): no new allowed values introduced by this bolt.
- **UserPreferencesUpdate** (new): `language: LanguageCode | None`, `daily_xp_target: DailyXPTarget | None`, `notification_enabled: bool | None` — a partial-update input; `None` on a field means "leave unchanged," not "clear it." Construction of the non-None `LanguageCode`/`DailyXPTarget` values already enforces the valid-option-set constraint (existing validation pattern), so this value object adds no new validation rules of its own.

### Aggregates

- **User** (aggregate root, no child entities). Invariants:
  - `selected_language`/`daily_xp_target`: write-once-then-sanctioned-update (amended from strict write-once).
  - `notification_enabled`: always non-null; freely mutable.
  - A `UserPreferencesUpdate` with all fields `None` is a valid no-op (submitting unchanged values must succeed, per story 001's edge case).

### Domain Events

- None. This codebase has no event-driven/domain-event infrastructure anywhere (consistent with every prior bolt, including the lesson-completion and offline-sync flows, which are all direct request/response) — introducing one here for a simple preference update would be new, unjustified complexity.

### Domain Services

- **UserPreferencesService**: Operation `update_preferences(user: User, update: UserPreferencesUpdate) -> User` — applies only the non-None fields of `update` to `user` and returns the updated aggregate. Dependencies: `UserRepository` (to persist the result). No cross-entity coordination needed (single-aggregate operation).

### Repository Interfaces

- **UserRepository** (existing, amended): add a persistence method for saving an updated `User` (exact method name/signature — e.g. `update`/`save` — is a Technical Design decision, matching this repository's existing naming convention rather than inventing a new one).

### Ubiquitous Language

- **Preference update**: The deliberate, sanctioned mutation of `selected_language`/`daily_xp_target`/`notification_enabled` after account creation, via `UpdateUserPreferences`.
- **Write-once-then-sanctioned-update**: The amended invariant replacing strict "write-once forever" for `selected_language`/`daily_xp_target`.
- **Notification-inert**: `notification_enabled` is stored and returned faithfully, but no code path currently reads it to trigger a delivery — there is no delivery system yet.

### Corrected during Stage 4 (Implement)

Reading the actual `services.py`/`use_cases.py` source (permitted at Stage 4, forbidden here at Stage 1) showed the existing `AuthenticationService.authenticate_with_google`/`_authenticate` methods take individually-optional loose parameters (`pending_language_code: str | None`, `pending_daily_goal_minutes: int | None`), not a bundled value object — `PendingSelectionInput` is only used as a single all-or-nothing application-layer DTO, wrapping a *group* that's optional as a whole. This bolt's three fields are independently optional (any subset may be omitted), which doesn't fit that DTO's "optional as a group" shape. `UserPreferencesUpdate` as a standalone value object was dropped in favor of matching the established loose-parameter convention: `UserPreferencesService.update_preferences(user, language_code, daily_goal_minutes, notification_enabled)`. No behavior differs from what this domain model specified — only the shape of how the three optional fields travel through the call chain.

### Story Coverage

| Story | Covered By |
|-------|-----------|
| 001-update-daily-goal-and-language | `User` invariant amendment, `UpdateUserPreferences`/`UserPreferencesService`, `UserPreferencesUpdate` (language/goal fields) |
| 002-store-notification-preference | `User.notification_enabled`, `UserPreferencesUpdate.notification_enabled`, backfill note on the entity |
