---
intent: 010-multi-language-courses
created: '2026-09-20T12:00:00Z'
status: in-progress
completed: null
---

# Inception Log: multi-language-courses

## Overview

**Intent**: Course list with switching and saved selection; courses are (learning language, from-language) pairs so any-language speakers can learn any other language when material exists.
**Type**: New Feature / Enhancement (schema + API + UI + content)
**Created**: 2026-09-20

## Progress

| Artifact | Status |
|----------|--------|
| Requirements | Approved at Checkpoint 2 (2026-09-20) |
| System Context | Generated |
| Units (2) | Generated |
| Stories (10) | Generated |
| Bolt Plan (4) | Generated: 024, 025, 026, 027 |

Checkpoint 3 (artifacts review) approved 2026-09-20. Awaiting Checkpoint 4 (ready for Construction). No bolt started.

## Summary

- **Functional Requirements**: 10
- **Non-Functional Requirements**: 5
- **Units**: 2
- **Stories**: 10
- **Bolts Planned**: 4

## Next Steps

`/specsmd-construction-agent --unit="001-courses-service" --bolt-id="024-courses-service"`

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-20 | Course = (learning language, from-language) pair | User: Amharic speakers without English must be able to learn Afaan Oromo and vice versa | Yes |
| 2026-09-20 | Course list + switcher with saved selection, Duolingo-style | User request | Yes |
| 2026-09-20 | Progress separate per course; XP, streak, Beans, Amole account-wide | User's Checkpoint 1 choice | Yes |
| 2026-09-20 | Seed small Afaan Oromo starters: en to om, am to om, om to am | User's Checkpoint 1 choice | Yes |
| 2026-09-20 | Dashboard course chip + picker; onboarding asks "I speak" and "I want to learn"; Settings reuses the picker | User's Checkpoint 1 choice | Yes |
| 2026-09-20 | App interface stays English (localisation is a later intent) | User's Checkpoint 1 choice | Yes |
| 2026-09-20 | Split backend into two bolts (024 structural, 025 content seed) and UI into two (026 picker/onboarding, 027 offline/verification) | Content and offline risks reviewable independently | Yes |

## Scope Changes

None yet.
