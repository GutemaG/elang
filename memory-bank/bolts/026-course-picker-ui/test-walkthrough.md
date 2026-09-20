---
stage: test
bolt: 026-course-picker-ui
created: '2026-09-20T23:30:00Z'
---

## Test Report: course-picker-ui

### Summary

- **Flutter**: 241 passed, 0 failed (182 before this bolt, so 59 added or extended)
- **Backend**: 506 passed, 0 failed; ruff clean
- **`flutter analyze`**: no errors or warnings; 13 info-level lints, all in existing style (none block)

### Test Files

- [x] `backend/tests/integration/test_courses_endpoints.py` - public catalog: no login needed, coming-soon included, no per-user fields, `/courses` still requires login
- [x] `test/shared/models/course_models_test.dart` - `Course` and `CourseList` parsing, missing fields, copy
- [x] `test/shared/services/http_course_api_test.dart` - catalog is public, list sends the token, switch request shape, backend error codes, network and malformed failures
- [x] `test/shared/services/course_wiring_test.dart` - tree `course`, session `active_course_id`, both languages persisted and sent at sign-in, older selections default to English
- [x] `test/features/courses/course_picker_test.dart` - grouping, active mark, progress, coming soon disabled, Retry, switch, no-op on the active course, failed switch, dismissal, overflow at 360dp and 320dp with 1.3x text
- [x] `test/features/lesson/screens/skill_tree_dashboard_course_chip_test.dart` - chip label, opens the picker, switch reloads the tree, failed switch keeps the course, no overflow at 360dp and 320dp
- [x] `test/features/auth/language_selection_screen_test.dart` (rewritten), `daily_goal_selection_screen_test.dart`, settings screen and controller tests, dashboard tests, `http_auth_api_test.dart` - updated for the new flow

### Success Criteria

- [x] Course list is API-driven; both hardcoded lists removed
- [x] Coming-soon courses disabled; failed switch keeps the current course
- [x] No overflow at 360dp and 320dp with 1.3x text
- [x] Full Flutter suite passes

### Not Covered

- **Manual on-device check** (pending for you): restart the backend, stop and `flutter run`, then switch course from the dashboard and Settings, restart the app to confirm it is remembered, and sign up with an Amharic-to-Afaan-Oromo pair.
- **Offline switching and per-course offline queue**: bolt 027.
- **Native-speaker review** of the Afaan Oromo and Amharic content: still open.
