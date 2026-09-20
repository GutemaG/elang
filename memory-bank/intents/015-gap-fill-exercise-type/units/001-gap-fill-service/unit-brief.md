---
unit: 001-gap-fill-service
intent: 015-gap-fill-exercise-type
phase: inception
status: complete
created: '2026-09-20T12:45:00Z'
updated: '2026-09-20T12:45:00Z'
---

# Unit Brief: Gap-Fill Service

## Purpose

Extend the existing lesson-service backend with a fifth exercise type, `gap_fill`, reusing the `ExerciseType` dispatch pattern exactly. Content model, migration, response mapping and seed content. **No grading logic** — per ADR-5 all grading is client-side; see `../002-gap-fill-ui/unit-brief.md`.

## Scope

### In Scope
- `ExerciseType.GAP_FILL = "gap_fill"` in `backend/app/domain/lesson/value_objects.py`
- `GapFillContent` value object, added to the `ExerciseContent` union
- Migration widening `ck_exercises_type` from 4 to 5 values via `op.batch_alter_table`, plus the matching literal in `ExerciseModel.__table_args__`
- JSON reconstruction (`lesson_repositories.py`), response schema (`lesson_schemas.py`), mapping (`exercise_mapping.py`)
- Seed content in all four courses, with an authored blank position per language and `vocab_item_id` set
- `database-schema.md` updated (declared source of truth for columns/constraints)

### Out of Scope
- Any new `AnswerKey` — this type reuses `ChoiceAnswerKey`. Needing a new one is a scope change to raise at a checkpoint (see `requirements.md`'s constraints)
- Client rendering **and grading** (both owned by `002-gap-fill-ui`)
- Any change to Beans/XP/streak/SRS award logic
- Any change to the other four exercise types
- Multi-gap sentences, and typing into the gap

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Gap-Fill Content Model and Seed Content | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `GapFillContent` | Renderable content for a `gap_fill` exercise | the learning-language sentence with one word removed, a from-language gloss, and `choices` (reusing the existing `Choice` value object) |
| `ChoiceAnswerKey` | **Existing**, reused unchanged | `correct_choice_id` |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| ServeExerciseContent | Return a `gap_fill` exercise's sentence, gloss and choices (existing endpoint, extended) | lesson_id | `GapFillContent` + `ChoiceAnswerKey`, flattened into one response per `lesson_schemas.py`'s existing pattern |

### Known Decision Point
How the gap is represented — a sentinel inside the existing non-null `exercises.prompt` column, versus structured before/after segments inside `content`. Deliberately unresolved at Inception; decide at the bolt's plan stage against real code. Both satisfy FR-1; they differ in rendering safety and in how much the client has to parse.

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
| 001-serve-gap-fill-exercise-content | Serve gap-fill exercise content (incl. seed data) | Must | Generated |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| None | Extends existing `001-lesson-service` code in place |

### Depended By
| Unit | Reason |
|------|--------|
| `002-gap-fill-ui` | Needs the real serialized contract to render and grade against |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| None | — | — |

---

## Technical Context

### Suggested Technology
Python/FastAPI, extending the same files bolts 004/005/011 established: `value_objects.py`, `lesson_models.py`, `lesson_repositories.py`, `lesson_schemas.py`, `exercise_mapping.py`, and the seed modules. The migration follows `c726efa81972` exactly (batch mode for SQLite, plain `ALTER` on PostgreSQL), including a verified downgrade/upgrade round-trip.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| Existing lesson-content endpoints | API | REST over HTTPS (no new endpoint) |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| `gap_fill` exercise content | PostgreSQL, existing `exercises` table, JSON `content` column (ADR-3) | ≥1 per course across 4 courses | Same as existing curriculum content |

---

## Constraints

- Must not change the response shape, grading behaviour or schema of the other four exercise types.
- Blank position is **authored per language, not computed** — token counts differ between languages for the same sentence (verified: `Daabboo nan barbaada` is 3 tokens, `ዳቦ እፈልጋለሁ` is 2).
- Distractors are drawn from the same lesson's vocabulary so wrong answers are plausible.
- Seeding must go through the existing idempotent loop and must stay re-runnable.
- Seeding into existing lessons bumps `updated_at` → `content_version` → invalidates downloaded offline packs. Expected, not a bug.
- New instruction wording is agent-authored in en/am/om and inherits `010-multi-language-courses`' NFR-3 native-speaker review blocker.

---

## Success Criteria

### Functional
- [ ] A `gap_fill` exercise is served through the existing lesson-content endpoint with no per-type special-casing beyond content shape
- [ ] Served content plus `correct_choice_id` is sufficient for the client to grade locally
- [ ] `gap_fill` exercises exist in all four seeded courses, with `vocab_item_id` set

### Non-Functional
- [ ] No regression to existing exercise types (full backend suite green)
- [ ] Migration round-trips (upgrade → downgrade → upgrade) on SQLite

### Quality
- [ ] Unit test coverage for the new content model and its JSON mapping
- [ ] All acceptance criteria met

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 030-gap-fill-service | simple-construction-bolt | 001 | Content model, migration, mapping and seed content — no grading logic |

---

## Notes

Small and self-contained, with one genuine unknown (the gap representation) and one repeat risk: bolt 011 assumed no migration was needed and was wrong. This brief states up front that a migration **is** required, so that assumption cannot be made twice.
