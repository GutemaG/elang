---
unit: 001-speak-check-service
intent: 006-speak-check-exercise-type
phase: inception
status: ready
created: '2026-09-17T14:45:00Z'
updated: '2026-09-17T14:45:00Z'
---

# Unit Brief: Speak-Check Service

## Purpose

Serve `speak_check` exercise content (target phrase + translation) and grade a recorded attempt by calling Google Cloud Speech-to-Text and fuzzy-comparing the transcript to the target phrase — the first exercise type in this codebase where grading happens server-side rather than client-side.

## Scope

### In Scope
- New `ExerciseType.SPEAK_CHECK` value + content/answer-key value objects
- `exercises` table CHECK-constraint migration (same pattern as `011-match-pairs-service`)
- New authenticated endpoint accepting a recorded audio attempt, returning pass/fail (+ transcript)
- Google Cloud Speech-to-Text integration, config-driven credentials (mirrors `Settings.google_oauth_client_id`)
- Fuzzy-similarity scoring (exact algorithm/threshold a Technical Design decision)
- Cost/latency guardrails: recording-duration limit (enforced client-side, but the contract/limit is defined here), STT-call timeout, graceful failure behavior
- Seed content: at least one `speak_check` exercise

### Out of Scope
- Any UI (owned by `002-speak-check-ui`)
- Offline queueing/deferred scoring (excluded per FR-5's resolved decision)
- Any change to the other 4 exercise types' grading model

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Speak-Check Content Model | Must |
| FR-2 | Server-Side Grading via Google Cloud Speech-to-Text | Must |
| FR-4 | Fuzzy Scoring, Unlimited Retries | Must |
| FR-6 | Cost/Latency Guardrails | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `Exercise` (existing, extended) | Adds `SPEAK_CHECK` to `ExerciseType` | New content/answer-key value objects for the target phrase |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| GradeSpeakCheckAttempt | Transcribes recorded audio and scores it against the target phrase | exercise_id, audio bytes | pass/fail, transcript, similarity score |

---

## Technical Context

### Suggested Technology
Python/FastAPI, extending `backend/app/domain/lesson/value_objects.py` (new content/answer-key types), a new Google Cloud Speech-to-Text client library (not yet a dependency — verify against `backend/pyproject.toml` at Construction), a new `Settings` field for credentials/config (mirrors `google_oauth_client_id`).

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| Google Cloud Speech-to-Text | Transcribes the recorded attempt | **Not yet provisioned.** Must be confirmed before Construction's Implement stage. Also: per-request cost, network latency/outage — see FR-6's guardrails. |

---

## Constraints

- Must not weaken session-token authentication or introduce a new auth mechanism.
- Grading is deliberately server-side (FR-2) — a documented deviation from ADR-5, expected to get its own ADR at Construction's ADR Analysis stage, not silently treated as "no ADR needed" by pattern-matching to a prior bolt.
- Do not implement this unit's Google Cloud STT integration against a real account in this pass — provisioning is a precondition, not something to work around with a placeholder that later needs replacing quietly.

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 015-speak-check-service | ddd-construction-bolt | 001, 002 | Content model + server-side grading + guardrails |

---

## Notes

**Do not start Construction on this bolt until Google Cloud Speech-to-Text is provisioned.** This unit-brief and its stories exist so Construction has a ready starting point the moment that precondition is met — this is an intentional "Inception-ahead-of-Construction" pass, not an oversight.
