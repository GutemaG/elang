---
id: 019-srs-tracking-service
unit: 001-srs-tracking-service
intent: 008-srs-and-practice
type: ddd-construction-bolt
status: complete
stories:
  - 001-vocab-item-content-model
  - 002-vocab-progress-retrofit
  - 003-leitner-box-algorithm
  - 004-due-items-and-count-endpoints
created: '2026-09-17T17:10:00Z'
started: '2026-09-17T21:00:00Z'
completed: '2026-09-17T18:53:23Z'
current_stage: null
stages_completed:
  - name: model
    completed: '2026-09-17T21:15:00Z'
    artifact: ddd-01-domain-model.md
  - name: design
    completed: '2026-09-17T21:30:00Z'
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: '2026-09-17T21:45:00Z'
    artifact: adr-10-widen-completion-contract-for-vocab-tracking.md
  - name: implement
    completed: '2026-09-17T22:45:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-17T23:00:00Z'
    artifact: ddd-03-test-report.md
requires_bolts: []
enables_bolts:
  - 020-practice-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 4
  avg_uncertainty: 3
  max_dependencies: 1
  testing_scope: 4
---

# Bolt: 019-srs-tracking-service

## Overview

Greenfield vocab content model (`vocab_items`, `exercises.vocab_item_id`), a retrofit of `complete_lesson` to track per-user progress against it, a Leitner-box spacing algorithm, and due-items/due-count endpoints for the Practice UI.

## Objective

A vocab item introduced in a lesson gets tracked; wrong answers bring it back sooner; the due-count is always accurate and cheap to check.

## Stories Included

- **001-vocab-item-content-model**: schema + seed linking (Must)
- **002-vocab-progress-retrofit**: `complete_lesson` side-effects (Must)
- **003-leitner-box-algorithm**: box transition math (Must)
- **004-due-items-and-count-endpoints**: session-assembly/badge endpoints (Must)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- [x] **1. Domain Model**: ✅ Complete → ddd-01-domain-model.md
- [x] **2. Technical Design**: ✅ Complete → ddd-02-technical-design.md
- [x] **3. ADR Analysis**: ✅ Complete → adr-10-widen-completion-contract-for-vocab-tracking.md
- [x] **4. Implement**: ✅ Complete → implementation-walkthrough.md
- [x] **5. Test**: ✅ Complete → ddd-03-test-report.md

## Dependencies

### Requires
- None — no external precondition. Sequenced after `007-amole-currency` by user preference only.

### Enables
- `020-practice-ui` (needs the real due-items/due-count/completion contracts)

## Success Criteria

- [x] A vocab item introduced in a lesson gets a `user_vocab_progress` row
- [x] Answering it incorrectly resets its box and moves `next_review_at` to tomorrow
- [x] Due-items and due-count endpoints agree with each other and with real data
- [x] A delayed offline-sync replay does not double-update progress
- [x] Zero regression to existing lesson-completion/offline-sync/exercise-rendering behavior for non-vocab-linked exercises

## Notes

Read `complete_lesson`'s real current request/response shape and the offline-sync replay path at Stage 4 before finalizing — story 002 explicitly flags that the completion request may need to widen to carry per-exercise correctness, which this codebase doesn't obviously have today at the aggregate level Inception could verify without reading Construction-time source.
