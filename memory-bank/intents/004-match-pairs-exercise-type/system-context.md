---
intent: 004-match-pairs-exercise-type
phase: inception
status: context-defined
updated: '2026-09-17T04:20:00Z'
---

# Match-Pairs Exercise Type - System Context

## System Overview

Extends the existing lesson engine (backend `001-lesson-service` + Flutter `002-core-lesson-loop-ui`) with a 4th exercise type. No new actors or external systems — this intent operates entirely within the system boundary already established by `002-core-lesson-loop` and `003-offline-caching-and-sync`.

## Context Diagram

```mermaid
C4Context
    title System Context - 004-match-pairs-exercise-type

    Person(learner, "Learner", "Buna app user taking a lesson")
    System(client, "Buna Flutter Client", "Renders exercises, grades locally where applicable, calls backend")
    System(backend, "Lesson Service (FastAPI)", "Serves lesson content, validates completions, awards Beans/XP")
    SystemDb(db, "PostgreSQL", "Stores curriculum content incl. match_pairs exercises")

    Rel(learner, client, "Taps tiles to match pairs")
    Rel(client, backend, "Fetches lesson content, submits completions", "REST/HTTPS")
    Rel(backend, db, "Reads/writes exercise content and attempts")
```

## External Integrations

None new. Reuses the existing backend REST API and PostgreSQL store.

## High-Level Constraints

- Must slot into the existing `ExerciseType` dispatch pattern on both backend and client — no parallel exercise-rendering pipeline.
- Must remain compatible with `003-offline-caching-and-sync`'s download/offline-take path with zero changes to that unit's code (text-only content requires no new download logic).

## Key NFR Goals

- Zero added network round-trips per tap (grading interaction is client-side/local, matching the other 3 exercise types).
- No regression to existing exercise types' behavior or response shape.
