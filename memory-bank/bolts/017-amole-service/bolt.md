---
id: 017-amole-service
unit: 001-amole-service
intent: 007-amole-currency
type: ddd-construction-bolt
status: planned
stories:
  - 001-ledger-backed-amole-balance
  - 002-award-amole-on-completion
created: '2026-09-17T16:30:00Z'
started: null
completed: null
current_stage: null
stages_completed: []

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

- [ ] **1. Domain Model**: Pending → ddd-01-domain-model.md
- [ ] **2. Technical Design**: Pending → ddd-02-technical-design.md
- [ ] **3. ADR Analysis**: Pending → adr-*.md (this amends a shipped aggregate's persisted shape — treat seriously, don't rubber-stamp "no ADR needed")
- [ ] **4. Implement**: Pending → backend/ (amended)
- [ ] **5. Test**: Pending → ddd-03-test-report.md

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
