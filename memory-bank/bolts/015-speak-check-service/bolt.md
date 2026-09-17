---
id: 015-speak-check-service
unit: 001-speak-check-service
intent: 006-speak-check-exercise-type
type: ddd-construction-bolt
status: planned
stories:
  - 001-serve-speak-check-exercise-content
  - 002-grade-speak-check-attempt
created: '2026-09-17T15:00:00Z'
started: null
completed: null
current_stage: null
stages_completed: []

requires_bolts: []
enables_bolts:
  - 016-speak-check-ui
requires_units: []
blocks: false

complexity:
  avg_complexity: 3
  avg_uncertainty: 3
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 015-speak-check-service

## ⛔ DO NOT START — External Precondition Not Met

**Google Cloud Speech-to-Text has not been provisioned** (no GCP account/project/billing/API credentials exist yet, per intent `006-speak-check-exercise-type`'s requirements.md Constraints/Assumptions). This bolt exists so Construction has a ready starting point the moment provisioning is confirmed — it is **not** ready to start today. If asked to start this bolt, confirm provisioning status with the user first rather than proceeding or substituting a placeholder/mock credential silently.

## Overview

Serves `speak_check` exercise content and grades a recorded attempt server-side via Google Cloud Speech-to-Text — the first exercise type in this codebase graded server-side rather than client-side (a deliberate deviation from ADR-5).

## Objective

Deliver a working, real `speak_check` content + grading contract for `016-speak-check-ui` to build against, with cost/latency guardrails from day one and a new ADR documenting the grading-architecture deviation.

## Stories Included

- **001-serve-speak-check-exercise-content**: content model + migration + seed content (Must)
- **002-grade-speak-check-attempt**: real STT-backed grading endpoint + guardrails (Must)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- [ ] **1. Domain Model**: Pending → ddd-01-domain-model.md
- [ ] **2. Technical Design**: Pending → ddd-02-technical-design.md
- [ ] **3. ADR Analysis**: Pending → adr-*.md (this bolt genuinely deviates from ADR-5 — take this stage seriously, expect at least one new ADR)
- [ ] **4. Implement**: Pending → backend/ (amended) — **blocked until GCP provisioning is confirmed**
- [ ] **5. Test**: Pending → ddd-03-test-report.md

## Dependencies

### Requires
- None to start Stages 1-3 (domain modeling/design/ADR analysis don't need real GCP access) — but Stage 4 (Implement) requires real GCP credentials to exist.

### Enables
- `016-speak-check-ui` (needs the real endpoint contract)

## Success Criteria

- [ ] `speak_check` exercise content served correctly, following the existing `content`/`answer_key` pattern
- [ ] Recorded attempts graded via a real Google Cloud Speech-to-Text call, with fuzzy scoring and unlimited retries
- [ ] Cost/latency guardrails enforced (max recording duration, STT call timeout, graceful failure)
- [ ] A new ADR documents the server-side-grading deviation from ADR-5
- [ ] Zero regression to `001-lesson-service`'s existing test suite

## Notes

Highest complexity/uncertainty of any bolt so far in this project (external metered API, new grading architecture, no prior pattern to copy). Even Stages 1-3 (which don't need real GCP access) should be treated as genuinely exploratory, not a rubber-stamp pass through a familiar template.
