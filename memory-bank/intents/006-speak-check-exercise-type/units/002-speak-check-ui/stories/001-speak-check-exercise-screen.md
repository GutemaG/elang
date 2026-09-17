---
id: 001-speak-check-exercise-screen
unit: 002-speak-check-ui
intent: 006-speak-check-exercise-type
status: ready
priority: must
created: '2026-09-17T14:50:00Z'
assigned_bolt: null
implemented: false
---

# Story: 001-speak-check-exercise-screen

## User Story

**As a** Buna learner
**I want** to record myself saying a phrase and see whether I got it right
**So that** I can practice speaking, not just reading/listening

## Acceptance Criteria

- [ ] **Given** a `speak_check` exercise, **When** the user taps record, **Then** recording starts, and tapping stop ends it
- [ ] **Given** a completed recording, **When** the user reviews it, **Then** they can re-record before submitting
- [ ] **Given** a submitted recording, **When** the backend responds, **Then** pass/fail feedback is shown, matching the atomic Check-based feedback pattern every other exercise type uses (per `012-match-pairs-ui`'s established convention — no live per-syllable feedback)
- [ ] **Given** a failed attempt, **When** the user wants to try again, **Then** there is no attempt cap (FR-4)
- [ ] **Given** microphone permission is denied, **When** the user tries to record, **Then** a clear, non-crashing message explains why recording isn't available

## Technical Notes

- Mirror the existing atomic build-then-Check pattern (`LessonController`'s established convention across all 4 existing exercise types) rather than inventing a new interaction model for this 5th type
- New recording package choice is a Technical Design decision at Construction, not fixed here
- Mock at the plugin boundary only for the recording package, same convention as `AnswerFeedbackPlayer`/`LessonAudioPlayer`

## Dependencies

### Requires
- `001-speak-check-service`'s stories (needs the real endpoint contract)

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Network failure during submission | Same generic-error-plus-retry pattern already established for other exercise-type/network failures in this codebase, not a new one |
| App backgrounded mid-recording | Not specially handled in this pass — flag as a known gap if discovered at Construction, don't silently solve it with unplanned scope |

## Out of Scope

- Offline behavior (see `002-exclude-speak-check-from-offline-packs`)
