---
id: 001-spell-tiles-exercise-screen
unit: 002-spell-tiles-ui
intent: 016-spell-from-tiles-exercise-type
status: complete
priority: must
created: '2026-09-20T18:10:00Z'
assigned_bolt: 033-spell-tiles-ui
implemented: true
---

# Story: 001-spell-tiles-exercise-screen

## User Story

**As a** Buna learner
**I want** to spell a word by tapping its characters in order
**So that** I learn what the word is actually made of, rather than only recognising its shape

## Acceptance Criteria

- [x] **Given** a `spell_tiles` exercise, **When** it renders, **Then** the from-language word shows as the prompt, with an empty spelling tray and the shuffled character tiles beneath it
- [x] **Given** the exercise, **When** the learner taps a tile, **Then** its character is appended to the tray and that tile dims
- [x] **Given** a word with two identical characters, **When** the learner taps one of them, **Then** **only that tile** dims and the other stays tappable
- [x] **Given** a partly built spelling containing two identical characters, **When** the learner removes one, **Then** the tile that was tapped for it becomes available again — not its twin
- [x] **Given** an empty tray, **When** the learner looks at Check, **Then** it is disabled; it enables as soon as one tile is placed
- [x] **Given** a built spelling, **When** the learner taps Check, **Then** the exercise is graded locally against `correct_sequence` with no network call, and `LessonController`'s existing grade/advance/Beans/XP flow runs unchanged (graded by the spelled text, not the id list, per bolt 032's decision D3: twin tiles are interchangeable)
- [x] **Given** a graded exercise, **When** the result shows, **Then** correct and incorrect states reuse the existing tile colour language rather than new states
- [x] **Given** an eleven-tile Afaan Oromo word and a Fidel word, **When** each renders at a large text scale, **Then** neither overflows
- [x] **Given** this story is complete, **When** `git diff` is inspected, **Then** `word_bank_builder.dart`, `SentenceConstructionExercise` and the `sentence_construction` parse path are unchanged

## Technical Notes

- Add `SpellTilesExercise` to the sealed `Exercise` in `lib/shared/models/exercise.dart` and an arm to `isAnswerCorrect` — `answer is List<String> && listEquals(answer, e.correctTileIds)`, mirroring `SentenceConstructionExercise`'s arm but over ids.
- The exercise must carry tiles as `(id, text)` pairs. `MatchPairsTile` already has that shape and that rationale; decide at the Plan stage whether to reuse it or add a sibling, and record why.
- Parse in `http_lesson_api.dart`'s `_toExercise`. **Do not copy the `sentence_construction` branch** — it builds a `textById` map and throws the ids away. That is the specific line this story exists to not repeat.
- Add to `fake_lesson_api.dart`, using a word with repeated characters so every test that runs against the fake exercises the real risk.
- New arms in `lesson_screen.dart`'s body switch and its `canSubmit` switch. `canSubmit` is `hasAnswer` for the index-based types; for this one it is a non-empty list, like `sentence_construction`'s.
- `LessonController.toggleWordBankToken` may already work unchanged when given ids, since it is a generic toggle over a `List<String>` and ids are unique. Verify against the real code; if it does work, the controller stays unopened, which is the same outcome `031` reached and is worth stating explicitly in the walkthrough. If its name no longer tells the truth, say so rather than quietly widening it.
- `word_bank_builder.dart` is the layout reference — tray above, bank below, dim-on-use. Read it, then write a new widget; do not extend it.
- On text metrics: prefer a layout that cannot overflow to one that computes what it needs. See the `011-dashboard-ui-polish` banner follow-ups.

## Dependencies

### Requires
- `001-spell-tiles-service`'s `001-serve-spell-tiles-exercise-content`

### Enables
- `002-offline-spell-tiles-verification`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Eleven tiles at 2.0x text scale on a narrow screen | Wraps to more rows; nothing overflows and the tray stays visible |
| The learner places every tile including distractors | Allowed; Check grades it wrong. No client-side "you used too many" hint |
| The learner taps a tile already in the tray | It is dimmed and not tappable, so nothing happens — the same rule `WordBankBuilder` uses |
| The learner removes the only placed tile | Check disables again |
| Two tiles with identical text in the tray, learner taps the first | That one is removed; the second stays. This is the whole point — cover it with a test |
| A Fidel character that renders wider than a Latin letter | The tile sizes to its content; tiles are not forced to a uniform width that clips one script |

## Out of Scope

- Typing the spelling
- Decomposing a Fidel character into consonant and vowel
- Any change to `LessonController`'s grading flow
- Any change to `sentence_construction`
