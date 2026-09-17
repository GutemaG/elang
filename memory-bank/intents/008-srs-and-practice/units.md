---
intent: 008-srs-and-practice
phase: inception
created: '2026-09-17T16:50:00Z'
---

# Units: srs-and-practice

## Overview

2 units, backend/frontend split, matching this project's established pattern. Backend unit is larger than the original build prompt assumed (greenfield schema, not a retrofit of dormant columns); frontend unit's entry-point mechanism is intentionally left open for Technical Design.

## Units

### 001-srs-tracking-service (backend, ddd-construction-bolt)

**Purpose**: New vocab content model, per-user progress tracking retrofit into `complete_lesson`, Leitner-box algorithm, due-items/due-count endpoints.
**Assigned Requirements**: FR-1, FR-2, FR-3, FR-4, FR-5
**Complexity**: Higher than the original build prompt assumed — greenfield schema (`vocab_items`, `user_vocab_progress`, new FK) plus a `complete_lesson` retrofit that must compose correctly with existing offline-replay idempotency.

### 002-practice-ui (frontend, simple-construction-bolt)

**Purpose**: Practice entry point with due-count badge, session assembly from due vocab items, reusing existing exercise-engine widgets.
**Assigned Requirements**: FR-6
**Complexity**: Moderate — no new exercise-rendering code, but the entry-point navigation mechanism and session-to-completion wiring are open Technical Design decisions (no tabbed nav shell exists today).
**Depends on**: `001-srs-tracking-service` (needs real due-items/due-count/vocab-linked-exercise contracts).

## Dependency Graph

```text
001-srs-tracking-service --> 002-practice-ui
```

## Notes

Coordinate with `007-amole-currency` (sequenced before this intent) so Practice-session completions trigger Amole awards consistently, without a second retrofit.
