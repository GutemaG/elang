---
unit: 001-match-pairs-service
intent: 004-match-pairs-exercise-type
phase: inception
status: complete
created: '2026-09-17T04:25:00Z'
updated: '2026-09-17T04:25:00Z'
---

# Unit Brief: Match-Pairs Service

## Purpose

Extend the existing lesson-service backend (`001-lesson-service` from `002-core-lesson-loop`) with a 4th exercise type: `match_pairs`. Adds the content model and seed data only, reusing the existing `ExerciseType` dispatch pattern exactly. **No grading logic** — per ADR-5, all exercise grading in this codebase is client-side; see `../002-match-pairs-ui/unit-brief.md`.

## Scope

### In Scope
- `ExerciseType.MATCH_PAIRS` enum value
- Content model (`MatchPairsContent`: shuffleable left/right tile columns) + answer-key model (`PairAnswerKey`: the correct pairing) — **corrected during Implement, 2026-09-17**: `content`/`answer_key` are kept separate (mirroring `multiple_choice`), not merged into one self-revealing blob as originally planned; see `../../bolts/011-match-pairs-service/ddd-01-domain-model.md`'s correction note
- A migration widening `ck_exercises_type`'s `CHECK` constraint (also corrected during Implement — originally assumed unnecessary)
- At least one seeded `match_pairs` exercise in the curriculum

### Out of Scope
- Client UI rendering **and grading** (both owned by `002-match-pairs-ui` — grading is client-side per ADR-5, corrected during Construction on 2026-09-17; see story `002-grade-match-pairs-attempts` in this unit's `stories/` for the retraction record)
- Any change to Beans/XP/streak award logic (reused exactly as-is from bolt 005)
- Any change to the other 3 exercise types

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Match-Pairs Content Model | Must |

FR-2 (Match-Pairs Grading) was originally assigned here but reassigned to `002-match-pairs-ui` during Construction — see that unit's brief and `requirements.md`'s FR-2 for the corrected description.

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `MatchPairsContent` | Renderable content for a `match_pairs` exercise | `left_tiles`/`right_tiles`: two `Choice` tuples (Amharic terms / English translations) |
| `PairAnswerKey` | Correct-answer data for a `match_pairs` exercise | `correct_pairs`: tuple of `(left_choice_id, right_choice_id)` |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| ServeExerciseContent | Return a `match_pairs` exercise's shuffled tiles + correct pairing (existing endpoint, extended) | lesson_id | `MatchPairsContent` + `PairAnswerKey` (flattened into one response per `lesson_schemas.py`'s existing pattern) |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 1 |
| Must Have | 1 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-serve-match-pairs-exercise-content | Serve match-pairs exercise content (incl. seed data) | Must | Planned |

*(002-grade-match-pairs-attempts retired — see `stories/002-grade-match-pairs-attempts.md` for the retraction record; grading moved to `002-match-pairs-ui`)*

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| None | Extends existing `001-lesson-service` code in place |

### Depended By
| Unit | Reason |
|------|--------|
| `002-match-pairs-ui` | Needs the new content shape to render and the grading endpoint to submit against |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| None | — | — |

---

## Technical Context

### Suggested Technology
Python/FastAPI, extending `backend/app/domain/lesson/value_objects.py` (`ExerciseType`, `MatchPairsContent`, `PairAnswerKey`), `backend/app/infrastructure/db/lesson_repositories.py` (JSON mapping), `backend/app/infrastructure/api/lesson_schemas.py`/`lesson_routers.py` (response schema + mapping) — same files/patterns bolt 004/005 already established for the other 3 exercise types. Seed data goes in the existing `backend/app/infrastructure/db/seed_lesson_content.py`. A migration (`c726efa81972`, `op.batch_alter_table`) widens `ck_exercises_type`.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| Existing lesson-content endpoints | API | REST over HTTPS (no new endpoint) |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| `match_pairs` exercise content | PostgreSQL (existing `exercises` table/JSON content column) | 1 new seeded exercise minimum | Same as existing curriculum content |

---

## Constraints

- Must not change the response shape, grading behavior, or database schema for `multiple_choice`, `listening`, or `sentence_construction`.
- A migration IS required (found during Implement) to widen `ck_exercises_type`; delivered via `op.batch_alter_table` since SQLite cannot modify a `CHECK` constraint in place (verified via downgrade/upgrade round-trip).

---

## Success Criteria

### Functional
- [x] A `match_pairs` exercise is served through the existing lesson-content endpoint with no per-type special-casing beyond content shape
- [x] Served content (`left_tiles`/`right_tiles` + `correct_pairs`) is sufficient on its own for the client to grade locally (no backend grading endpoint needed)

### Non-Functional
- [x] No regression to existing exercise types (251/251 backend tests pass)

### Quality
- [x] Unit test coverage for the new content/answer-key model and its JSON mapping (100% on touched modules)
- [x] All acceptance criteria met
- [x] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 011-match-pairs-service | ddd-construction-bolt | 001 | Content model + seed data (no grading logic — client-side per ADR-5) |

---

## Notes

Small, self-contained unit — no new external dependency. One schema-risk assumption from Inception ("no migration needed") turned out wrong once Implement actually read `lesson_models.py`; fixed within this same bolt (see `ddd-02-technical-design.md`'s correction note). Single bolt was still sufficient.
