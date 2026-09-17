---
intent: 005-profile-and-settings
phase: inception
status: context-defined
updated: '2026-09-17T07:45:00Z'
---

# Profile & Settings - System Context

## System Overview

Extends the existing auth bounded context (`001-auth-service`) with one new capability — updating a user's preferences after account creation — plus a new Flutter Settings screen. No new actors or external systems.

## Context Diagram

```mermaid
C4Context
    title System Context - 005-profile-and-settings

    Person(learner, "Learner", "Buna app user")
    System(client, "Buna Flutter Client", "Settings screen: view/edit preferences, sound toggle, logout")
    System(backend, "Auth Service (FastAPI)", "Amended: accepts preference updates, deliberately relaxes the prior write-once invariant")
    SystemDb(db, "PostgreSQL", "users table")

    Rel(learner, client, "Views/edits settings, logs out")
    Rel(client, backend, "GET/PATCH preferences", "REST/HTTPS, session-token auth")
    Rel(backend, db, "Reads/writes selected_language, daily_xp_target, notification_enabled")
```

## External Integrations

None new.

## High-Level Constraints

- Amends `001-auth-service` rather than creating a new bounded context — same pattern `001-offline-sync-service` used amending `001-lesson-service`.
- The prior "written exactly once at creation" invariant on `selected_language`/`daily_xp_target` must be formally amended (documented, likely ADR-worthy), not silently bypassed.

## Key NFR Goals

- Same session-token auth as every other endpoint — no new auth mechanism.
- No name/email/avatar data introduced — the domain model's actual shape is respected, not expanded speculatively.
