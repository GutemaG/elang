---
stage: plan
bolt: 108-team-read-api
created: '2026-10-13T15:20:00Z'
---

## Implementation Plan: team-api

### Objective

Story 011 (FR-10, read). `GET /api/v1/admin/team` lists owners, then
members, for super admins.

### Decisions

- **D1** New `app/infrastructure/api/team_routers.py` (prefix
  `/api/v1/admin/team`, router-level `require_super_admin`) and
  `team_schemas.py`; registered in `app/main.py` and `make_client`.
- **D2** `app/application/team_use_cases.py`: `list_team(repo, owners)`
  returns `TeamMember` rows — owners (sorted, from
  `dependencies.get_owner_emails()`, so tests' patched settings apply),
  then members by email. An owner's stored row is skipped.
- **D3** Repository: `last_sign_ins(emails)` (newest
  `auth_sessions.issued_at` per lower-cased `users.email`, one grouped
  query) and `course_titles(ids)` (one query).

### Acceptance Criteria

- [x] Every criterion of story 011.

---

## Implement (2026-10-13)

- D1–D3 as planned. Owners have `id`, `created_*`, `updated_*` null and
  no courses; a course admin's courses come back as `{id, title}` by
  title.
- Team routes added to `SUPER_ONLY`, so the sweep and the super-admin
  tests cover them.

---

## Test (2026-10-13)

- `tests/integration/test_team_api.py` (`TestList`): owners first then
  members, courses and titles, `last_signed_in_at` set or null, 403
  `super_admin_only` for a course admin. Full backend suite: 2239 passed.
