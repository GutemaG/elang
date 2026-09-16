---
id: 008-offline-sync-service
unit: 001-offline-sync-service
intent: 003-offline-caching-and-sync
type: ddd-construction-bolt
status: complete
stories:
  - 001-content-version-signal
  - 002-timestamped-completion-for-streak-attribution
  - 003-idempotent-offline-replay
created: '2026-09-16T21:00:00Z'
started: '2026-09-16T21:30:00Z'
completed: '2026-09-16T23:15:00Z'
current_stage: null
stages_completed:
  - name: model
    completed: '2026-09-16T21:30:00Z'
    artifact: ddd-01-domain-model.md
  - name: design
    completed: '2026-09-16T21:45:00Z'
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: '2026-09-16T22:00:00Z'
    artifact: adr-6-no-batch-sync-endpoint.md
  - name: implement
    completed: '2026-09-16T22:30:00Z'
    artifact: backend/app (amended)
  - name: test
    completed: '2026-09-16T23:00:00Z'
    artifact: ddd-03-test-report.md

requires_bolts: []
enables_bolts:
  - 009-offline-caching-and-sync-ui
  - 010-offline-caching-and-sync-ui
requires_units: []
blocks: false

complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 008-offline-sync-service

## Overview

Only bolt for the `001-offline-sync-service` unit. Amends `002-core-lesson-loop`'s existing lesson-content and completion endpoints (from bolts 004/005) rather than building new ones: adds a content-version signal, teaches streak/XP-day attribution to trust a client-supplied completion timestamp, and re-verifies the existing `attemptId` idempotency guarantee under delayed/replayed calls.

## Objective

Deliver the amended API contract that `002-offline-caching-and-sync-ui`'s download manager and sync engine integrate against, without regressing `002-core-lesson-loop`'s existing 215/215 backend test suite.

## Stories Included

- **001-content-version-signal**: Expose a content-version signal for staleness checks (Must)
- **002-timestamped-completion-for-streak-attribution**: Accept a client-supplied completion timestamp for streak/XP-day attribution (Must)
- **003-idempotent-offline-replay**: Re-verify/extend idempotent replay of delayed completions (Must)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- ✅ **1. Domain Model**: Complete → ddd-01-domain-model.md
- ✅ **2. Technical Design**: Complete → ddd-02-technical-design.md
- ✅ **3. ADR Analysis**: Complete → adr-6-no-batch-sync-endpoint.md
- ✅ **4. Implement**: Complete → backend/app (amended)
- ✅ **5. Test**: Complete → ddd-03-test-report.md
- [ ] **3. ADR Analysis**: Pending → adr-*.md (if any decisions warrant one, e.g. the batch-sync-endpoint question)
- [ ] **4. Implement**: Pending → backend/ (amended router/service modules)
- [ ] **5. Test**: Pending → ddd-03-test-report.md

## Dependencies

### Requires
- None to start — amends `001-lesson-service` (intent `002-core-lesson-loop`), which is already complete

### Enables
- `009-offline-caching-and-sync-ui` and `010-offline-caching-and-sync-ui` (both need this bolt's amended contract to integrate against)

## Success Criteria

- [ ] Content-version signal present on lesson-content/skill-tree responses
- [ ] `client_completed_at` accepted, validated, and correctly drives streak/XP-day attribution
- [ ] Idempotent replay re-verified (and hardened if gaps found) for delayed/duplicate completion calls
- [ ] `002-core-lesson-loop`'s existing backend test suite still passes in full

## Notes

Deliberately a single bolt, not split — this unit amends existing endpoints rather than introducing a new aggregate, so there's no natural "content vs. engagement" seam the way `002-core-lesson-loop`'s two backend bolts had.
