---
stage: test
bolt: 031-gap-fill-ui
created: '2026-09-20T17:05:00Z'
---

## Test Report: 002-gap-fill-ui

### Summary

- **Tests**: 473/473 passed (422 before this bolt, +51)
- **Analyze**: 13 issues, all pre-existing `info` lints. Zero warnings, zero errors
- **Backend**: untouched

### Test Files

- [x] `test/shared/services/lesson_pack_json_test.dart` - **new**. The offline pack's JSON round trip, through real `jsonEncode`/`jsonDecode` rather than just the maps. Covers a pack holding all five types, gap-fill's fields, the empty-side case, a mid-sentence gap, grading after the round trip, and an unknown type failing loudly.
- [x] `test/features/lesson/widgets/gap_sentence_test.dart` - **new**, 40 tests. Both sides of the gap render; empty and filled states; gaps at the start and end; the gap does not change width when filled or when a longer word is chosen; no overflow at five text scales on three widths in both Fidel and Latin; a long sentence wraps; and the gap is announced to a screen reader.
- [x] `test/features/lesson/screens/lesson_screen_test.dart` - four tests: the gap fills on tap with Check disabled until then; tapping another word moves the selection and tapping the chosen word again keeps it; an incorrect answer requeues the exercise; and a pack containing a gap-fill downloads, plays offline with no network call, and queues its completion.
- [x] `test/shared/services/http_lesson_api_test.dart` - the API's `correct_choice_id` becomes the client's index.

### Acceptance Criteria Validation

- ✅ **Sealed-class arm and `isAnswerCorrect` case**: covered by the pack and screen tests
- ✅ **API parsing converts id to index**: asserted directly, on a non-zero index
- ✅ **The fake serves a gap-fill**: added, with the gap mid-sentence
- ✅ **Both halves of `lesson_pack_store.dart`, proven by a round trip**: proven, and the proof was verified (see Notes)
- ✅ **Sentence renders with a distinct gap, in Fidel and Latin**
- ✅ **Tapping a word fills the gap; the sentence does not reflow**: asserted by comparing the gap's width empty vs filled, and across options of different lengths
- ✅ **Check disabled until a word is chosen; another tap moves the selection**
- ✅ **Grading is local, no network call on Check**
- ✅ **`LessonController` gains no new state or methods**: it was never opened
- ✅ **Downloads, plays offline, syncs**: end to end, asserting the completion queued rather than called
- ✅ **No overflow at more than one text scale, in both scripts**: 5 scales × 3 widths × 2 scripts
- ✅ **Full suite green, analyze clean, no backend file touched**

### Issues Found

1. **The pack's JSON mapping had never been tested — for any exercise type.** It was private to a sqflite-backed store that `flutter test` cannot open, so the round trip every downloaded pack depends on was entirely unverified. Since an acceptance criterion required proving it, the four mapping functions were lifted to the top level of the same file. A deviation from the plan, flagged at the checkpoint; it is a visibility change, not a behaviour change, and it retires a real blind spot rather than only serving this bolt.

2. **A test of mine was wrong before the code was.** The first version tapped words with `find.text`, which becomes ambiguous the moment a word is also sitting in the gap — `tap` refused it. Fixed with a finder scoped to `ChoiceTile`. Worth noting because the ambiguity is itself evidence the feature works: the word really is on screen twice.

3. **`http_auth_api_e2e_test.dart` failed once in a full run and passed in isolation and on re-run.** The known intermittent flake against the real backend, unrelated to this bolt. Final full run: 473 passing.

### Notes

**The round-trip test was verified to be meaningful.** I removed the `gap_fill` case from `packExerciseFromJson` and re-ran: three tests failed with `Bad state: Unknown exercise type in cached pack: gap_fill`. The serialize half still **compiled**, which is the asymmetry this bolt kept warning about — the write direction is compiler-checked, the read direction is not, and a real user would have met that error inside a downloaded pack while offline. The case was restored and the file re-verified.

**The rendering risk was checked, but only as far as a test can.** The gap is a `WidgetSpan`, and the test font's metrics are not a device's. The tests prove no overflow at 1.0x–2.0x on 320/360/412dp in both scripts, and that the gap does not resize under the learner. They cannot prove the baseline looks right. That belongs to the device pass, along with whether a filled gap sits on the line rather than floating above it.

**Not covered here**: the sixteen `seed_category_content.py` lessons still have no gap-fill (backend follow-up), and typing into the gap remains out of scope.
