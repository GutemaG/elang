---
unit: 001-spell-tiles-service
intent: 016-spell-from-tiles-exercise-type
phase: inception
status: complete
created: '2026-09-20T18:10:00Z'
updated: '2026-09-20T18:10:00Z'
---

# Unit Brief: Spell-Tiles Service

## Purpose

Serve `spell_tiles` exercises from the existing lesson-content endpoint, and seed them into all four courses, without adding an answer-key shape or a response envelope.

## Scope

### In Scope
- `ExerciseType.SPELL_TILES` and `SpellTilesContent` in `value_objects.py`
- The `ck_exercises_type` widening — in **both** the model's `__table_args__` and a new Alembic revision
- Reconstruction in `lesson_repositories.py`, response schema in `lesson_schemas.py`, mapping in `exercise_mapping.py`
- Seed content in `seed_lesson_content.py` and `seed_course_content.py`, appended after the gap-fill
- A new instruction string per from-language in `_TEXT`
- Updating `database-schema.md`

### Out of Scope
- Any change to the `AnswerKey` union
- Any grading logic (ADR-5: grading is client-side)
- Client rendering (owned by `002-spell-tiles-ui`)
- `seed_category_content.py`'s sixteen further en→am lessons — same follow-up `015` left open

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Spell-Tiles Content Model and Seed Content | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `SpellTilesContent` | Renderable content for a `spell_tiles` exercise | `tiles: tuple[Choice, ...]` — shuffled character tiles including distractors, each with a stable id |
| `SequenceAnswerKey` | **Existing**, reused unchanged | `correct_sequence: tuple[str, ...]` — tile ids in spelling order |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| Reconstruct content | Map the stored JSON blob to `SpellTilesContent` | type + JSON | domain VO |
| Map to response | Emit the `spell_tiles` response variant | domain exercise | response model |
| Seed | Build tiles from a lesson word plus two distractor characters | word, lesson words, order | exercise dict |

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
| 001-serve-spell-tiles-exercise-content | Serve a spell-tiles exercise | Must | Complete (bolt 032) |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| None | Extends existing lesson-service code in place |

### Depended By
| Unit | Reason |
|------|--------|
| `002-spell-tiles-ui` | Needs the real serialized contract |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| None | — | — |

---

## Technical Context

### Suggested Technology

Python/FastAPI/SQLAlchemy/Alembic, extending the files bolts 011 and 030 established.

One thing is already right and must not be "fixed":
- `test_exercise_type_dispatch.py` is parametrized over `ExerciseType`, so adding `SPELL_TILES` makes it fail immediately. That is the alarm working as designed; satisfy it, do not weaken it.

~~`_answer_key_from_json` already reconstructs a `SequenceAnswerKey` from `correct_sequence`, so it needs **no edit** — the same free win `gap_fill` got from `ChoiceAnswerKey`.~~ — **wrong, corrected during Construction (bolt 032)**. Its first branch named `SENTENCE_CONSTRUCTION` only, and everything else fell through to `ChoiceAnswerKey`. This type had to be named explicitly or it would have died on a missing `correct_choice_id`. The general lesson: a fall-through that happens to fit one new type is not evidence it fits the next.

One thing is a trap: the seed's `_choices` helper and the `id_by_token = {tile["text"]: tile["id"]}` idiom both key by tile **text**. For sentences that is fine. For spelling it silently drops repeated characters. A separate helper is needed, as `030` needed `_gap_choices` for the same class of reason.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| Existing lesson-content endpoint | API | REST over HTTPS |
| PostgreSQL / SQLite (tests) | DB | SQLAlchemy |

---

## Constraints

- Reuse `SequenceAnswerKey`. A new answer-key shape is a checkpoint-level scope change.
- `content` must not reveal its own answer: tiles are shuffled and `correct_sequence` is a permutation of a subset of them, exactly as `sentence_construction` does.
- Duplicate character text within one exercise is normal and must survive storage, reconstruction and serialization.
- Seeding is idempotent and appends — no existing `order_index` moves.
- A migration **is** required, and a green test suite does not prove it: the test DB uses `Base.metadata.create_all` and never runs migrations. Verify the revision by hand, up and down.

---

## Success Criteria

### Functional
- [ ] A lesson containing a `spell_tiles` exercise serves through the existing endpoint with no new envelope
- [ ] All four courses contain at least one `spell_tiles` exercise after seeding
- [ ] Re-seeding changes nothing

### Non-Functional
- [ ] No regression to the five existing exercise types
- [ ] Full backend suite green, ruff and mypy no worse than before

### Quality
- [ ] `test_exercise_type_dispatch.py` extended, not weakened
- [ ] A test asserts a seeded word with repeated characters keeps all its tiles
- [ ] A test asserts `spell_tiles` sets no `vocab_item_id`
- [ ] The migration verified by hand, up and down, on a scratch SQLite database

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 032-spell-tiles-service | simple-construction-bolt | 001 | Domain model, migration, mapping and seed |

---

## Notes

This is the cheapest backend half an exercise type has had: no new answer key, no new authored content, and an existing dispatch test that will point at every seam that still needs filling. The only real thinking is the tile-identity discipline — and that is a discipline, not a design problem.
