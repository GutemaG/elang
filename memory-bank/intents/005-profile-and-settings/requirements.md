---
intent: 005-profile-and-settings
phase: inception
status: draft
created: '2026-09-17T04:00:00Z'
updated: '2026-09-17T04:00:00Z'
---

# Requirements: Profile & Settings Screen

## Intent Overview

Add the Profile & Settings screen that was explicit in the original product scope (a student-only app where users "update their settings") but was never built across any completed intent. Confirmed gap: `lib/features/` currently contains only `auth/` and `lesson/` — no profile/settings feature exists.

## Scope (draft)

### In Scope
- Language preference (change target/UI language, if multi-language is supported — needs confirmation)
- Daily goal (change the value selected during onboarding, `002-language-and-daily-goal-selection-screens`)
- Notification toggle
- Sound toggle
- Logout
- Likely also: basic profile display (name/email/avatar from the existing auth session)

### Out of Scope
- Account deletion / data export (unless user wants it added here)
- Payment/subscription management (no evidence this exists in the app yet)
- Anything covered by `004-match-pairs-exercise-type` or `006-speak-check-exercise-type`

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Does daily-goal change need to re-run any backend validation, or is it a pure client-side preference update via an existing endpoint? | User/Construction | Before Technical Design | Pending |
| Is there a profile-picture/display-name concept at all yet, or is this settings-only for v1? | User | Before requirements finalized | Pending |
| Where is notification-toggle state actually enforced (nothing push-related exists yet per `004-connectivity-and-sync-status-indicator`'s Out of Scope) — is this just a stored preference with no wired notification system yet? | User | Before requirements finalized | Pending |
