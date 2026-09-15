---
unit: 002-auth-onboarding-ui
intent: 001-auth-onboarding
phase: inception
status: ready
created: 2026-09-15T12:35:35Z
updated: 2026-09-15T12:35:35Z
unit_type: frontend
default_bolt_type: simple-construction-bolt
---

# Unit Brief: Auth & Onboarding UI

## Purpose

Flutter screens for the entire pre-lesson-loop flow: splash, onboarding carousel, language + daily-goal selection, and the Google/Apple sign-in screen, including inline OAuth failure/retry handling. Visual designs already exist (Stitch "Highland Pulse" design system, exported to `stitch-screens/extracted/stitch_ethiopian_language_learning_app/`) — this unit implements those designs in Flutter and wires them to `001-auth-service`.

## Scope

### In Scope
- Splash screen with session check (skip onboarding if a valid session exists)
- Onboarding carousel (skippable)
- Language selection screen (Amharic only in Phase 1, UI doesn't hardcode single-course assumption)
- Daily goal selection screen (4 presets: Casual/Regular/Serious/Intense, by minutes/day)
- Local pre-auth state holder that survives app backgrounding/kill during the OAuth browser handoff
- Sign-in screen with Google + Apple buttons at equal visual prominence
- Inline error + retry UI for OAuth failure/denial

### Out of Scope
- Token verification logic (owned by `001-auth-service`)
- Anything past the sign-in screen (home/skill tree is a different, future intent)
- Settings screen changes to daily goal after onboarding (Account intent, future)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Onboarding Carousel | Must |
| FR-5 | OAuth Failure/Denial Handling | Must |

*(This unit also implements the UI for FR-2/FR-3/FR-4, owned by `001-auth-service` — see `units.md` mapping note.)*

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| PendingOnboardingSelection | Local, pre-auth client state | selectedLanguage, dailyGoalMinutes |
| SessionState | Local record of whether a valid session exists | sessionToken (secure storage), isValid |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| CheckExistingSession | On splash, check secure storage for a valid session token | None | Route to home (skip onboarding) or to carousel |
| PersistPendingSelectionLocally | Hold language/goal choices in secure local state until auth completes | User selections | Local state surviving app kill/background |
| InitiateGoogleSignIn / InitiateAppleSignIn | Trigger native OAuth SDK flow, call `001-auth-service` on success | Pending selections (if any) | Session token or error |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 5 |
| Must Have | 5 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-splash-and-onboarding-carousel | Splash screen + skippable onboarding carousel | Must | ✅ Complete |
| 002-language-and-daily-goal-selection-screens | Language + daily-goal selection UI | Must | ✅ Complete |
| 003-sign-in-screen-google-apple-equal-prominence | Sign-in screen with equal-prominence Google/Apple buttons | Must | ✅ Complete |
| 004-oauth-failure-inline-retry | Inline OAuth failure + retry handling | Must | ✅ Complete |
| 005-real-backend-integration-and-native-sdks | Real backend integration + native SDKs | Must | Planned (bolt 003-auth-onboarding-ui) |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| 001-auth-service | Needs the auth API contract (from its Technical Design stage) to integrate sign-in; needs the implemented endpoints for full end-to-end testing |

### Depended By
| Unit | Reason |
|------|--------|
| None | Terminal unit for this intent |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| Google Sign-In SDK (Flutter) | Native OAuth flow trigger | Low — well-documented plugin |
| Sign in with Apple SDK (Flutter) | Native OAuth flow trigger | Low — well-documented plugin |

---

## Technical Context

### Suggested Technology
Flutter/Dart per `memory-bank/standards/tech-stack.md`. Secure local storage for session token and pending onboarding selections (Keychain/Keystore via `flutter_secure_storage` or equivalent). Feature-based file organization per `coding-standards.md` (`lib/features/auth/`).

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| 001-auth-service | API | REST over HTTPS |
| Google Sign-In SDK | Native plugin | Platform channel |
| Apple Sign-In SDK | Native plugin | Platform channel |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| Session token, pending onboarding selection | Secure local device storage | Single record per device | Until logout / selection consumed |

---

## Constraints

- Apple sign-in button must have equal visual prominence to Google's, not secondary styling (App Store policy, already reflected in the Stitch designs).
- No hardcoded single-course assumption in the language-selection UI (Afaan Oromo lands Phase 2).
- Must match the existing Stitch "Highland Pulse" design system exports for visual consistency.

---

## Success Criteria

### Functional
- [ ] Returning user (valid session) skips splash/carousel/onboarding entirely
- [ ] New user completes carousel → language/goal selection → sign-in without losing selections on a failed auth attempt
- [ ] Google and Apple buttons render with equal size/weight on the sign-in screen

### Non-Functional
- [ ] Pending onboarding selections survive app kill/background during OAuth handoff
- [ ] No tokens or OAuth payloads logged client-side

### Quality
- [ ] Widget tests for each screen
- [ ] All acceptance criteria met
- [ ] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 002-auth-onboarding-ui | Simple | 001, 002, 003, 004 | Full pre-auth screen flow in one bolt, matching existing Stitch designs |

---

## Notes

Reference the exported Stitch screens directly during implementation: `stitch-screens/extracted/stitch_ethiopian_language_learning_app/` contains `code.html` + `screen.png` for splash, onboarding carousel, language selection, daily goal selection, and create-account/sign-in — use these as the visual source of truth rather than re-deriving styles from `coding-standards.md` alone.
