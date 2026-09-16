---
intent: 006-speak-check-exercise-type
phase: inception
status: draft
created: '2026-09-17T04:00:00Z'
updated: '2026-09-17T04:00:00Z'
---

# Requirements: Speak-Check Exercise Type

## Intent Overview

Add `speak_check` as the fifth and final originally-planned exercise type: the user speaks a phrase and the app checks pronunciation/correctness. Requires Google Cloud Speech-to-Text (Track A of the AI plan). Larger lift than `004-match-pairs-exercise-type` (external API dependency, audio capture, latency/cost considerations) — sequenced last of the 3 gap-closing intents.

## Scope (draft)

### In Scope
- Backend: new `ExerciseType.SPEAK_CHECK` value, integration with Google Cloud Speech-to-Text for transcription/scoring, grading logic (likely fuzzy/threshold-based rather than exact-match)
- Client: audio recording UI, upload/stream to backend, result feedback
- Seed content: at least one `speak_check` exercise
- Cost/latency guardrails for the new external API call (not present anywhere else in this codebase yet)

### Out of Scope
- Any change to the other 4 exercise types
- Offline support for this exercise type specifically (speech-to-text requires network; a `speak_check` exercise inside a downloaded-for-offline pack needs a defined fallback — see Open Questions)

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Google Cloud Speech-to-Text account/billing setup — does this already exist, or does it need to be provisioned first? | User | Before Technical Design | Pending |
| What happens if a downloaded pack contains a `speak_check` exercise and the user is offline (per `003-offline-caching-and-sync`)? Skip it, block it, or exclude speak_check exercises from downloadable packs entirely? | User | Before requirements finalized | Pending |
| Scoring threshold / retry UX (how many attempts, what tolerance) | User | Before Technical Design | Pending |

## Dependencies

- Blocked on `004-match-pairs-exercise-type` and `005-profile-and-settings` only by sequencing choice, not technical necessity.
- New external dependency: Google Cloud Speech-to-Text (not used anywhere else in this codebase today).
