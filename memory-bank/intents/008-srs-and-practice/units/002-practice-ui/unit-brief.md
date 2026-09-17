---
unit: 002-practice-ui
intent: 008-srs-and-practice
phase: inception
status: ready
created: '2026-09-17T16:55:00Z'
updated: '2026-09-17T16:55:00Z'
---

# Unit Brief: Practice UI

## Purpose

A new entry point showing the due-review count, launching a Practice session assembled from due vocab items' linked exercises, reusing the existing exercise-engine widgets end to end.

## Scope

### In Scope
- Due-count badge/indicator
- Practice entry point (exact placement — tab vs. dashboard element — a Plan-stage decision, since no tabbed nav shell exists in `main.dart` today)
- Session assembly: fetch due items, resolve their linked exercises, hand them to the existing exercise-engine widgets unmodified
- Session completion wired through the existing grading/XP path where applicable, consistent with any Amole triggers from intent `007` if it has landed
- Offline: entry point visibly disabled (not hidden) when offline

### Out of Scope
- Any new exercise-rendering widget
- Any change to the regular lesson-taking flow

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-6 | Practice Tab / Entry Point | Must |

---

## Domain Concepts

No new domain concepts on the client — reuses `Exercise`/exercise-type widgets already modeled from `002-core-lesson-loop-ui`/`012-match-pairs-ui`. New client-side model: a due-count value and a due-items response shape (mirrors the real backend contract from `001-srs-tracking-service` — do not guess its shape at Construction, read the real endpoint).

## Technical Context

### Suggested Technology
Flutter. Read `main.dart`'s and `SkillTreeDashboardScreen`'s real current navigation structure at Plan stage before deciding tab-bar vs. dashboard-element placement — no assumption is made here.

### External Dependencies
None.

---

## Constraints

- Depends on `001-srs-tracking-service`'s real endpoint contracts (due-items, due-count, and whatever practice-completion endpoint shape it defines at its own Technical Design stage) — do not guess these at Construction.
- Zero regression to the regular lesson-taking flow or existing dashboard tests.

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 020-practice-ui | simple-construction-bolt | 001, 002 | Practice entry point + session assembly/completion |

---

## Notes

Entry-point placement is deliberately left open here — forcing a "tab" when no tabbed shell exists would mean this unit-brief silently deciding a UI-structure change that belongs at Plan stage, after reading real navigation code.
