---
intent: 001-auth-onboarding
phase: inception
status: inception-complete
created: 2026-09-15T10:48:32Z
updated: 2026-09-15T12:46:24Z
---

# Requirements: Auth & Onboarding

## Intent Overview

Let a new Buna user move through onboarding and sign in before reaching the core lesson loop. This is the foundation intent for Phase 1 — every other feature (lesson loop, gamification, SRS) assumes an authenticated, onboarded user exists. Covers the "Auth/onboarding" screen group from the MVP spec: splash, onboarding carousel, language + goal selection, sign up/login (Google OAuth + Sign in with Apple).

**Resolved flow order**: onboarding (carousel + language/goal selection) happens **before** account creation — the user sees the carousel and picks a language/goal as an anonymous visitor, then authenticates, and those pending selections attach to the new account on first successful sign-in.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| User can create an account and return to it later | Signup → logout → login round-trip succeeds, same progress state | Must |
| User completes onboarding before first lesson | 100% of new users pass through carousel + language/goal selection prior to skill tree | Must |
| App Store compliance on sign-in options | Sign in with Apple offered with equal prominence to Google OAuth | Must |
| Returning users aren't re-onboarded | User with a valid session skips splash/carousel/onboarding, lands directly on home/skill tree | Should |

---

## Functional Requirements

### FR-1: Onboarding Carousel
- **Description**: First-time users (no valid session on device) see a splash screen then an onboarding carousel introducing Buna, before any account exists.
- **Acceptance Criteria**:
  - Carousel is shown only when no valid session token exists on the device.
  - User can advance through carousel screens and reach language/goal selection without signing in first.
  - A returning user (valid session token present) skips splash/carousel/onboarding entirely and lands on home/skill tree.
- **Priority**: Must
- **Related Stories**: TBD

### FR-2: Language + Daily Goal Selection (Pre-Auth)
- **Description**: During onboarding, the user selects a target language (Amharic — the only course in Phase 1) and one of 4 daily-goal presets by minutes/day: Casual (5 min), Regular (10 min), Serious (15 min), Intense (20 min) — before creating an account.
- **Acceptance Criteria**:
  - Selections are held in local device state (surviving app backgrounding/kill) until sign-in completes — see FR-5.
  - The minutes/day preset maps to a stored daily XP target server-side once the account is created (exact minutes→XP mapping formula is a technical-design decision, not fixed here).
  - Selection screens don't hardcode a second course — Amharic is the only option shown, but the UI/data model doesn't assume there will only ever be one.
- **Priority**: Must
- **Related Stories**: TBD

### FR-3: Google OAuth Sign-Up/Sign-In
- **Description**: After onboarding selections are made, the user authenticates via Google OAuth to create or access their account. Pending onboarding selections persist to the account on first successful auth.
- **Acceptance Criteria**:
  - A new Google account creates a `users` row with the pending language + daily goal attached.
  - An existing Google account (returning user) logs in normally — pending onboarding selections from this session are discarded in favor of the account's existing state (no overwriting a returning user's real progress/goal).
  - Session persists across app restarts — no re-auth required every launch.
- **Priority**: Must
- **Related Stories**: TBD

### FR-4: Sign in with Apple
- **Description**: Same account-creation/merge behavior as FR-3, via Sign in with Apple, offered with equal prominence to Google OAuth (App Store requirement whenever a third-party login is offered).
- **Acceptance Criteria**:
  - Functionally identical to FR-3's account-creation/merge behavior, using Apple's identity token.
  - Account dedup uses Apple's stable user identifier, not email (Apple's private-relay email must not break account uniqueness or create duplicate accounts on re-login).
- **Priority**: Must
- **Related Stories**: TBD

### FR-5: OAuth Failure/Denial Handling
- **Description**: If the OAuth flow fails (network error, user cancels, permission denied), the user sees an inline error on the sign-in screen with a retry action — no separate error screen for Phase 1.
- **Acceptance Criteria**:
  - Failure never crashes the app and never loses the pending onboarding selections (language/goal chosen pre-auth must survive a failed auth attempt, so the user isn't forced to redo onboarding).
  - Retry re-triggers the same provider's OAuth flow the user attempted.
- **Priority**: Must
- **Related Stories**: TBD

---

## Non-Functional Requirements

### Security
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Authentication | OAuth 2.0 (Google) / Sign in with Apple | No password storage anywhere in Phase 1 |
| Token storage | Platform secure storage | Session tokens in Keychain (iOS) / Keystore (Android), not plain prefs |
| Logging | Never log tokens or OAuth payloads | Per `memory-bank/standards/coding-standards.md` logging rules |

### Reliability
| Requirement | Metric | Target |
|-------------|--------|--------|
| Pending onboarding state durability | Selections survive app kill/background during the OAuth browser handoff | 100% — no re-onboarding after a completed OAuth round-trip |

### Compliance
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Apple App Store Review Guideline 4.8 | Sign in with Apple required alongside third-party login | Must have equal visual prominence to Google OAuth, not buried as a secondary option |

---

## Constraints

### Technical Constraints

**Project-wide standards**: Loaded from `memory-bank/standards/` by Construction Agent (tech-stack.md, data-stack.md, coding-standards.md).

**Intent-specific constraints**:
- OAuth-only auth in Phase 1 — no email/password flow.
- No teacher/admin/content-manager role — every authenticated user is a student.
- Onboarding selections must exist in a pre-auth (anonymous) client state that gets attached to the account atomically on first successful sign-in — this is a real technical constraint on the client architecture, not just a UX choice.

### Business Constraints
- Phase 1 ships English → Amharic only; language selection UI should not hardcode a single-course assumption that blocks adding Afaan Oromo in Phase 2.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| `users` table schema (per `database-schema.md`) has fields for daily-goal target and selected course/language matching this flow | Rework of onboarding data model | Confirm against `database-schema.md` during Context/Units step |
| Minutes/day presets map cleanly to an XP-per-day target used elsewhere in gamification | Mapping formula becomes a cross-intent dependency with the gamification engine intent | Flag as a shared decision between this intent and the (future) gamification-engine intent |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Does onboarding happen before or after account creation? | Product | Requirements step | ✅ Resolved — onboarding first, then sign-in |
| What are the daily-goal presets? | Product | Requirements step | ✅ Resolved — 4 tiers by minutes/day (5/10/15/20) |
| OAuth failure/denial handling? | Product | Requirements step | ✅ Resolved — inline error + retry, no dedicated screen |
| Exact minutes→daily-XP-target formula | Product/Eng | Technical design (Construction) | Pending — defer to technical-design stage, shared with gamification-engine intent |
