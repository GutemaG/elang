---
stage: test
bolt: 023-categories-ui
created: '2026-09-20T01:10:00Z'
---

## Test Report: categories-ui

### Summary

- **Flutter**: 182/182 passed (`flutter analyze`: no errors or warnings)
- **Backend**: full suite passed, ruff clean (one test added this stage)
- **Manual on-device check**: not yet done (user)

### Test Files

- [x] `test/features/lesson/screens/skill_tree_dashboard_categories_test.dart` - N categories render N banners in order with correct "x/y Completed"; skills sit under their own banner; zig-zag restarts per category; empty category shows 0/0; locked nodes stay untappable and unlocked nodes in later categories get a download badge; no overflow at 360dp and 320dp with long titles and 1.3x text
- [x] `test/shared/services/http_lesson_api_test.dart` - categories parsed in order and grouped by category id; empty category; unknown category id fails clearly; older response without categories falls back to one banner
- [x] `test/shared/services/fake_lesson_api_test.dart` - completing a skill unlocks only within its own category
- [x] `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart`, `test/features/auth/splash_screen_test.dart`, `test/helpers/controllable_lesson_api.dart` - existing dashboard behaviors unchanged on the category model
- [x] `backend/tests/integration/test_seeded_categories_end_to_end.py` - new: words learned in a Travel & Places lesson appear in Practice once due (story 002)

### Acceptance Criteria Validation

- ✅ **N categories render N banners with correct counts**: dashboard categories test
- ✅ **Each category's skills beneath its banner, zig-zag restarting**: dashboard categories test
- ✅ **No overflow at 360dp (and 320dp)**: dashboard categories test, long titles and 1.3x text
- ✅ **Existing skill behaviors unchanged**: existing dashboard tests pass unmodified apart from fixtures
- ✅ **Models/HTTP/Fake parse and expose categories; older response falls back**: HTTP and fake tests
- ✅ **New-category lessons complete (XP, vocab rows), unlock only within their category, feed Practice**: backend end-to-end tests (bolt 022 plus the new Practice test)
- ✅ **Downloads**: the per-lesson download path is category-independent; badge shown for unlocked nodes in every category (widget test). Real pack download of a new-category lesson is verified manually
- ✅ **Full Flutter and backend suites pass**
- ⏳ **Manual on-device check**: pending user

### Issues Found

- `http_auth_api_e2e_test.dart` hits a real local backend and failed once in a full run (network flake); it passed on rerun and in the next full run.
- `dart format` on the whole tree reformats about 25 unrelated files; it was reverted. Only files this bolt touches are changed.

### Notes

- The phone must be fully rebuilt (stop, `flutter run`) to see the categories; a hot reload will not pick up the model change.
- Amharic content remains agent-authored and not native-reviewed (NFR-3).
