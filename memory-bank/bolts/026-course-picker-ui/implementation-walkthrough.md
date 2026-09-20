---
stage: implement
bolt: 026-course-picker-ui
created: '2026-09-20T23:00:00Z'
---

## Implementation Walkthrough: course-picker-ui

### Summary

The app now lists courses from the backend and lets the learner switch between them. A course chip on the dashboard and a Course row in Settings open one shared picker; onboarding asks "I speak" and "I want to learn" from a public course catalog, so an Amharic speaker can start on Afaan Oromo and the reverse. Both hardcoded course lists are gone. One small backend endpoint was added so onboarding can list courses before sign-in.

### Structure Overview

A new `CourseApi` boundary (interface, HTTP implementation and in-memory fake) offers three calls: the public catalog, the signed-in course list, and switching the active course. A `Course` model serves all three, and the skill tree now carries the active course. The picker is one bottom sheet plus a helper that shows it and performs the switch, returning the new course or nothing on dismissal, no change, or failure (with a message). The dashboard chip, Settings and onboarding are thin consumers of these pieces. The shared `CourseApi` instance lives in the auth dependencies, so onboarding (before sign-in) and the signed-in screens use the same object.

### Completed Work

- [x] `backend/app/infrastructure/api/course_routers.py`, `course_schemas.py` - new public `GET /api/v1/courses/catalog` (no login, no user data) listing every course
- [x] `lib/shared/models/course.dart` - `Course` (available or coming soon, active flag, progress) and `CourseList`
- [x] `lib/shared/models/language_names.dart` - language code to display and native name
- [x] `lib/shared/services/course_api.dart`, `http_course_api.dart`, `fake_course_api.dart` - the boundary, its HTTP client (catalog is public, the rest use the session token) and the fake
- [x] `lib/shared/models/skill_tree.dart`, `lib/shared/services/http_lesson_api.dart` - the tree carries an optional `course`, parsed when present
- [x] `lib/shared/services/session_api.dart` - the session user reads `active_course_id` when sent
- [x] `lib/shared/models/pending_onboarding_selection.dart`, `lib/shared/services/onboarding_repository.dart`, `lib/shared/services/http_auth_api.dart` - the pending selection holds the from-language (older stored selections read as English) and sign-in sends it
- [x] `lib/features/courses/course_picker.dart` - the shared picker sheet and the pick-and-switch helper
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` - the course chip, opening the picker and reloading after a switch; the top bar became a row with the chip and icons above the sync banner
- [x] `lib/features/settings/screens/settings_screen.dart`, `state/settings_controller.dart` - the Language row became a Course row using the shared picker, showing the active course title; the old language-PATCH path was removed from the controller
- [x] `lib/features/auth/screens/language_selection_screen.dart` - rewritten as "I speak" then "I want to learn", driven by the catalog, with coming-soon courses disabled, a waitlist button, and Retry on failure
- [x] `lib/features/auth/auth_dependencies.dart`, `auth_routes.dart`, `lib/main.dart` - the course API is created once and wired to onboarding, the dashboard and Settings
- [x] Tests: existing onboarding, settings, dashboard, pending-selection and sign-in tests updated (none deleted); new tests for the models, the HTTP client, the picker, the dashboard chip, Settings' course row, the wiring, and the backend catalog

### Key Decisions

- **Public catalog endpoint**: chosen at Plan approval because onboarding has no session; it returns no user data.
- **"I speak" comes from available courses only**: a language nobody teaches from never appears, so an unavailable pair cannot be continued by construction. Coming-soon courses for the chosen language show disabled with the existing waitlist button.
- **Course chip on its own row above the sync banner**: the plan allowed this fallback; it avoids the banner and the chip competing for width at 320dp.
- **Picker returns the course, the helper does the switch**: one code path and one failure message for both callers.
- **Settings falls back to the language name** when the course list cannot be loaded, rather than failing the whole screen.

### Deviations from Plan

- New tests were written during this stage to validate the code as it was built; Stage 3 will run and report them rather than write them.
- The unused language argument on the preferences API interface was left in place; the client no longer calls it, but the backend still supports it for older clients.

### Dependencies Added

None.

### Developer Notes

- Full Flutter suite: 241 passed (182 before this bolt); `flutter analyze` shows no errors or warnings, only the existing info-level lints. Backend suite: 506 passed, ruff clean.
- **To see it on the phone**: restart the backend (new catalog route), then stop and run `flutter run` for a full rebuild; a hot reload will not pick up the model changes.
- Offline behaviour of switching (no connection, cached courses) is bolt 027; today a failed switch or list simply shows a message and keeps the current course.
- The manual on-device check (switch course, restart the app, sign up with a pair) is still pending.
