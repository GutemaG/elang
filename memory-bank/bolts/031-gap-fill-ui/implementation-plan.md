---
stage: plan
bolt: 031-gap-fill-ui
created: '2026-09-20T15:45:00Z'
---

## Implementation Plan: 002-gap-fill-ui

### Objective

A learner can complete a gap-fill exercise: read a sentence with a visible gap, tap a word to drop it into the gap, and check it. Graded locally, works offline from a downloaded pack, and the four existing exercise types behave exactly as before.

### Deliverables

1 - `GapFillExercise` as a new arm of the sealed `Exercise`, plus its `isAnswerCorrect` case
2 - Parsing in `http_lesson_api.dart` and a fixture in `fake_lesson_api.dart`
3 - **Both halves** of `lesson_pack_store.dart` — the serialize map and the deserialize case
4 - A new widget rendering the sentence with a gap the chosen word fills in place
5 - New arms in `lesson_screen.dart`'s body switch and `_ActionBar`'s readiness switch
6 - Widget tests, a pack round-trip test, and offline verification

### Dependencies

- `030-gap-fill-service`, complete and committed (`7bc5321`). The contract is `sentence_before`, `sentence_after`, `choices`, `correct_choice_id`.

---

### Technical Approach

#### The client model is index-based, unlike the API

`_toExercise` already translates the API's id-based answers into index-based ones — `MultipleChoiceExercise` stores `correctOptionIndex: choices.indexWhere(...)`, not a choice id. `GapFillExercise` follows that, carrying `prompt`, `sentenceBefore`, `sentenceAfter`, `options` and `correctOptionIndex`. Introducing an id-based model here would make gap-fill the odd one out on the client for no benefit.

#### Selection reuses the existing controller path, unchanged

`LessonController.selectOption(int)` already sets `_selectedAnswer` to an index, and `_ActionBar`'s readiness switch already has an arm for "any answer will do": `MultipleChoiceExercise _ || ListeningExercise _ => hasAnswer`. Gap-fill joins that arm and needs **no new controller method and no new state** — the client mirror of the backend's `ChoiceAnswerKey` reuse. `isAnswerCorrect` gains one line comparing the index.

This is worth stating as a constraint rather than an observation: if the implementation finds itself adding controller state for gap-fill, something has gone wrong.

#### Rendering the gap

`Text.rich`, with a `TextSpan` for the text before, a `WidgetSpan` for the gap, and a `TextSpan` for the text after. A `Wrap` of per-word chips was considered and rejected: it would re-implement line breaking badly, and the sentence must wrap like prose in both Fidel and Latin.

The gap itself is a fixed-height underlined box that shows the chosen word once one is picked, sized to the widest option so the sentence does not reflow when a word is dropped in — reflowing text on every tap is visually noisy and makes the sentence hard to re-read.

**Known risk**: `WidgetSpan` baseline alignment. `PlaceholderAlignment.baseline` needs an explicit `TextBaseline`, and a misaligned or over-tall placeholder is the most likely way this widget looks wrong on device. Per bolt 029's lesson, prefer a structure that cannot overflow over one that predicts its own height, and verify at more than one text scale in both scripts rather than trusting the test font.

#### The tile row

`ChoiceTile` unchanged, one per option, in the same column layout `_MultipleChoiceBody` uses. A chosen tile is `selected`; after Check the existing `feedback` drives correct/incorrect. No new tile states.

#### Re-selection

Tapping a different tile moves the selection. Tapping the already-selected tile **keeps** it selected rather than clearing — `selectOption` is idempotent, so this is the default behaviour, and clearing would mean a learner can tap a word twice and end up unable to press Check without understanding why. The story leaves this open; this is the choice, and a test will pin it.

#### The offline seam

`lesson_pack_store.dart` maps JSON by hand in both directions. The sealed class turns every other omission into a compile error; this one fails at runtime. Both halves get written together and a round-trip test is written before the offline verification, not after.

---

### Acceptance Criteria

- [ ] `GapFillExercise` is an arm of the sealed `Exercise`, with an `isAnswerCorrect` case
- [ ] `http_lesson_api.dart` parses the type, converting `correct_choice_id` to an index
- [ ] `fake_lesson_api.dart` serves one, so the fake stays a faithful stand-in
- [ ] Both halves of `lesson_pack_store.dart` handle it, proven by a round-trip test
- [ ] The sentence renders with a visibly distinct gap, gloss above, in Fidel and Latin
- [ ] Tapping a word puts it **in the gap**; the sentence does not reflow
- [ ] Check is disabled until a word is chosen; tapping another word moves the selection
- [ ] Grading is local, no network call on Check
- [ ] `LessonController` gains **no new state or methods**
- [ ] A pack containing a gap-fill downloads, plays offline with zero network calls, and syncs
- [ ] No overflow at more than one text scale, in both scripts
- [ ] Full Flutter suite green, `flutter analyze` clean, no backend file touched

---

### Risks

1 - **`lesson_pack_store.dart` fails silently.** The only seam the compiler does not guard. Mitigated by writing the round-trip test as part of the same change.
2 - **`WidgetSpan` alignment and text metrics.** The `011` banner needed three attempts because a predicted height was a pixel short on device while every test passed — the test font's metrics are not a phone's. Prefer structures that cannot overflow; treat green tests as necessary, not sufficient.
3 - **Existing lesson tests assert exercise counts.** The backend seed now returns five exercises per lesson, so Flutter tests or fakes that assume four may need updating — the same arithmetic that moved eleven backend assertions. Expect it rather than be surprised.
4 - **Already-downloaded packs are invalidated** by the seed's `content_version` bump. Correct behaviour, and it will show up during offline verification.

### Out of Scope

- Typing into the gap; more than one gap per sentence
- Any change to `LessonController`, `SyncEngine`, `PendingSyncQueueStore` or `LessonPackDownloader`
- Gap-fill content for the sixteen `seed_category_content.py` lessons (backend follow-up)
