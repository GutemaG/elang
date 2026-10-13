---
stage: plan
bolt: 106-language-scoped-routes
created: '2026-10-13T14:40:00Z'
---

## Implementation Plan: route-permissions

### Objective

Story 009 (FR-6, FR-8). A course admin works on the Sounds charts, and
generates audio by language, only for the languages their courses
teach.

### Decisions

- **D1** `SqlAlchemyAdminContentRepository.learning_languages(course_ids)`.
- **D2** `dependencies.languages_of(access, repo)`: `None` (all) for a
  super admin, else their courses' learning languages.
- **D3** `require_language(language)`: another language is the same
  404 as a language with no chart (`entity: sound_chart`). On the six
  chart routes: GET, PATCH, add/change/delete letters, upload link.
- **D4** `GET /admin/sound-charts` filters by D2.
- **D5** `POST /admin/voice/generate` with `language` and no
  `lesson_id`: another language is 403 `super_admin_only`.
- **D6** `LANGUAGE` and `OPEN` in `admin_route_rules.py`.

### Acceptance Criteria

- [x] Every criterion of story 009.
- [x] `ruff` clean; `mypy` no new errors; full suite passes.

---

## Implement (2026-10-13)

- D1–D6 as planned.
- No deviations.

---

## Test (2026-10-13)

- `tests/integration/test_language_routes.py`: 24 passed.
- Full backend suite: 2239 passed.

| Criterion | Test |
|---|---|
| Chart list has their languages only; super admin sees all | `test_the_chart_list_has_only_their_languages`, `test_a_super_admin_lists_every_chart` |
| Chart routes: another language 404, unchanged; theirs gets through | `test_another_language_is_the_no_chart_404_and_unchanged`, `test_their_language_gets_through` (6 each) |
| Recording a letter of their chart | `test_a_course_admin_records_a_letter_of_their_chart` |
| Generate by language | `test_generating_for_another_language_is_refused`, `test_generating_for_their_language_gets_through` |
| Open routes stay open | `test_open_routes_stay_open_to_a_course_admin` (7) |
