---
intent: 005-profile-and-settings
phase: inception
status: complete
created: '2026-09-17T04:00:00Z'
updated: '2026-09-17T07:45:00Z'
---

# Requirements: Profile & Settings Screen

## Intent Overview

Add the Profile & Settings screen that was explicit in the original product scope (a student-only app where users "update their settings") but was never built across any completed intent. Confirmed gap: `lib/features/` currently contains only `auth/` and `lesson/` — no profile/settings feature exists.

Verified against the actual backend before drafting these requirements: `User` (`backend/app/domain/entities.py`) has no name/email/avatar field at all — only an opaque `provider_identity`, `selected_language`, `daily_xp_target`. Those last two are explicitly documented as "written exactly once, at creation, never overwritten by a later authentication," and no endpoint exists to change them post-creation. Editing them from Settings is therefore a real backend change (new endpoint + a deliberate, documented amendment of that invariant), not a pure client-side update — confirmed in scope for this intent (Checkpoint 1).

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Deliver the "update their settings" requirement from the original product scope, closing a hard gap | Language, daily goal, notification toggle, sound toggle, and logout are all real and functional | Must |
| Amend the auth-service's write-once invariant deliberately and safely | New endpoint ships with the invariant's amendment documented (its own ADR if warranted), zero regression to `001-auth-service`'s existing test suite | Must |

---

## Functional Requirements

### FR-1: View Current Settings
- **Description**: The Settings screen displays the user's current language, current daily goal, notification-toggle state, sound-toggle state, and which provider they're signed in with (derived from `provider_identity` — e.g. "Signed in with Google"). No name/email/avatar section — the domain model has no such data (Checkpoint 1 decision).
- **Acceptance Criteria**:
  - All 4 settings values are visible and match the account's actual current state on screen load
  - "Signed in with {Google|Apple}" is shown, derived from the existing session/provider data, not a new field
- **Priority**: Must

### FR-2: Edit Daily Goal
- **Description**: The user can change their daily XP goal from Settings. Requires a new backend endpoint and a deliberate amendment to `User`'s "written exactly once" invariant (Checkpoint 1 decision) — the invariant becomes "written at creation, then only ever changed through this one explicit endpoint," not silently relaxed everywhere.
- **Acceptance Criteria**:
  - Changing the daily goal in Settings persists it server-side and is reflected immediately on the skill-tree dashboard's daily-goal progress (existing `002-core-lesson-loop-ui` UI, unchanged otherwise)
  - The set of selectable goal values matches the existing onboarding daily-goal-selection screen's options (`002-language-and-daily-goal-selection-screens`) — no new goal values invented here
- **Priority**: Must

### FR-3: Edit Language Preference
- **Description**: The user can change their selected language from Settings, through the same new endpoint/invariant-amendment as FR-2.
- **Acceptance Criteria**:
  - Changing the language in Settings persists it server-side
  - The set of selectable languages matches the existing onboarding language-selection screen's options (`002-language-and-daily-goal-selection-screens`)
- **Priority**: Must
- **Open question carried into Technical Design**: does changing language require anything else to happen (e.g. is curriculum content keyed by language yet, per `mvp_phase: "Phase 1 — English to Amharic course only"` in `project.yaml`)? Flagging now rather than assuming — Phase 1 is English→Amharic only, so a language change may currently have no other observable effect, which is fine to ship as-is but should be an explicit, documented Technical Design note, not a silent gap.

### FR-4: Notification Toggle (Stored, Not Yet Wired)
- **Description**: The user can toggle notifications on/off. Persisted as a real value (Checkpoint 1 decision: store now, wire later) — stored server-side alongside FR-2/FR-3's new preference endpoint, since a future real notification system will need the server to know this preference to decide whether to send. Gates nothing yet; no notification system exists anywhere in this codebase (confirmed by search).
- **Acceptance Criteria**:
  - The toggle's value persists across app restarts and sessions (survives via the backend, like FR-2/FR-3)
  - No notification is ever sent as a result of this toggle in either state — there is nothing to send yet
- **Priority**: Must (explicit in original scope, even though functionally inert for now)

### FR-5: Sound Toggle (Client-Local, Fully Functional)
- **Description**: The user can toggle sound feedback on/off. Unlike FR-4, this is immediately functional: `lib/shared/services/answer_feedback_player.dart` already exists and plays real audio cues on grading — this toggle gates it directly. Stored client-locally (no reasonable reason for the server to know about local audio preference, and it needs no cross-device sync).
- **Acceptance Criteria**:
  - Turning sound off silences `AnswerFeedbackPlayer`'s correct/incorrect cues during lesson-taking; turning it back on restores them
  - The toggle's value persists across app restarts (local storage)
- **Priority**: Must

### FR-6: Logout
- **Description**: The user can log out from Settings. Reuses the existing `SessionRepository.clearSession()` (`lib/shared/services/session_repository.dart`) — no new session-management code.
- **Acceptance Criteria**:
  - Logging out clears the local session and returns the user to the sign-in screen
  - A logged-out user cannot navigate back into any authenticated screen without signing in again
- **Priority**: Must

---

## Non-Functional Requirements

### Security
| Requirement | Standard | Notes |
|-------------|----------|-------|
| The new settings-update endpoint | Same session-token auth as every other `001-lesson-service`/`001-auth-service` endpoint | No new auth mechanism |

No other new NFRs — reuses existing performance/reliability standards.

---

## Constraints

### Technical Constraints

**Project-wide standards**: Required standards will be loaded from memory-bank standards folder by Construction Agent.

**Intent-specific constraints**:
- `User.selected_language`/`daily_xp_target`'s "written exactly once" invariant must be *amended*, not silently ignored — the new endpoint becomes the one documented, deliberate exception
- No new `User` fields for name/email/avatar — out of scope per Checkpoint 1
- Notification toggle must not require or assume any notification-delivery system — it's a stored preference only

### Business Constraints
- None identified beyond normal project pacing

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| A language change has no other observable effect in Phase 1 (English→Amharic only course) | If curriculum ever becomes multi-language-keyed, this settings screen would need to also trigger a content re-fetch/re-seed check | Flagged explicitly in FR-3; revisit when a 2nd course/language is added |
| Notification toggle can ship "inert but real" without confusing users | Users might expect it to do something immediately | Copy/UX should avoid implying live notifications exist yet (a Technical Design/UI decision, not fixed here) |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Does daily-goal/language change need backend validation or is it pure client-side? | User | Checkpoint 1 | **Resolved**: real backend change, new endpoint, invariant amendment |
| Is there a profile-picture/display-name concept? | User | Checkpoint 1 | **Resolved**: no — settings-only, no profile identity beyond provider name |
| Where is notification-toggle state enforced? | User | Checkpoint 1 | **Resolved**: stored (server-side, alongside FR-2/FR-3), functionally inert until a real notification system exists |
| Should sound-toggle also be server-side, for consistency with notification/goal/language? | Construction (this session) | Requirements | **Resolved**: no — client-local, since it's a UI/local-audio preference with no cross-device need, and it can be fully functional immediately (unlike notifications) |
