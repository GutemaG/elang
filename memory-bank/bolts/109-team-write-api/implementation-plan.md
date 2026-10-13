---
stage: plan
bolt: 109-team-write-api
created: '2026-10-13T15:30:00Z'
---

## Implementation Plan: team-api

### Objective

Story 012 (FR-10, FR-11). Add, change and remove admins, with the team
rules.

### Decisions

- **D1** `POST /team`, `PUT /team/{member_id}`, `DELETE /team/{member_id}`
  in `team_routers.py`; rules in `team_use_cases.py`.
- **D2** Errors as FR-11. A new `AdminMemberSelfError` (409
  `admin_member_self`). Role and course ids are plain strings in the
  request, so a wrong value gets the Team page's own message, not
  Pydantic's.
- **D3** Each write logs `admin_write action=… entity=admin_member id=…
  role=… courses=… admin=…`.

### Acceptance Criteria

- [x] Every criterion of story 012.

---

## Implement (2026-10-13)

- D1–D3 as planned. Email check: one `@`, a dot in the domain, no
  spaces, after `normalise_email`.

---

## Test (2026-10-13)

- `tests/integration/test_team_api.py` (`TestAdd`, `TestChange`,
  `TestRemove`): 17 cases in all, including a stored super admin
  managing the team, nobody changing themselves, unknown ids, every
  FR-11 error, the log lines, and a removed member's next request
  being 403. Full backend suite: 2239 passed.
