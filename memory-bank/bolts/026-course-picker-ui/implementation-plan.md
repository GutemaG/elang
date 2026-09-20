---
stage: plan
bolt: 026-course-picker-ui
created: '2026-09-20T21:30:00Z'
---

## Implementation Plan: course-picker-ui

### Objective

A learner can see the list of courses, switch between them from the dashboard or Settings with the choice saved, and, when signing up, say which language they speak and which they want to learn, so an Amharic speaker can start on Afaan Oromo and the reverse.

### Real-Source Findings (re-read at Plan stage)

- **Onboarding is before sign-in**, so it has no session and cannot call the authenticated `GET /api/v1/courses`. Today it renders a hardcoded list (`_courseOptions` in `language_selection_screen.dart`: Amharic live, Afaan Oromo "coming soon") and stores only a learning-language code in `PendingOnboardingSelection`, which `HttpAuthApi` sends as `pending_selection.language`.
- **Settings** has its own second hardcoded list (`_courseOptions` in `settings_screen.dart`) and sends `PATCH /users/me` with `language`; `SettingsController.updateLanguage` reads the language from the session check.
- **Dashboard** top bar is a row: sync status banner (expanded), Manage Downloads icon, Settings icon. It loads the skill tree, beans and due count in one `Future.wait`, and reloads on `_reload()`. The dashboard is built in `main.dart` and in several tests with a fixed set of required services.
- **`HttpLessonApi.getSkillTree`** parses categories and nodes and ignores unknown fields, so the new `course` object is additive. `SessionApi` reads `selected_language` and would ignore the new `active_course_id`.
- No skill-tree cache exists on the client yet (only downloaded lesson packs), so course-keyed caching is bolt 027's work, not this bolt's.
- Existing tests to update, not delete: onboarding language screen, settings screen and controller, dashboard tests (new required service), pending-selection storage and `HttpAuthApi` request shape.

### Decisions for your approval

1. **A small public catalog endpoint, so onboarding can be API-driven (recommended).** Add `GET /api/v1/courses/catalog` on the backend: no login, no user data, returns every course (id, learning language, from-language, title, status). Onboarding calls it; if it cannot be reached the screen shows a message and Retry, with no silent default (story 002's edge case). This is a small backend addition in a UI bolt, with its own tests. Alternative: a bundled course list in the app, which keeps the hardcoded list this intent is removing.
2. **A separate `CourseApi` (recommended).** Its own interface, real HTTP implementation and in-memory fake, with three calls: catalog (public), my courses (authenticated), switch course. It leaves `LessonApi` and its many test doubles untouched.
3. **One shared picker.** A bottom sheet used by the dashboard chip and by Settings, grouped by "I want to learn" language with the from-language on each row, coming-soon rows disabled, the active one marked, and completed/total skills shown.
4. **Chip placement.** A course chip at the start of the dashboard top bar showing the active course's learning language. If it does not fit with the sync banner at 360dp and 320dp with large text, it moves to a row of its own above the banner. Layout decided by the overflow tests, not by guessing.

### Deliverables

- **Backend**: `GET /api/v1/courses/catalog` (public) plus tests.
- **Models**: a `Course` model (id, learning language, from-language, title, status, active flag, completed/total skills); `SkillTreeResponse` gains an optional `course`; `SessionUser` reads `active_course_id`; `PendingOnboardingSelection` gains a from-language (older stored selections default to English).
- **Services**: `CourseApi` with `HttpCourseApi` and `FakeCourseApi`; `HttpLessonApi` parses the tree's `course`; `HttpAuthApi` sends `from_language`; `OnboardingRepository` stores both languages; `UserPreferencesApi` unchanged (Settings switches through `CourseApi`).
- **UI**: the shared course picker sheet; the dashboard chip, reloading the dashboard after a switch and keeping the current course with a message on failure; Settings' language row opens the same picker and shows the active course; the onboarding step becomes "I speak" then "I want to learn", driven by the catalog, with coming-soon courses disabled and Continue disabled when no available course matches; the two hardcoded lists removed.
- **Helpers**: a small shared mapping from language code to display and native name (Amharic / አማርኛ, Afaan Oromo / Afaan Oromoo, English), used by the picker, chip and onboarding.
- **Tests**: updated existing tests plus new ones (see below).

### Dependencies

- Bolts 024 and 025 (complete): the course list and switch endpoints and the four seeded courses.
- The backend must be restarted for the new catalog endpoint, and the app fully rebuilt (stop, `flutter run`) for the model changes.

### Technical Approach

- Follow the existing conventions: an abstract API class with an HTTP implementation and a fake; a `ChangeNotifier` controller only where several async mutations need it (Settings already has one); plain stateful widgets elsewhere.
- Keep `LessonApi` unchanged. The dashboard gets `CourseApi` as a new dependency wired in `main.dart`; the dashboard tests' shared builder gains a fake.
- Onboarding derives its "I speak" options from the distinct from-languages of available courses, and "I want to learn" from the courses available for the chosen from-language; coming-soon courses for that from-language show disabled with the existing Join Waitlist affordance. The default "I speak" is English when present.
- Switching: call the switch endpoint, then reload the dashboard; on any failure keep the current course and show a snackbar. Offline switching rules are bolt 027.
- Layout: Fidel and Latin both used in titles, so verify no overflow at 360dp and 320dp with 1.3x text, in the picker, the chip, and the onboarding step.

### Test Plan

- Models and services: course parsing from the catalog, list and switch responses (including errors 404/422 and network failure); tree `course` parsing and its absence; `SessionUser` with and without `active_course_id`; pending selection round trip and the older stored format; `HttpAuthApi` sends `from_language`; the new backend catalog endpoint (public, all courses, no user data).
- Picker: grouped by learning language, from-language shown, active marked, coming soon disabled and unselectable, progress shown, selection returns the course, load failure shows a message and Retry.
- Dashboard: chip shows the active course; picking another course reloads and shows the new tree; a failed switch keeps the current course with a message; existing dashboard behaviours unchanged.
- Settings: the language row opens the picker, a switch is saved through the course API and shown, failure reverts with a message.
- Onboarding: catalog-driven options; an Amharic speaker is offered Afaan Oromo and an Afaan Oromo speaker is offered Amharic, with no English step; a pair with no available course disables Continue with a coming-soon message; catalog failure shows Retry with no default; both languages persisted and sent at sign-in.
- Overflow at 360dp and 320dp, 1.3x text.
- Full Flutter and backend suites, `flutter analyze`. A manual on-device check follows: switch course, restart the app, sign up with a pair.

### Acceptance Criteria

- [ ] Course lists in onboarding, dashboard and Settings all come from the backend; no hardcoded course list remains
- [ ] Dashboard chip opens the picker; coming-soon courses are disabled; the active one is marked
- [ ] Selecting a course saves it and shows that course's dashboard; a failed switch keeps the current course with a message
- [ ] Settings uses the same picker
- [ ] Onboarding asks "I speak" and "I want to learn"; an Amharic speaker can pick Afaan Oromo and the reverse; an unavailable pair cannot continue; a catalog failure shows Retry with no silent default
- [ ] The chosen pair survives an app restart during onboarding and is sent at sign-in
- [ ] No overflow at 360dp and 320dp with 1.3x text
- [ ] Existing tests updated (none deleted) and the full Flutter and backend suites pass
- [ ] Manual on-device check done by the user
