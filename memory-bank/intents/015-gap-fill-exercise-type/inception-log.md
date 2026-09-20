---
intent: 015-gap-fill-exercise-type
created: '2026-09-20T12:30:00Z'
completed: '2026-09-20T12:45:00Z'
status: complete
---

# Inception Log: gap-fill-exercise-type

## Overview

**Intent**: Add the `gap_fill` exercise type — a sentence with one word removed, filled by tapping a word — to the lesson engine, backend and client.
**Type**: brown-field (extends `002-core-lesson-loop`'s exercise-type dispatch)
**Created**: 2026-09-20

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units.md, units/{unit-name}/unit-brief.md |
| Stories | ✅ | units/{unit-name}/stories/*.md |
| Bolt Plan | ✅ | memory-bank/bolts/030-gap-fill-service/bolt.md, memory-bank/bolts/031-gap-fill-ui/bolt.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 3 |
| Non-Functional Requirements | 0 new (inherits `010`'s NFR-3 content-review blocker) |
| Units | 2 |
| Stories | 3 |
| Bolts Planned | 2 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-gap-fill-service | 1 | 1 (030-gap-fill-service) | Must |
| 002-gap-fill-ui | 2 | 1 (031-gap-fill-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-20 | Build exercise types in a complexity ladder, `gap_fill` first | Of the candidate types, it alone needs no audio, no keyboard, no external service and no new answer-key shape, and its content derives from sentences already seeded. Everything above it on the ladder is gated on people or money rather than engineering | Yes |
| 2026-09-20 | One exercise type per intent, following `004-match-pairs-exercise-type` | Keeps bolts small and the story/bolt mapping one-to-one; the next type (spell-from-tiles) becomes its own intent rather than widening this one | Yes |
| 2026-09-20 | Reuse `ChoiceAnswerKey`; adding an `AnswerKey` union member is a scope change requiring a checkpoint | The cheapness of this type is a stated goal, not an accident. Making it a constraint means a drift toward a new answer key has to surface rather than be absorbed | Yes |
| 2026-09-20 | Grading is client-side, stated in the requirements rather than discovered later | ADR-5 already settles this. `004` wrote a backend grading story and retired it mid-Construction; writing it correctly up front costs nothing | Yes |
| 2026-09-20 | Blank position authored per language, never computed | Token counts differ across languages for the same sentence — verified against the seed: "I want bread" is 3 tokens in Afaan Oromo, 2 in Amharic. A computed index would blank the wrong word in one language | Yes |
| 2026-09-20 | `gap_fill` sets `vocab_item_id` and so feeds SRS/Practice | It tests one specific word; excluding it would weaken Practice for no reason. The column already exists and is nullable (bolt 019) | Yes |
| 2026-09-20 | One gap-fill per lesson that has a seeded sentence, added to the sequence rather than replacing an exercise | Introduces the type everywhere without shortening existing lessons or displacing tested content | Yes |
| 2026-09-20 | Gap representation (prompt sentinel vs structured segments) left open for the bolt's Plan stage | Exactly the class of detail `004` got wrong on paper and corrected against real code. Deciding it at Inception would be guessing | Yes |
| 2026-09-20 | Two units, backend then client, mirroring `002`/`003`/`004` | Consistency with the established decomposition; the UI needs the real serialized contract before it can render or grade against it | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-09-20 | FR-1's `vocab_item_id` acceptance criterion retracted: gap-fill is **not** vocab-linked | Discovered at bolt `030`'s Implement stage, by an existing test rather than by reading: `list_exercises_by_vocab_item_ids` keeps the first row per `vocab_item_id`, so a vocab item maps to exactly one exercise. Sharing one adds no SRS coverage and makes which exercise Practice serves depend on a UUID comparison | No story or bolt change; the criterion is inverted and asserted by a test. Widening SRS coverage properly needs vocab items for the untracked words — separate scope |
| 2026-09-20 | `seed_category_content.py`'s sixteen further English-to-Amharic lessons got no gap-fill | The acceptance criterion is at least one per course, met by the four hand-written ones. Sixteen more means sixteen authored Amharic blank positions — content work, not mechanism | Follow-up; additive, no model change |
| 2026-09-20 | Bolt `031` lifted `lesson_pack_store.dart`'s four JSON mapping functions to the top level | An acceptance criterion required proving the pack round trip, but the mapping was private to a sqflite-backed store `flutter test` cannot open — so it had never been tested, for **any** exercise type | Visibility change only, no behaviour change; retires a long-standing blind spot |

## Risks Carried Into Construction

| Risk | Where recorded | Mitigation |
|------|----------------|------------|
| Assuming no migration is needed — bolt 011 made this exact mistake | `030-gap-fill-service`'s Notes, the story's Technical Notes | Stated as a required deliverable, including the duplicate `CHECK` literal in `ExerciseModel.__table_args__` |
| Merging `content` and `answer_key` into one self-revealing blob — also bolt 011's first design | `030`'s Notes | Stated as a constraint |
| `lesson_pack_store.dart` fails silently — the only seam the sealed class does not guard | `031`'s Notes, story `002`'s AC | Round-trip test is an acceptance criterion, not a nicety |
| Predicted text heights overflowing on device — three attempts were needed on the `011` banner | `031`'s Notes, story `001`'s AC | Prefer layouts that cannot overflow; verify in Fidel and Latin at more than one text scale |
| Agent-authored Amharic/Afaan Oromo content | requirements.md NFR section | Inherits `010`'s NFR-3 native-speaker review blocker; this intent adds one instruction string per from-language |

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [ ] Human review complete — awaiting Checkpoint 3

## Next Steps

1. Approve at Checkpoint 3
2. Begin Construction with unit `001-gap-fill-service`
3. Execute: `/specsmd-construction-agent --unit="001-gap-fill-service" --bolt-id="030-gap-fill-service"`

## Dependencies

Depends on `002-core-lesson-loop` (extends its exercise-type dispatch), `003-offline-caching-and-sync` (must stay compatible with the pack path), `008-srs-and-practice` (sets `vocab_item_id`) and `010-multi-language-courses` (seeds across four courses). Nothing depends on this intent. It is unrelated to the open requirements-only intents `012`, `013` and `014`.
