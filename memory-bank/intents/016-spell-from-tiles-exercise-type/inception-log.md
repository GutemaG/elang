---
intent: 016-spell-from-tiles-exercise-type
created: '2026-09-20T17:30:00Z'
completed: '2026-09-20T18:25:00Z'
status: complete
---

# Inception Log: spell-from-tiles-exercise-type

## Overview

**Intent**: Add the `spell_tiles` exercise type — spell a word by tapping
character tiles in order — to the lesson engine, backend and client.
**Type**: brown-field (extends `002-core-lesson-loop`'s exercise-type dispatch,
following `004-match-pairs-exercise-type` and `015-gap-fill-exercise-type`)
**Created**: 2026-09-20

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units.md, units/{unit-name}/unit-brief.md |
| Stories | ✅ | units/{unit-name}/stories/*.md |
| Bolt Plan | ✅ | memory-bank/bolts/032-spell-tiles-service/bolt.md, memory-bank/bolts/033-spell-tiles-ui/bolt.md |

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
| 001-spell-tiles-service | 1 | 1 (032-spell-tiles-service) | Must |
| 002-spell-tiles-ui | 2 | 1 (033-spell-tiles-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-20 | `spell_tiles` is the next type on the complexity ladder, ahead of the audio and typing types | It is the only remaining candidate with no external blocker. Every seeded `audio_url` is still `PLACEHOLDER_AUDIO_URL` (a piano recording), so all audio-dependent types are blocked on recordings rather than engineering; the typing types are blocked on the unresolved Fidel keyboard question, explicitly fenced out of `015` | Yes |
| 2026-09-20 | One exercise type per intent, continuing `004` and `015` | Keeps bolts small and the story/bolt mapping one-to-one | Yes |
| 2026-09-20 | A **new sibling widget** for id-keyed tiles; `WordBankBuilder` and `sentence_construction` are not touched | Generalising the existing widget to ids would edit a shipped, tested type and its parse path for the benefit of a type that does not exist yet. Some duplicated chrome is cheaper than that regression risk (Checkpoint 1, Q1) | Yes |
| 2026-09-20 | The prompt is the **from-language word**; the learner spells the learning-language word from recall | Copying a visible model is tracing, not recall. It also matches how `sentence_construction` prompts | Yes |
| 2026-09-20 | **Two distractor tiles** beyond the word's own characters, drawn from the same lesson's other words | Without them the exercise is an anagram, solvable by elimination without knowing the word. Same-lesson sourcing keeps them plausible, mirroring `015`'s distractor rule | Yes |
| 2026-09-20 | One per lesson, **appended after the gap-fill** | No existing `order_index` moves and no tested content is displaced — exactly the approach `015` took | Yes |
| 2026-09-20 | **One tile per Fidel character** for v1; consonant+vowel decomposition is a possible later type | Per-character is a clean grapheme split and needs no new content. Decomposition is a syllabary picker — a different interaction, not a variant of this one | Yes |
| 2026-09-20 | Accept the wide Latin case: design the layout for **up to 12 tiles** rather than restricting which words are seeded | Restricting by length would silently skip lessons and make coverage uneven across courses. The layout has to hold 11 tiles for `Hanqaaquu` regardless | Yes |
| 2026-09-20 | `spell_tiles` sets **no** `vocab_item_id`, stated at Inception rather than discovered in Construction | `015` wrote the opposite into FR-1 and had to retract it mid-bolt once an existing test showed a vocab item maps to exactly one exercise. The finding is carried forward here instead of re-learned | Yes |

## Pre-Inception Findings

Recorded before Checkpoint 1 because they were found by reading the code, and
because one of them changes the cost estimate this intent was opened on.

| Finding | Evidence | Consequence |
|---------|----------|-------------|
| `SequenceAnswerKey` fits spelling unchanged — a tuple of tile ids in order | `backend/app/domain/lesson/value_objects.py:268` | Second consecutive type adding **no** `AnswerKey` union member |
| Content needs no new authored material | `_WORDS` at `seed_course_content.py:37` is 16 words × en/am/om, already seeded | Unlike `015`, which needed a hand-authored `blank` index per language |
| **`WordBankBuilder` cannot be reused as-is: it is keyed by tile *text*, not tile *id*** | `word_bank_builder.dart` uses `built.contains(token)` and `onToggle(token)`; `http_lesson_api.dart:281` flattens ids to text at parse time; the seed's `id_by_token = {tile["text"]: tile["id"]}` (`seed_course_content.py:275`) silently collapses duplicates | Words repeat letters where sentences do not repeat words. `Galatoomi` has two `a` and two `o`; `Hanqaaquu` has three `a`. The existing widget would dim both twins and remove the wrong one. **This needs an id-keyed builder** — see Checkpoint 1 |
| Latin and Fidel produce very different tile counts for the same word | `Hanqaaquu` is 9 Latin letters; `እንቁላል` is 5 Fidel characters | A layout that works for Amharic may overflow for Afaan Oromo |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-09-20 | Grading for this type compares the **spelled text**, not the id sequence (bolt `032`'s plan decision D3) | Not anticipated at Inception, and a correctness bug if missed. A word with a repeated character has interchangeable tiles for it, so several id sequences spell the same word — a learner who taps the *other* `a` in `Maaloo` builds a correct spelling that an id-list comparison marks wrong | No backend change: `correct_sequence` still carries ids. It changes what `correct_sequence` **means** for this type, recorded in `SequenceAnswerKey`'s docstring, `SpellTilesExerciseResponse`'s docstring, `database-schema.md` and `032`'s plan. **Owed to bolt `033` as an acceptance criterion** — not yet in story `001` of unit `002`, by the user's choice at `032`'s Stage 1 checkpoint |
| 2026-09-20 | `_answer_key_from_json` needed an edit after all; the unit brief and story said it would not | Its first branch named `SENTENCE_CONSTRUCTION` alone and everything else fell through to `ChoiceAnswerKey`. A `spell_tiles` row would have died on a missing `correct_choice_id`. Caught because the plan said "confirm, do not assume", which it said because bolt 030 left a warning in that exact spot | One extra line; both stale claims struck through in place. General lesson recorded: a fall-through that happens to fit one new type is not evidence it fits the next |
| 2026-09-20 | `to_exercise_response` gained a terminal `raise` it never had | Bolt 030 made `match_pairs` explicit but left `gap_fill` as the unguarded final branch, so the trap had moved rather than closed — a `spell_tiles` exercise would have failed on an `isinstance` assertion naming `GapFillContent` | Every type now explicit; matches `_content_from_json`. Retires a latent defect rather than adding scope |

## Risks Carried Into Construction

| Risk | Where recorded | Mitigation |
|------|----------------|------------|
| Text-keyed tiles written by reflex, by copying the nearest neighbour | `033`'s Notes, story `001`'s Technical Notes, the unit brief's Notes | Every tile path in the codebase currently keys by text. Named explicitly, including the specific line not to copy (`http_lesson_api.dart`'s `sentence_construction` branch) |
| A test that passes against a text-keyed implementation | `033`'s Notes, both UI stories' AC | Spelling `ቡና` proves nothing. The repeated-character test is load-bearing and is an acceptance criterion in three places |
| Reusing the seed's `_choices` / `id_by_token` helpers, collapsing duplicate characters | `032`'s Notes, story `001`'s Technical Notes | Stated as a prohibition with the reason, mirroring how `030` needed `_gap_choices` |
| Assuming no migration is needed — bolt `011` made this exact mistake | `032`'s Notes, story `001`'s Technical Notes | Stated as a required deliverable including the duplicate CHECK literal, with hand verification because the suite uses `create_all` |
| `lesson_pack_store.dart` fails silently — the only seam the sealed class does not guard | `033`'s Notes, story `002`'s AC | Round-trip test with a repeating word, plus a falsification step, both acceptance criteria |
| Eleven tiles overflowing on device — three attempts were needed on the `011` banner | `033`'s Notes, story `001`'s AC | Prefer layouts that cannot overflow; verify in Fidel and Latin at more than one text scale, then on device |
| Someone later "tidying up" by merging the new widget into `WordBankBuilder` | `units.md`, "Note on Not Sharing the Word Bank" | The rejection and its reason are recorded where a future reader will find them |
| Agent-authored Amharic/Afaan Oromo content | requirements.md NFR section | Inherits `010`'s NFR-3 native-speaker review blocker; this intent adds one instruction string per from-language |

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete — approved at Checkpoint 3, 2026-09-20

## Next Steps

1. Begin Construction with unit `001-spell-tiles-service`
2. Execute: `/specsmd-construction-agent --unit="001-spell-tiles-service" --bolt-id="032-spell-tiles-service"`

## Dependencies

Depends on `002-core-lesson-loop` (exercise-type dispatch),
`003-offline-caching-and-sync` (the pack path) and `010-multi-language-courses`
(seeds across four courses). Shares the `SequenceAnswerKey` and word-bank
lineage with `002`'s `sentence_construction`. Nothing depends on this intent.
