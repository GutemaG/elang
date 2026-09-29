---
stage: plan
bolt: 058-audio-playing-state
created: '2026-09-29T09:23:25Z'
---

## Implementation Plan: audio-playing-state

### Objective

- The play button shows "playing" from the tap (or the auto-play) until
  the clip ends, not just until it starts.
- While playing it is animated: moving sound bars and a pulsing ring.
- A tap while playing starts the clip again from the beginning.

### What the code says (checked before planning)

- **F1: "Playing" ends when the clip starts.** `_LessonQuestionState`
  counts plays in `_starting` and lowers it when `play()` returns.
  `AudioplayersLessonAudioPlayer.play` returns once playback has started,
  so the look lasts about as long as loading (about a second).
- **F2: The button is still by design.** `AudioPlayButton` swaps the
  speaker for a still `graphic_eq` icon and adds a halo; its doc says the
  caller decides how long that lasts.
- **F3: A tap already restarts.** `play()` calls `stop()` and plays from
  the start, so only the "playing" look needs fixing for a replay.
- **F4: Nothing stops a clip when its question goes.** The player is
  shared app-wide; leaving the lesson mid-clip lets it play on.
- **F5: Reduced motion.** `AppMotion.reduced(context)` is how components
  skip movement (bolt 049); they keep colour changes only.
- **F6: Tests.** Many widget tests `pumpAndSettle` on audio questions.
  The fake player returns at once, so "playing" ends at once there and a
  looping animation never blocks settling.

### Decisions

- **D1: `play()` returns when the clip ends.**
  - `LessonAudioPlayer.play` now completes when the clip finishes, is
    replaced by another play, or is stopped. It throws if it cannot play.
  - `AudioplayersLessonAudioPlayer` keeps a completer for the current
    clip. It completes on `onPlayerComplete`, on a new `play()` (after
    `stop()`), on `stop()` and on `dispose()`.
  - `CachingLessonAudioPlayer` passes that through; a play replaced while
    downloading returns at once, as now.
- **D2: New `stop()`** on `LessonAudioPlayer`.
- **D3: The lesson's "playing" look.** `_starting` becomes `_playing`,
  with the same counting, so it spans download plus playback. A tap while
  playing replays: the first play returns (replaced) and the second
  carries on, so the look never flickers off.
- **D4: Stop when the question goes.** `_LessonQuestionState.dispose`
  stops the clip, so a clip never plays on after Continue or leaving the
  lesson. The next question's own auto-play is unaffected: it starts
  after the old question is gone.
- **D5: The animation, in `AudioPlayButton`** (becomes stateful, one
  repeating controller that runs only while `playing`).
  - Four rounded sound bars replace the still `graphic_eq` icon and rise
    and fall out of step, about 900 ms a cycle.
  - A ring behind the face grows and fades, about 1.2 s a cycle.
  - Both sizes, large and small; the colours stay the design system's.
  - Reduced motion: no movement, bars at rest heights plus the existing
    halo (today's still look).
  - Stops the moment `playing` goes false; nothing runs at rest.
- **D6: Gallery.** The kit gallery's "playing" sample shows the animation.

### Out of scope

- Pause, a progress bar, or playback speed.
- The answer-feedback sounds (separate player).

### Acceptance criteria

- **A. Player**
  - [ ] `play()` completes when the clip ends, is replaced, or is
    stopped.
  - [ ] `stop()` ends the current clip.
- **B. Lesson**
  - [ ] "Playing" shows from the tap or auto-play until the clip ends,
    download time included.
  - [ ] A tap while playing restarts the clip and the look stays on.
  - [ ] Leaving the question stops its clip.
- **C. Button**
  - [ ] While playing, the bars and the ring move; at rest nothing runs.
  - [ ] With reduced motion, nothing moves while playing.
  - [ ] "Playing audio" for screen readers, as now.
- **D. Checks**
  - [ ] `flutter analyze` clean; `flutter test` passes.
  - [ ] On a phone: the look lasts the whole clip; a replay tap restarts
    it (left for a person).

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-29 and built as written (D1-D6).

### Player (`lesson_audio_player.dart`)

- `LessonAudioPlayer` has `stop()`, and `play()` completes when the clip
  is over.
- `AudioplayersLessonAudioPlayer`:
  - One completer per play. It completes on `onPlayerComplete`, on the
    next `play()`, on `stop()` and on `dispose()`.
  - An end heard before the new clip has started belongs to the old clip,
    so it is ignored (`_started`).
  - A clip already `completed` when `play` returns (a very short clip)
    ends at once, so "playing" can't stick.
  - A play replaced while stopping the old clip returns without playing.
- `CachingLessonAudioPlayer.stop()` also counts as the latest ask, so a
  clip still downloading when stopped never starts.

### Lesson (`lesson_screen.dart`)

- `_starting` became `_playing`: the same counting, but now held for the
  whole clip because `play()` lasts the clip.
- `_LessonQuestionState.dispose` stops the clip if this question's clip is
  still playing. The next question's auto-play runs after its first frame,
  so after that stop.

### Button (`audio_play_button.dart`)

- Now a `StatefulWidget` with one `AnimationController` (1.2 s,
  repeating), running only while `playing` and not reduced motion. It
  stops and resets as soon as either changes.
- `SoundBarsPainter` (public for tests) draws four rounded bars.
  - Heights follow sines with whole-number speeds, so the loop has no
    jump. Without a phase they rest at fixed heights.
- A ring (`_Ring`, the face's size, behind it) swells to 1.45x and fades
  out, eased, once a cycle.
- The halo and the "Playing audio" label stay as they were.
- The gallery's "playing" samples now animate, with no gallery change
  needed.

### Tests

- `audio_play_button_test.dart`: the still-look test was replaced with:
  - bars and halo;
  - bars and ring move;
  - nothing runs at rest, and the motion stops when playing ends;
  - reduced motion stays still;
  - the loop has no jump.
- `lesson_screen_kit_test.dart`:
  - "playing until the clip is over" (still on 3 s in; a replay tap keeps
    it on);
  - "leaving the question stops its clip".
- `caching_lesson_audio_player_test.dart`: a stop cancels a clip still
  downloading.
- `FakeLessonAudioPlayer` counts `stops`.
- `AudioplayersLessonAudioPlayer` itself has no unit test: it needs the
  platform plugin, which tests cannot load. It is left for the phone
  check.

## Checks (Stage 2)

- `flutter analyze`: no issues.
- `flutter test --exclude-tags e2e`: 1412 passed.

---

## Test Report (Stage 3)

Implement approved 2026-09-29.

### Runs

| Suite | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test --exclude-tags e2e` | 1412 passed |
| Button and lesson-kit tests, repeated | passed 3 of 3 runs |

The e2e auth tests need a backend on port 8000 and were not run; this bolt
does not touch auth.

### Acceptance criteria

- **A. Player**
  - [x] `play()` completes when the clip is replaced or stopped (the
    caching player's tests). The real end of a clip comes from the
    `audioplayers` plugin, which tests cannot load; see "Left for a
    person".
  - [x] `stop()` ends the current clip, and a clip still downloading never
    starts.
- **B. Lesson** (`lesson_screen_kit_test.dart`)
  - [x] "Playing" shows from auto-play until the clip is over, 3 s in
    included.
  - [x] A tap mid-clip replays it and the look stays on.
  - [x] Leaving the question stops its clip.
- **C. Button** (`audio_play_button_test.dart`)
  - [x] While playing, the bars and the ring move; at rest nothing runs.
  - [x] With reduced motion, nothing moves while playing.
  - [x] "Playing audio" for screen readers, unchanged.
- **D. Checks**
  - [x] `flutter analyze` clean; `flutter test` passes.
  - [ ] On a phone: the look lasts exactly the clip, and a tap mid-clip
    restarts it. Not tried yet.

### Left for a person

- On a phone: a listening question's bars move for the whole clip and stop
  when the sound ends. A tap mid-clip starts it over. Continue mid-clip
  silences it.
- Turn on Settings > Accessibility > Remove animations: the button should
  show the bars still while playing.
