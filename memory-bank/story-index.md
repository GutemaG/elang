# Global Story Index

## Overview
- **Total stories**: 26
- **Generated**: 26
- **Completed**: 26
- **Last updated**: 2026-09-17

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

---

## Stories by Status

- **Planned**: 0
- **Generated**: 0
- **In Progress**: 0
- **Completed**: 26
