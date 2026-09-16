---
stage: plan
bolt: 012-match-pairs-ui
created: '2026-09-17T06:25:00Z'
---

## Implementation Plan: Match-Pairs UI

### Objective

Deliver the client side of the `match_pairs` exercise type: a tap-based matching screen wired into the existing `LessonController`/exercise-engine flow exactly like the other 3 exercise types, plus verification that it works fully offline through the existing download/pack-storage/sync path with zero required changes there.

### Deliverables

- `MatchPairsExercise`/`MatchPairsTile` added to the sealed `Exercise` model (`lib/shared/models/exercise.dart`)
- `isAnswerCorrect` extended with a `MatchPairsExercise` case
- `HttpLessonApi._toExercise` extended with a `match_pairs` JSON-parsing branch
- `LessonPackStore._exerciseToJson`/`_exerciseFromJson` extended (Dart's exhaustive-switch checking on the sealed class will force this — a compile error otherwise)
- `LessonController` extended with the minimal new state/method needed to build up a tap-to-link answer (see Technical Approach) — no change to `check()`/`continueToNext()`/`_finishLesson()` themselves
- New `MatchPairsBuilder` widget (mirrors `WordBankBuilder`'s structure: two `Wrap` columns instead of one tray+bank) + wiring into `LessonScreen`'s exercise-type `switch`
- `FakeLessonApi` gets one `match_pairs` demo exercise added to an existing lesson, for local-dev/demo parity with the other 3 types (nice-to-have, not a story requirement)

### Dependencies

- `011-match-pairs-service` (complete) — real response shape: `{id, order_index, type: "match_pairs", prompt, left_tiles: [{id,text}], right_tiles: [{id,text}], correct_pairs: [[left_id,right_id]]}`
- No new package dependencies

### Technical Approach

**Read the actual codebase before planning this** (allowed at this stage, unlike the DDD bolt type's Stage 1/2) — this surfaced one important correction to the UX described at Inception time, flagged below.

**Data model** — `MatchPairsExercise` follows the existing sealed-class pattern:
- `prompt: String`
- `leftTiles: List<MatchPairsTile>`, `rightTiles: List<MatchPairsTile>` (new small `MatchPairsTile{id, text}` class — separate ids are required here, unlike `MultipleChoiceExercise.options` which is a plain `List<String>`, because after two independently-shuffled columns, position alone can no longer identify a tile)
- `correctPairs: Map<String, String>` (`leftId -> rightId`)

**Grading model — corrected from Inception's plan.** The intent's stories described *live, per-pair* feedback (tap a pair, see an immediate lock/flash before continuing). Reading `LessonController`/`ChoiceTile`/`WordBankBuilder` shows every existing exercise type actually uses one atomic model instead: build up a tentative answer via taps (no grading yet), an explicit "Check" button becomes enabled once the answer is "complete enough," tapping it grades the *whole* exercise at once via `isAnswerCorrect`, and a single `TileFeedback` (correct/incorrect) applies uniformly afterward — there is no live per-token feedback anywhere in this codebase today, not even for `sentence_construction`'s word-bank builder.

Reusing that exact model for `match_pairs` (tap-to-link tentative pairs, "Check" once every left tile has a linked right tile, atomic all-or-nothing grade) is far more consistent with the rest of the app and meaningfully less work than inventing a new interaction paradigm. **Flagging this for explicit approval** rather than silently deviating from the Inception-time story text — see Checkpoint Decision below.

**Controller changes**: `_selectedAnswer` (already an untyped `Object?`) will hold a `Map<String, String>` for this exercise type once complete, exactly parallel to `List<String>` for sentence-construction. One new transient concept is needed that the other types don't have: which left tile (if any) is currently "armed" awaiting its right-side tap. This is UI selection state, not part of the graded answer — it will live on the controller (small private field + getter), not duplicated into a stateful widget, keeping `MatchPairsBuilder` a `StatelessWidget` like `WordBankBuilder`.

**Offline verification (story 002)**: `LessonPackDownloader._downloadAudioAndRewrite` only special-cases `is ListeningExercise`; everything else (including the new `MatchPairsExercise`) already passes through unchanged — no code change expected there. `LessonPackStore`'s JSON round-trip DOES need an explicit new case (the switch is exhaustive over the sealed class, so the compiler enforces this isn't skipped). This story's job is to prove the full path (download → offline take → sync) end-to-end with a real test, not just assume it from the downloader's design.

### Acceptance Criteria

- [ ] A user can complete a `match_pairs` exercise via tap-only interaction: tap a left tile to arm it, tap a right tile to link it, tap an armed/linked left tile again to unlink; "Check" enables once every left tile is linked
- [ ] Checking grades the whole exercise atomically (correct only if the submitted map exactly equals `correctPairs`), using the same `TileFeedback`/Continue flow as the other 3 types
- [ ] `LessonController`'s existing grade/advance/Beans-XP/offline-completion-queueing flow runs completely unchanged for this exercise type
- [ ] A downloaded pack containing a `match_pairs` exercise plays fully offline with zero network calls (verified by a real test, not assumed)
- [ ] `flutter analyze` clean, full existing Flutter test suite still passes
