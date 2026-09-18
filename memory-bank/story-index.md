# Global Story Index

## Overview
- **Total stories**: 46
- **Generated**: 46
- **Completed**: 42
- **Last updated**: 2026-09-18

---

## Stories by Intent

### 001-auth-onboarding

#### Unit: 001-auth-service

- [x] **001-persist-pending-onboarding-selections** (auth-service): Attach pending onboarding selections on first auth - Must - ✅ COMPLETED
- [x] **002-google-oauth-authentication** (auth-service): Sign up / log in with Google - Must - ✅ COMPLETED
- [x] **003-apple-sign-in-authentication** (auth-service): Sign in with Apple - Must - ✅ COMPLETED

#### Unit: 002-auth-onboarding-ui

- [x] **001-splash-and-onboarding-carousel** (auth-onboarding-ui): Splash screen + skippable onboarding carousel - Must - ✅ COMPLETED
- [x] **002-language-and-daily-goal-selection-screens** (auth-onboarding-ui): Language + daily-goal selection UI - Must - ✅ COMPLETED
- [x] **003-sign-in-screen-google-apple-equal-prominence** (auth-onboarding-ui): Sign-in screen with equal-prominence Google/Apple buttons - Must - ✅ COMPLETED
- [x] **004-oauth-failure-inline-retry** (auth-onboarding-ui): Inline OAuth failure + retry handling - Must - ✅ COMPLETED
- [x] **005-real-backend-integration-and-native-sdks** (auth-onboarding-ui): Real backend integration + native SDKs - Must - ✅ COMPLETED (bolt 003-auth-onboarding-ui)

### 002-core-lesson-loop

#### Unit: 001-lesson-service

- [x] **001-serve-skill-tree-and-lesson-content** (lesson-service): Serve skill tree + lesson content - Must - ✅ COMPLETED (bolt 004-lesson-content-service)
- [x] **002-answer-exercises-and-manage-beans** (lesson-service): Validate answers + manage Beans lifecycle - Must - ✅ COMPLETED (bolt 005-lesson-engagement-service)
- [x] **003-complete-lesson-award-xp-and-progress** (lesson-service): Complete lesson, award XP, update skill progress - Must - ✅ COMPLETED (bolt 005-lesson-engagement-service)
- [x] **004-daily-streak-and-freeze** (lesson-service): Daily streak + freeze protection - Should - ✅ COMPLETED (bolt 005-lesson-engagement-service)
- [x] **005-seed-curriculum-content** (lesson-service): Seed a small real Amharic curriculum - Must - ✅ COMPLETED (bolt 004-lesson-content-service)

#### Unit: 002-core-lesson-loop-ui

- [x] **001-skill-tree-dashboard-screen** (core-lesson-loop-ui): Skill-tree home dashboard - Must - ✅ COMPLETED (bolt 006-core-lesson-loop-ui)
- [x] **002-lesson-exercise-screens** (core-lesson-loop-ui): Lesson exercise screens (3 types) - Must - ✅ COMPLETED (bolt 006-core-lesson-loop-ui)
- [x] **003-out-of-beans-and-refill-modal** (core-lesson-loop-ui): Out-of-beans interruption + refill - Must - ✅ COMPLETED (bolt 006-core-lesson-loop-ui)
- [x] **004-lesson-complete-streak-and-levelup-modals** (core-lesson-loop-ui): Lesson-complete summary + streak/level-up - Should - ✅ COMPLETED (bolt 006-core-lesson-loop-ui)
- [x] **005-real-backend-integration** (core-lesson-loop-ui): Real backend integration - Must - ✅ COMPLETED (bolt 007-core-lesson-loop-ui)

### 003-offline-caching-and-sync

#### Unit: 001-offline-sync-service

- [x] **001-content-version-signal** (offline-sync-service): Expose a content-version signal for staleness checks - Must - ✅ COMPLETED (bolt 008-offline-sync-service)
- [x] **002-timestamped-completion-for-streak-attribution** (offline-sync-service): Accept a client-supplied completion timestamp for streak/XP-day attribution - Must - ✅ COMPLETED (bolt 008-offline-sync-service)
- [x] **003-idempotent-offline-replay** (offline-sync-service): Re-verify/extend idempotent replay of delayed completions - Must - ✅ COMPLETED (bolt 008-offline-sync-service)

#### Unit: 002-offline-caching-and-sync-ui

- [x] **001-download-lesson-packs** (offline-caching-and-sync-ui): Download and cache lesson packs (content + audio) - Must - ✅ COMPLETED (bolt 009-offline-caching-and-sync-ui)
- [x] **002-offline-lesson-taking** (offline-caching-and-sync-ui): Take a downloaded lesson with zero connectivity - Must - ✅ COMPLETED (bolt 009-offline-caching-and-sync-ui)
- [x] **003-pending-sync-queue-and-auto-sync** (offline-caching-and-sync-ui): Queue and auto-sync offline completions on reconnect - Must - ✅ COMPLETED (bolt 010-offline-caching-and-sync-ui)
- [x] **004-connectivity-and-sync-status-indicator** (offline-caching-and-sync-ui): Connectivity/sync status indicator - Should - ✅ COMPLETED (bolt 010-offline-caching-and-sync-ui)
- [x] **005-download-management-screen** (offline-caching-and-sync-ui): Manage downloaded packs (list/size/delete) - Could - ✅ COMPLETED (bolt 010-offline-caching-and-sync-ui)

### 004-match-pairs-exercise-type

#### Unit: 001-match-pairs-service

- [x] **001-serve-match-pairs-exercise-content** (match-pairs-service): Serve match-pairs exercise content (incl. seed data) - Must - ✅ COMPLETED (bolt 011-match-pairs-service)
- ~~**002-grade-match-pairs-attempts**~~ (match-pairs-service): **RETIRED** 2026-09-17 — reassigned to match-pairs-ui per ADR-5 (client-side grading), no replacement story needed

#### Unit: 002-match-pairs-ui

- [x] **001-match-pairs-exercise-screen** (match-pairs-ui): Take a match-pairs exercise via tap-tile-pairs (now also covers FR-2 grading) - Must - ✅ COMPLETED (bolt 012-match-pairs-ui)
- [x] **002-offline-match-pairs-verification** (match-pairs-ui): Match-pairs exercises work fully offline - Must - ✅ COMPLETED (bolt 012-match-pairs-ui)

### 005-profile-and-settings

#### Unit: 001-user-preferences-service

- [x] **001-update-daily-goal-and-language** (user-preferences-service): Change daily goal and language preference after account creation - Must - ✅ COMPLETED (bolt 013-user-preferences-service)
- [x] **002-store-notification-preference** (user-preferences-service): Persist a notification on/off preference - Must - ✅ COMPLETED (bolt 013-user-preferences-service)

#### Unit: 002-profile-and-settings-ui

- [x] **001-settings-screen** (profile-and-settings-ui): View and edit language/daily-goal/notification/sound from one screen - Must - ✅ COMPLETED (bolt 014-profile-and-settings-ui)
- [x] **002-logout** (profile-and-settings-ui): Log out from Settings - Must - ✅ COMPLETED (bolt 014-profile-and-settings-ui)

### 006-speak-check-exercise-type

#### Unit: 001-speak-check-service

- [x] **001-serve-speak-check-exercise-content** (speak-check-service): Serve speak-check exercise content (target phrase + translation) - Must - ✅ GENERATED
- [x] **002-grade-speak-check-attempt** (speak-check-service): Grade a recorded attempt via Google Cloud Speech-to-Text - Must - ✅ GENERATED — 🚫 BLOCKED (GCP not yet provisioned)

#### Unit: 002-speak-check-ui

- [x] **001-speak-check-exercise-screen** (speak-check-ui): Record, submit, and see pass/fail feedback - Must - ✅ GENERATED
- [x] **002-exclude-speak-check-from-offline-packs** (speak-check-ui): Exclude speak-check from offline downloadable packs - Must - ✅ GENERATED

### 007-amole-currency

#### Unit: 001-amole-service

- [x] **001-ledger-backed-amole-balance** (amole-service): Retrofit spend/balance onto a new amole_transactions ledger - Must - ✅ COMPLETED (bolt 017-amole-service)
- [x] **002-award-amole-on-completion** (amole-service): Award Amole on lesson completion, perfect lesson, streak milestones - Must - ✅ COMPLETED (bolt 017-amole-service)

#### Unit: 002-amole-ui

- [x] **001-amole-balance-on-dashboard** (amole-ui): Show Amole balance on the home dashboard - Must - ✅ COMPLETED (bolt 018-amole-ui)

### 008-srs-and-practice

#### Unit: 001-srs-tracking-service

- [x] **001-vocab-item-content-model** (srs-tracking-service): New vocab_items content model + exercises FK - Must - ✅ COMPLETED (bolt 019-srs-tracking-service)
- [x] **002-vocab-progress-retrofit** (srs-tracking-service): Track per-user vocab progress from complete_lesson - Must - ✅ COMPLETED (bolt 019-srs-tracking-service)
- [x] **003-leitner-box-algorithm** (srs-tracking-service): 5-box spaced-repetition transition math - Must - ✅ COMPLETED (bolt 019-srs-tracking-service)
- [x] **004-due-items-and-count-endpoints** (srs-tracking-service): Due-items + due-count endpoints - Must - ✅ COMPLETED (bolt 019-srs-tracking-service)

#### Unit: 002-practice-ui

- [x] **001-practice-entry-point-and-due-count** (practice-ui): Due-count entry point, disabled (not hidden) offline - Must - ✅ COMPLETED (bolt 020-practice-ui)
- [x] **002-practice-session-assembly-and-completion** (practice-ui): Assemble + complete a practice session via existing exercise widgets - Must - ✅ COMPLETED (bolt 020-practice-ui)

---

## Stories by Status

- **Planned**: 0
- **Generated**: 4
- **In Progress**: 0
- **Completed**: 42
- **Retired**: 1
