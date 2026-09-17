---
stage: test
bolt: 018-amole-ui
created: '2026-09-17T20:35:00Z'
---

## Test Report: amole-ui

### Summary

- **Tests**: 158/158 passing (excluding 7 pre-existing e2e tests that require a live backend on `localhost:8000` — same known gap from prior bolts, unaffected by this change)
- **Coverage**: widget-level (this bolt's convention, per `coding-standards.md` — UI screens get smoke/widget-level coverage, not exhaustive)

### Test Files

- [x] `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart` — 3 new tests (balance renders correctly, zero balance shown not hidden, balance updates after a reload triggered by returning from a lesson) + 2 existing tests fixed (their `ControllableLessonApi` doubles needed `beansStatus` set, since the dashboard now depends on it)

### Acceptance Criteria Validation

- ✅ **Dashboard shows current Amole balance next to streak/beans/XP on load**: `shows the Amole balance from beans-status next to streak/beans/XP`
- ✅ **Balance updates after returning from a lesson, via the existing `_reload()` path**: `the Amole balance reflects a change after the dashboard reloads`
- ✅ **Balance of 0 displays as `0`, not hidden**: `a zero Amole balance is shown as 0, not hidden`
- ✅ **Combined fetch failure shows the same retry UI as today's skill-tree fetch failure**: `a fetch failure shows inline error + retry, then recovers` (pre-existing test, still passes — `Future.wait` propagates either future's failure)
- ✅ **Zero regression to `skill_tree_dashboard_screen_test.dart`'s existing assertions**: all 7 pre-existing tests in that file still pass
- ✅ **`flutter analyze` clean, `flutter test` passing**: confirmed (only pre-existing info-level lints; only pre-existing e2e gaps)

### Issues Found

None new. The 2 pre-existing test fixtures that needed `beansStatus` added were an expected, direct consequence of widening the dashboard's data dependency (documented in `implementation-walkthrough.md`'s Developer Notes) — not a defect.

### Notes

This bolt adds one extra network request per dashboard load (`getBeansStatus()`, alongside the pre-existing `getSkillTree()`), a deliberate, documented trade-off from the Plan stage rather than the "zero new network calls" originally assumed at Inception. No performance concern was raised for this codebase's scale.
