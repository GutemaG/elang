---
id: 002-grade-speak-check-attempt
unit: 001-speak-check-service
intent: 006-speak-check-exercise-type
status: ready
priority: must
created: '2026-09-17T14:50:00Z'
assigned_bolt: null
implemented: false
---

# Story: 002-grade-speak-check-attempt

## User Story

**As a** Buna learner
**I want** my spoken attempt graded automatically
**So that** I get real pronunciation feedback, not just a recognition check

## Acceptance Criteria

- [ ] **Given** a signed-in user submits a recorded attempt for a `speak_check` exercise, **When** the backend transcribes it via Google Cloud Speech-to-Text and compares it to the target phrase, **Then** it returns pass/fail (and ideally the transcript)
- [ ] **Given** a close-but-imperfect transcript, **When** it's within the similarity threshold, **Then** the attempt passes (fuzzy scoring, not exact match — FR-4)
- [ ] **Given** any grading outcome, **When** the user retries, **Then** there is no attempt cap
- [ ] **Given** Google Cloud Speech-to-Text is unreachable or times out, **When** an attempt is submitted, **Then** the failure is surfaced as a clear, retryable error — never an unbounded hang or a crash
- [ ] **Given** a recording exceeding the enforced maximum duration, **When** submitted, **Then** it is rejected with a clear error before an STT call is even made (cost guardrail)

## Technical Notes

- **This is the first exercise type graded server-side** — every other type follows ADR-5 (client-side grading, server only bounds the ledger). Take the ADR Analysis stage seriously here; this is exactly the kind of decision that warrants a new ADR, not a "no ADR needed" rubber stamp.
- Exact similarity algorithm/threshold, STT call timeout value, and max recording duration are Technical Design decisions, not fixed here.
- Config-driven GCP credentials, mirroring `Settings.google_oauth_client_id` in `backend/app/config.py` — never hardcoded.
- **Do not implement this story against a real GCP account in this pass** — provisioning is an explicit precondition (see intent requirements.md's Constraints/Assumptions). If Construction reaches this story before provisioning is confirmed, stop and ask, don't substitute a placeholder silently.

## Dependencies

### Requires
- `001-serve-speak-check-exercise-content`

### Enables
- `002-speak-check-ui`'s story `001-speak-check-exercise-screen`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User submits silence / no speech detected | A defined, non-crashing outcome (likely a fail with a distinct reason, not the same as "wrong phrase") — exact UX a Technical Design decision |
| Background noise/poor audio quality | Not specially handled beyond whatever Google Cloud STT itself tolerates — no custom audio-quality gating in this pass |

## Out of Scope

- Any UI (see `002-speak-check-ui`)
- Per-user rate limiting beyond the per-attempt guardrails above (flag as a future consideration if real-world abuse is observed, don't build preemptively)
