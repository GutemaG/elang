# Global Story Index

## Overview
- **Total stories**: 99
- **Generated**: 99
- **Completed**: 88
- **Last updated**: 2026-09-25

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

### 009-course-categories

#### Unit: 001-categories-service

- [x] **001-category-content-model-and-migration** (categories-service): categories table + skills.category_id + data-preserving migration - Must - ✅ COMPLETED (bolt 021-categories-service)
- [x] **002-per-category-progression** (categories-service): Linear within a category, all categories open - Must - ✅ COMPLETED (bolt 021-categories-service)
- [x] **003-skill-tree-api-with-categories** (categories-service): Skill-tree API returns categories - Must - ✅ COMPLETED (bolt 021-categories-service)
- [x] **004-seed-four-new-categories** (categories-service): Seed Family, Numbers & Time, Travel, Colors/Body & Health - Must - ✅ COMPLETED (bolt 022-category-content-seed)

#### Unit: 002-categories-ui

- [x] **001-dashboard-grouped-by-category** (categories-ui): Banner + skill path per category - Must - ✅ COMPLETED (bolt 023-categories-ui)
- [x] **002-new-category-end-to-end-verification** (categories-ui): New-category lessons work fully - Must - ✅ COMPLETED (bolt 023-categories-ui)

### 010-multi-language-courses

#### Unit: 001-courses-service

- [x] **001-course-model-and-migration** (courses-service): courses table + categories.course_id + data-preserving migration - Must - ✅ COMPLETED (bolt 024-courses-service)
- [x] **002-active-course-per-user** (courses-service): Saved active course, signup with a language pair - Must - ✅ COMPLETED (bolt 024-courses-service)
- [x] **003-course-list-api** (courses-service): List all courses, mark active - Must - ✅ COMPLETED (bolt 024-courses-service)
- [x] **004-course-scoped-skill-tree-and-progress** (courses-service): Separate skills, crowns, unlocks per course - Must - ✅ COMPLETED (bolt 024-courses-service)
- [x] **005-course-scoped-practice** (courses-service): Practice only from the active course - Must - ✅ COMPLETED (bolt 024-courses-service)
- [x] **006-seed-afaan-oromo-starter-courses** (courses-service): Three Afaan Oromo/Amharic starter courses - Must - ✅ COMPLETED (bolt 025-course-content-seed)

#### Unit: 002-courses-ui

- [x] **001-course-switcher-and-settings-picker** (courses-ui): Dashboard chip, picker, Settings picker - Must - ✅ COMPLETE (bolt 026-course-picker-ui)
- [x] **002-onboarding-language-pair** (courses-ui): "I speak" and "I want to learn" in onboarding - Must - ✅ COMPLETE (bolt 026-course-picker-ui)
- [x] **003-offline-per-course** (courses-ui): Cache and packs keyed by course - Must - ✅ COMPLETE (bolt 027-course-offline-and-verification)
- [x] **004-multi-course-end-to-end-verification** (courses-ui): End-to-end and regression proof - Must - ✅ COMPLETE (bolt 027-course-offline-and-verification)

### 011-dashboard-ui-polish

#### Unit: 001-dashboard-shell-ui

- [x] **001-pinned-header-with-stats** (dashboard-shell-ui): Stats move into a pinned header - Must - ✅ COMPLETE (bolt 028-dashboard-shell)
- [x] **002-smooth-scroll-and-sticky-sections** (dashboard-shell-ui): One scroll surface, sticky category banners - Must - ✅ COMPLETE (bolt 028-dashboard-shell)
- [x] **003-course-rail-and-add-course** (dashboard-shell-ui): Header badge expands a course rail with + Course - Must - ✅ COMPLETE (bolt 029-course-switcher-panel)
- [x] **004-course-settings-and-downloads-access** (dashboard-shell-ui): Settings and downloads move into the course panel - Must - ✅ COMPLETE (bolt 029-course-switcher-panel)

### 015-gap-fill-exercise-type

#### Unit: 001-gap-fill-service

- [x] **001-serve-gap-fill-exercise-content** (gap-fill-service): Serve gap-fill exercise content (incl. seed data) - Must - ✅ COMPLETE (bolt 030-gap-fill-service)

#### Unit: 002-gap-fill-ui

- [x] **001-gap-fill-exercise-screen** (gap-fill-ui): Fill the gap by tapping a word - Must - ✅ COMPLETE (bolt 031-gap-fill-ui)
- [x] **002-offline-gap-fill-verification** (gap-fill-ui): Gap-fill works inside a downloaded pack - Must - ✅ COMPLETE (bolt 031-gap-fill-ui)

### 016-spell-from-tiles-exercise-type

#### Unit: 001-spell-tiles-service

- [x] **001-serve-spell-tiles-exercise-content** (spell-tiles-service): Serve spell-tiles exercise content (incl. seed data) - Must - ✅ COMPLETE (bolt 032-spell-tiles-service)

#### Unit: 002-spell-tiles-ui

- [x] **001-spell-tiles-exercise-screen** (spell-tiles-ui): Spell a word by tapping character tiles - Must - ✅ GENERATED
- [x] **002-offline-spell-tiles-verification** (spell-tiles-ui): Spell-tiles works inside a downloaded pack - Must - ✅ GENERATED

### 018-mobile-design-system

#### Unit: 001-design-foundation-ui

- [x] **001-design-tokens-shadows-and-motion** (design-foundation-ui): Every colour, shadow, radius and animation timing as a named token - Must - ✅ COMPLETED (bolt 042-design-foundation)
- [x] **002-bundled-fonts-with-ethiopic-fallback** (design-foundation-ui): The same typeface on my Android phone and my friend's iPhone, in English and Amharic - Must - ✅ COMPLETED (bolt 042-design-foundation)
- [x] **003-buttons** (design-foundation-ui): Every button in the app to look and press the same way for the same kind of action - Must - ✅ COMPLETED (bolt 042-design-foundation)
- [x] **004-gallery-and-rules-test** (design-foundation-ui): One screen that shows every token and component in every state, and a test that fails when a screen draws its own decoration - Must - ✅ COMPLETED (bolt 042-design-foundation)
- [x] **005-page-shell-and-backgrounds** (design-foundation-ui): Every screen to sit on the same warm background with the same margins, top bar and bottom action area - Must - ✅ COMPLETED (bolt 043-design-surfaces)
- [x] **006-cards-and-surfaces** (design-foundation-ui): Every card, row and banner to have the same border, corner and shadow - Must - ✅ COMPLETED (bolt 043-design-surfaces)
- [x] **007-sheets-and-dialogs** (design-foundation-ui): Every pop-up sheet and confirmation to look like part of the same family - Must - ✅ COMPLETED (bolt 043-design-surfaces)
- [x] **008-status-and-feedback-pieces** (design-foundation-ui): My streak, beans, gems, progress and any empty or error message to look the same wherever they appear - Must - ✅ COMPLETED (bolt 043-design-surfaces)

#### Unit: 002-question-kit-ui

- [x] **001-exercise-layout-and-question-prompt** (question-kit-ui): Every question to have the same top bar, prompt style and button position - Must - ✅ COMPLETED (bolt 044-question-kit)
- [x] **002-one-answer-tile-for-every-question-type** (question-kit-ui): Every answer tile, word chip and match card to look and react the same way - Must - ✅ COMPLETED (bolt 044-question-kit)
- [x] **003-audio-button-slot-line-and-action-bar** (question-kit-ui): The play button, the line my sentence builds on and the Check/Continue bar to look the same in every question - Must - ✅ COMPLETED (bolt 044-question-kit)
- [x] **004-lesson-screen-on-the-kit** (question-kit-ui): Every question in a lesson to share one layout and style - Must - ✅ COMPLETED (bolt 045-lesson-screen-on-kit)

#### Unit: 003-screen-migration-ui

- [x] **001-onboarding-and-sign-in-on-the-library** (screen-migration-ui): The first screens I see to look polished and consistent with each other - Must - ✅ GENERATED (bolt 046-onboarding-screens-on-kit)
- [x] **002-dashboard-and-course-picker-on-the-library** (screen-migration-ui): The home screen to look like the mockup, with the same cards, pills and sheets as the rest of the app - Must - ✅ GENERATED (bolt 047-dashboard-on-kit)
- [x] **003-lesson-complete-and-lesson-sheets-on-the-library** (screen-migration-ui): The end of a lesson and every lesson pop-up to look celebratory and consistent - Must - ✅ GENERATED (bolt 048-lesson-complete-and-sheets-on-kit)
- [x] **004-settings-and-downloads-on-the-library** (screen-migration-ui): Settings and downloads to look like the rest of the app instead of stock system screens - Must - ✅ GENERATED (bolt 049-settings-downloads-and-sweep)
- [x] **005-consistency-sweep** (screen-migration-ui): Every screen checked together against the same rules - Must - ✅ GENERATED (bolt 049-settings-downloads-and-sweep)

### 019-image-choice-exercise-types

#### Unit: 001-image-choice-service

- [x] **001-picture-question-content-types** (image-choice-service): Store and serve both picture question types - Must - ✅ COMPLETED (bolt 050-image-choice-service)
- [x] **002-picture-upload-links** (image-choice-service): Upload links and local storage for pictures - Must - ✅ COMPLETED (bolt 050-image-choice-service)
- [x] **003-sample-picture-questions** (image-choice-service): Sample questions with free-licensed, credited pictures - Must - ✅ COMPLETED (bolt 051-image-choice-samples)

#### Unit: 002-image-choice-admin

- [x] **001-picture-upload-with-shrinking** (image-choice-admin): Pick a picture and have it shrunk and uploaded - Must - ✅ COMPLETED (bolt 052-image-choice-admin)
- [x] **002-picture-question-editors-and-preview** (image-choice-admin): Build, check and preview both picture question types - Must - ✅ COMPLETED (bolt 052-image-choice-admin)

#### Unit: 003-image-choice-ui

- [x] **001-picture-tile-in-the-kit** (image-choice-ui): A picture answer tile that looks and reacts like every other tile - Must - ✅ COMPLETED (bolt 053-picture-tile-and-lesson)
- [x] **002-picture-questions-in-lessons-and-practice** (image-choice-ui): Both picture questions in lessons and practice - Must - ✅ COMPLETED (bolt 053-picture-tile-and-lesson)
- [x] **003-offline-packs-with-pictures** (image-choice-ui): Downloaded lessons carry their pictures - Must - ✅ COMPLETED (bolt 054-picture-offline-and-credits)
- [x] **004-pictures-ready-before-their-question** (image-choice-ui): A lesson's pictures load before they are needed - Should - ✅ COMPLETED (bolt 054-picture-offline-and-credits)
- [x] **005-picture-credits-in-the-app** (image-choice-ui): Picture credits in the app's licences - Must - ✅ COMPLETED (bolt 054-picture-offline-and-credits)

---

## Stories by Status

- **Planned**: 0
- **Generated**: 11
- **In Progress**: 0
- **Completed**: 88
- **Retired**: 1
