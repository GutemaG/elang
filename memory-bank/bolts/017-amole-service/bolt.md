---
id: 017-amole-service
unit: 001-amole-service
intent: 007-amole-currency
type: ddd-construction-bolt
status: complete
stories:
  - 001-ledger-backed-amole-balance
  - 002-award-amole-on-completion
created: '2026-09-17T16:30:00Z'
started: '2026-09-17T17:30:00Z'
completed: '2026-09-17T14:45:29Z'
current_stage: null
stages_completed:
  - name: model
    completed: '2026-09-17T17:45:00Z'
    artifact: ddd-01-domain-model.md
  - name: design
    completed: '2026-09-17T18:00:00Z'
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: '2026-09-17T18:20:00Z'
    artifact: adr-8-amole-ledger-not-column.md, adr-9-bean-refill-idempotency-gap-accepted.md
  - name: implement
    completed: '2026-09-17T19:00:00Z'
    artifact: backend/ (amended)
  - name: test
    completed: '2026-09-17T19:30:00Z'
    artifact: ddd-03-test-report.md
requires_bolts: []
enables_bolts:
  - 018-amole-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 017-amole-service

## Overview

Replaces the mutable `user_beans.amole_balance` column with an append-only `amole_transactions` ledger, adds the missing Amole-award side-effects to `complete_lesson`, and retrofits the already-shipped spend/balance code onto the ledger.

## Objective

Amole becomes a real earn-and-spend loop: lesson completion, perfect-lesson bonus, and streak milestones all award it; the existing Bean-refill spend and balance-read paths are unchanged externally but now backed by an auditable, idempotent ledger.

## Stories Included

- **001-ledger-backed-amole-balance**: ledger table + migration + retrofit of existing spend/balance code (Must)
- **002-award-amole-on-completion**: award triggers inside `complete_lesson` (Must)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- [x] **1. Domain Model**: ✅ Complete → ddd-01-domain-model.md
- [x] **2. Technical Design**: ✅ Complete → ddd-02-technical-design.md
- [x] **3. ADR Analysis**: ✅ Complete → adr-8-amole-ledger-not-column.md, adr-9-bean-refill-idempotency-gap-accepted.md
- [x] **4. Implement**: ✅ Complete → backend/ (amended)
- [x] **5. Test**: ✅ Complete → ddd-03-test-report.md

## Dependencies

### Requires
- None — no external precondition, unlike `015-speak-check-service`. Amends bolt `005-lesson-engagement-service`'s shipped code directly.

### Enables
- `018-amole-ui` (needs the retrofitted balance endpoint, though its response shape is unchanged)

## Success Criteria

- [ ] Existing users' balances are preserved exactly across the migration (verified, not assumed)
- [ ] Existing spend/balance API contracts are byte-for-byte unchanged in shape
- [ ] Lesson completion, perfect lesson, and 7-day/30-day streak milestones each award Amole exactly once per qualifying event, even under a retried request
- [ ] Zero regression to bolt `005`'s existing test suite (`test_bean_ledger.py`, lesson-engagement use-case/endpoint/repository tests)

## Notes

This is a retrofit of shipped code, not a greenfield bolt — read `UserBeans`, `complete_lesson`, and `refill_beans_with_amole`'s real current implementations at Stage 4 before finalizing the design from Stages 1-2's necessarily-source-blind pass (same discipline as bolt `013`'s "Corrected during Stage 4" sections).
