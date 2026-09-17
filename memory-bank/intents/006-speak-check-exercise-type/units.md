---
intent: 006-speak-check-exercise-type
phase: inception
created: '2026-09-17T14:40:00Z'
---

# Units: speak-check-exercise-type

## Overview

2 units, mirroring `004-match-pairs-exercise-type`'s backend/frontend split — but unlike that intent, grading stays on the **backend** unit here (FR-2's deliberate ADR-5 deviation), since there's no client-side speech-recognition capability to grade with.

## Units

### 001-speak-check-service (backend, ddd-construction-bolt)

**Purpose**: Serve `speak_check` exercise content and grade recorded attempts via Google Cloud Speech-to-Text.
**Assigned Requirements**: FR-1, FR-2, FR-4, FR-6
**Complexity**: Higher than `011-match-pairs-service` — new external dependency, new grading architecture (deviates from ADR-5), new cost/latency guardrails, no prior pattern to copy for any of these.
**Blocked on**: Google Cloud Speech-to-Text provisioning (external, not a code dependency) — see requirements.md.

### 002-speak-check-ui (frontend, simple-construction-bolt)

**Purpose**: Recording UI, attempt submission, pass/fail feedback with unlimited retries, and offline-pack exclusion.
**Assigned Requirements**: FR-3, FR-5
**Complexity**: Similar to `012-match-pairs-ui`, plus a new recording package (not yet in `pubspec.yaml`) and microphone-permission handling — both genuinely new to this codebase.
**Depends on**: `001-speak-check-service` (needs the real endpoint contract).

## Dependency Graph

```text
001-speak-check-service --> 002-speak-check-ui
```

## Notes

Do not start Construction on `001-speak-check-service` until Google Cloud Speech-to-Text is provisioned. This is an Inception-only pass for this intent per the user's explicit Checkpoint 1 direction.
