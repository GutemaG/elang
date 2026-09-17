---
intent: 006-speak-check-exercise-type
phase: inception
status: complete
created: '2026-09-17T04:00:00Z'
updated: '2026-09-17T14:30:00Z'
---

# Requirements: Speak-Check Exercise Type

## Intent Overview

Add `speak_check` as the fifth and final originally-planned exercise type: the user speaks a phrase aloud and the app checks it against the target phrase via Google Cloud Speech-to-Text. Confirmed by search: no speech/audio-recording package exists in `pubspec.yaml` yet (only `audioplayers`, for playback), and no Google Cloud dependency exists anywhere in `backend/pyproject.toml`. This is a genuinely new integration on both sides, not an extension of existing audio handling.

**Explicit scope decision (Checkpoint 1)**: the user has not yet provisioned a Google Cloud Speech-to-Text account/project/billing. Per the user's direction, this intent's Inception artifacts (this document, system context, units, stories, bolt plan) are produced now, in full, but **Construction is not started** for this intent — real GCP provisioning is a precondition for Construction's Implement stage, not for Inception.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Deliver the 5th and final originally-planned exercise type, closing the last exercise-type gap from the original product scope | `speak_check` exercises are fully playable end-to-end once Construction begins | Must |
| Introduce the new external dependency (Google Cloud Speech-to-Text) safely, with cost/latency guardrails from day one | No unbounded per-attempt cost or latency; failures degrade gracefully | Must |

---

## Functional Requirements

### FR-1: Speak-Check Content Model
- **Description**: New `ExerciseType.SPEAK_CHECK` value. Content carries the target phrase (Amharic text) the user must say aloud, plus its translation (for the prompt UI) — mirroring every other exercise type's existing `content`/`answer_key` sibling-field split (ADR-3), even though here the two are largely the same string (there is no reason to hide the target phrase from the user, unlike a multiple-choice's correct answer).
- **Acceptance Criteria**:
  - A `speak_check` exercise's content includes the target phrase and its translation
  - Follows the existing polymorphic `exercises` table pattern (ADR-3) — a `CheckConstraint` migration to widen `ck_exercises_type`, per the precedent from `011-match-pairs-service`
- **Priority**: Must

### FR-2: Server-Side Grading via Google Cloud Speech-to-Text
- **Description**: The user's recorded attempt is sent to the backend, which calls Google Cloud Speech-to-Text to transcribe it, then compares the transcript to the target phrase.
- **Acceptance Criteria**:
  - A new authenticated endpoint accepts a recorded audio attempt for a given exercise and returns a pass/fail result (and ideally the transcript, for user feedback)
  - Grading happens server-side
- **Priority**: Must
- **Open question carried to Technical Design/ADR**: every other exercise type in this codebase grades client-side (ADR-5: the lesson-content payload ships correct-answer data, and the client grades instantly with no per-exercise network call — the server only bounds the account ledger). `speak_check` cannot follow that model: there is no client-side speech-recognition capability in this stack, and calling Google Cloud STT directly from the client would require the mobile app to hold GCP credentials, which this project's existing patterns (server-side OAuth verification in `001-auth-service`) argue against. This is a deliberate, first-of-its-kind deviation from ADR-5 for this one exercise type and should get its own ADR at Construction, analogous to ADR-7's invariant-amendment record.

### FR-3: Client Audio-Recording UI
- **Description**: A new recording widget: tap to record, tap to stop, then submit. Requires microphone permission handling and a new recording package (none exists yet — `audioplayers` is playback-only).
- **Acceptance Criteria**:
  - The user can record, re-record before submitting, and submit an attempt
  - Microphone-permission-denied is handled explicitly (not a crash)
- **Priority**: Must

### FR-4: Fuzzy Scoring, Unlimited Retries
- **Description**: Grading uses a tolerant similarity threshold against the target phrase (not exact transcript match), with no cap on retry attempts — matches this app's existing low-stakes, practice-oriented tone (no other exercise type punishes retries either).
- **Acceptance Criteria**:
  - A close-but-imperfect transcript can still pass
  - The user may retry as many times as they want
- **Priority**: Must
- **Open question carried to Technical Design**: the exact similarity algorithm and numeric pass threshold are not fixed here.

### FR-5: Excluded from Offline Downloadable Packs
- **Description**: Since grading requires a live call to an external service, `speak_check` exercises cannot be scored offline. Per the user's explicit choice (Checkpoint 1): excluded from downloadable lesson packs entirely, rather than building a record-now-score-later offline queue.
- **Acceptance Criteria**:
  - A lesson containing a `speak_check` exercise is not silently broken when downloaded for offline use — either the whole lesson is excluded from download eligibility, or the exercise itself is skipped within an otherwise-downloadable lesson
- **Priority**: Must
- **Open question carried to Technical Design**: whole-lesson vs. per-exercise exclusion granularity is not fixed here — a real design choice once `LessonPackDownloader`'s actual per-exercise-type handling is read at Construction (forbidden at this Inception stage's remove, and this codebase's DDD bolts forbid source-reading before Stage 4 anyway).

### FR-6: Cost/Latency Guardrails
- **Description**: This is the first per-request-billed external API call anywhere in this codebase (Google/Apple OAuth verification is free; Speech-to-Text is metered). Needs an explicit guardrail design, not an afterthought.
- **Acceptance Criteria**:
  - A maximum recording duration is enforced (client-side, before upload)
  - The backend's STT call has a timeout and a defined failure behavior (not an unbounded hang)
- **Priority**: Must
- **Open question carried to Technical Design**: exact duration/timeout values, and whether any per-user rate limiting is warranted, are not fixed here.

---

## Non-Functional Requirements

### Security & Privacy
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Recorded audio is not retained longer than needed to grade the attempt | New — no prior NFR in this codebase addresses voice data | This is the first feature handling anything audio-as-input (existing audio is all outbound/playback); retention policy is a real decision, not assumed |
| The new endpoint | Same session-token auth as every other authenticated endpoint | No new auth mechanism |

### Reliability
| Requirement | Standard | Notes |
|-------------|----------|-------|
| A Google Cloud STT outage or timeout must not crash the lesson-taking flow | New | Must degrade to a visible, retryable error — see FR-6 |

### Cost
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Per-attempt cost must be bounded | New — first metered external API in this codebase | See FR-6's guardrails |

---

## Constraints

### Technical Constraints
- No change to the other 4 exercise types.
- New backend dependency: a Google Cloud Speech-to-Text client library — not yet in `backend/pyproject.toml`.
- New Flutter dependency: an audio-recording package — not yet in `pubspec.yaml` (`audioplayers` is playback-only).
- **GCP account/project/billing/API credentials do not exist yet.** Requirements and Technical Design proceed on a config-driven-credential assumption (mirroring `Settings.google_oauth_client_id`'s pattern in `backend/app/config.py`) — the real credential must be provisioned before Construction's Implement stage can make a real call, but Inception does not require it to exist.

### Business Constraints
- None identified beyond normal project pacing.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| A GCP project with Speech-to-Text billing enabled will be provisioned before this intent's Construction Implement stage begins | Implement stage blocked until it exists | Flagged explicitly here and in the bolt plan's dependencies; Construction should not be started for this intent until provisioning is confirmed |
| Fuzzy scoring is acceptable for this feature's pedagogical goal (encouragement over strict assessment) | If stricter assessment is later desired, the threshold is a config value, not a rewrite | Threshold left as an explicit Technical Design/config decision, not hardcoded |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Google Cloud Speech-to-Text account/billing setup | User | Checkpoint 1 | **Resolved**: not yet provisioned — document the requirement now, provision before Construction's Implement stage; do not implement against a real account today |
| Offline behavior for a downloaded pack containing a `speak_check` exercise | User | Checkpoint 1 | **Resolved**: excluded from downloadable packs entirely (exact granularity — whole-lesson vs. per-exercise — deferred to Technical Design) |
| Scoring threshold / retry UX | User | Checkpoint 1 | **Resolved**: fuzzy similarity threshold, unlimited retries (exact algorithm/threshold value deferred to Technical Design) |

---

## Dependencies

- Blocked on `004-match-pairs-exercise-type` and `005-profile-and-settings` only by sequencing choice, not technical necessity (both are now complete).
- New external dependency: Google Cloud Speech-to-Text (not used anywhere else in this codebase today) — **not yet provisioned; Construction should not begin until it is.**
