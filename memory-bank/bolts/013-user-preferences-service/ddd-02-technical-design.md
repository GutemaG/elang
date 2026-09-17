---
stage: design
bolt: 013-user-preferences-service
created: '2026-09-17T08:25:00Z'
---

## Technical Design: user-preferences-service

### Architecture Pattern

Same layered architecture as every prior backend bolt (`001-auth-service`, `004-lesson-content-service`, `011-match-pairs-service`): domain entities/value objects → domain service → infrastructure repository → API router/schema. No new pattern introduced. One new use case (`UpdateUserPreferences`), no new layer.

### Layer Structure

```text
┌─────────────────────────────┐
│   Presentation (API)        │  PATCH /api/v1/users/me
│   lesson_routers-style       │  UserPreferencesUpdateRequest / UserResponse
├─────────────────────────────┤
│   Domain Service             │  UserPreferencesService.update_preferences
├─────────────────────────────┤
│   Domain (entities.py)       │  User (amended), UserPreferencesUpdate (new VO)
├─────────────────────────────┤
│   Infrastructure (db)        │  UserRepository (amended, +1 persistence method)
└─────────────────────────────┘
```

### API Design

- **`PATCH /api/v1/users/me`** — single endpoint for all three preference fields (decides story 002's open "same endpoint or adjacent?" question: **same endpoint**, since all three fields belong to one `UpdateUserPreferences` operation on one aggregate, and a single call avoids two round trips for what is functionally one "save my settings" action).
  - Auth: existing session-token dependency, identical to every other authenticated endpoint — no new auth mechanism.
  - Request: `UserPreferencesUpdateRequest { language: str | None = None, daily_xp_target: int | None = None, notification_enabled: bool | None = None }` — all fields optional; omitted/`None` means "leave unchanged." An empty body is a valid no-op (200, unchanged values returned).
  - Validation: `language`/`daily_xp_target` construct the existing `LanguageCode`/`DailyXPTarget` value objects — invalid values raise the same `ValueError` → 422 pattern already used elsewhere in this API (no new error-handling code path). No new allowed values are introduced.
  - Response: `UserResponse` (existing response shape), extended with `notification_enabled: bool`.
  - Idempotent: resubmitting the same values is a no-op success (per story 001's edge case), since the handler only ever sets fields to their new value regardless of prior value — no special-casing needed.

### Data Model

- **`users` table**: add `notification_enabled BOOLEAN NOT NULL`, migration `server_default=true` (constant, DB-level default — required for `NOT NULL` + `ADD COLUMN` on SQLite per the documented gotcha in `003-offline-caching-and-sync`'s errata; this backfills all existing rows to `true` at migration time, matching story 002's "opt-out, not opt-in" default and its "sensible backfill, not null" acceptance criterion).
- No `CHECK` constraint changes: unlike bolt 011 (which added a brand-new exercise type and had to widen `ck_exercises_type`), this bolt reuses `LanguageCode`/`DailyXPTarget`'s existing value sets unchanged — no enum widening, no migration beyond the one new column.
- No new table, no new foreign key.

### Security Design

- Reuses the existing session-token auth dependency verbatim. No new mechanism, no new token type, no change to `001-auth-service`'s ADR-1 (session tokens as SHA-256 hashes) — this bolt only adds a new authenticated action for an already-authenticated user.

### NFR Implementation

- **No regression to `001-auth-service`'s test suite**: the amended invariant is additive (one new sanctioned mutation path); no existing behavior is removed, so existing tests should be unaffected. Verified at Stage 5 (Test), not assumed here.

### Open Question Resolved: FR-3's "does a language change do anything else?"

Per `project.yaml`'s `mvp_phase: "Phase 1 — English to Amharic course only"`, there is currently exactly one course. Changing `selected_language` persists the new value and is honestly reflected everywhere the field is read, but — as flagged in requirements — there is no second course for it to switch content to yet. This is documented here explicitly as a known, accepted Phase-1 limitation, not a silent gap: the field is real and correctly stored, it simply has no visible downstream effect until a second language/course ships.

### Deferred to Implement (Stage 4)

- Exact `UserRepository` persistence-method name (`update`/`save`/etc.) — will match whatever naming convention `001-auth-service`'s existing repository already uses, verified by reading the actual source at Stage 4 (not guessed here, consistent with this bolt type's Stage 1-2 no-source-reading constraint).
- Exact request/response schema module/class placement (mirrors `001-auth-service`'s existing schema file, verified at Implement time).

### Integration Points

| Integration | Type | Protocol |
|-------------|------|----------|
| `002-profile-and-settings-ui` | API | REST over HTTPS, session-token auth (existing pattern) — consumes `PATCH /api/v1/users/me` |

---

### Corrected during Stage 4 (Implement)

Reading the actual source (permitted at Stage 4, forbidden at Stages 1-2) surfaced four decisions this design left open or guessed at, resolved as follows:

1. **FR-1's "view current settings" needs a read, and there was no GET endpoint planned.** Rather than add a redundant `GET /api/v1/users/me` that just duplicates the PATCH response shape, extended the existing `AuthUserResponse`/`SessionUserResponse` (returned by sign-in and `/auth/session`, which the app already calls on every restart) with `notification_enabled: bool`. `002-profile-and-settings-ui` reads current settings from whatever the app already has cached from that existing call, not a new endpoint.
2. **Error mapping**: the existing `InvalidPendingSelectionError` (raised by `LanguageCode`) is already mapped to 400, not 422 — this design's "same 422 pattern already used elsewhere" claim was wrong (that 422 convention belongs to the *lesson* domain's business-rule errors, not the *auth* domain's, which defaults to 400). Rather than force this endpoint's genuinely-invalid-request-content into that 400 bucket (or leak `InvalidPendingSelectionError`'s sign-in-specific docstring/semantics into an unrelated endpoint), added a new `InvalidPreferenceValueError` (422) specific to this endpoint, satisfying story 001's literal AC without touching sign-up's existing, unrelated 400 behavior.
3. **`daily_goal_minutes`, not `daily_xp_target`, is the request field.** `OnboardingAttachmentPolicy.map_minutes_to_daily_xp_target` already owns the one lookup table from minutes to XP (Casual=5→20 ... Intense=20→80); the new endpoint reuses it directly rather than accepting a raw XP integer and duplicating/bypassing that table.
4. **New router/schema files** (`user_routers.py`/`user_schemas.py`, prefix `/api/v1/users`), not added to the existing `/api/v1/auth`-prefixed `routers.py`/`schemas.py` — mirrors how lesson content got its own `lesson_routers.py`/`lesson_schemas.py` rather than overloading the auth router, since this is a distinct concern (preference management) from authentication.
