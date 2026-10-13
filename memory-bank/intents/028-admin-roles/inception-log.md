---
intent: 028-admin-roles
created: 2026-10-13T09:00:00Z
status: complete
---

# Inception Log: 028-admin-roles

## Overview

**Intent**: Replace the all-or-nothing `ADMIN_EMAILS` admin with super
admins and course admins, managed on a Team page. `ADMIN_EMAILS` stays
as the owners, who are always super admins. Course admins work only on
the courses a super admin gives them.
**Type**: brown-field
**Created**: 2026-10-13T09:00:00Z

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | requirements.md, Current state |
| Units | ✅ | units.md, units/*/unit-brief.md |
| Stories | ✅ | in each unit brief (001–018) |
| Bolt Plan | ✅ | memory-bank/bolts/100–114 |

## Decisions

| Date | Decision | Why |
|------|----------|-----|
| 2026-10-13 | Course admins publish lessons in their courses | Owner's answer |
| 2026-10-13 | Learners, dashboard and feedback are super admin only | Learner data is personal |
| 2026-10-13 | Course admins edit and record Sounds for their courses' learning languages | Owner's answer |
| 2026-10-13 | `ADMIN_EMAILS` kept as owners; more super admins added on the Team page | No lockout; owner's answer |
| 2026-10-13 | Another course's id is 404 for a course admin | Doesn't reveal other courses |
