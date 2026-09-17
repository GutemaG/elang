---
stage: implement
bolt: 018-amole-ui
created: '2026-09-17T20:20:00Z'
---

## Implementation Walkthrough: amole-ui

### Summary

Added an Amole balance pill to the home dashboard's HUD, sourced from a new parallel `getBeansStatus()` fetch alongside the existing skill-tree fetch (per the Plan-stage correction — no backend change, no reused existing fetch).

### Structure Overview

`SkillTreeDashboardScreen` now resolves a small private `_DashboardData` (skill tree + beans status) via one combined `Future.wait`, instead of the skill tree alone. `LessonHud` (the existing streak/beans/XP pill row) gains a 4th required parameter and pill for the Amole balance, using a distinct icon from XP's so the two don't read as the same currency.

### Completed Work

- [x] `lib/features/lesson/widgets/lesson_hud.dart` — new required `amoleBalance` param, 4th `_HudPill` (`Icons.paid`, distinct from XP's `Icons.bolt`)
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` — new private `_DashboardData` class; `_load()` combines `getSkillTree()` + `getBeansStatus()` via `Future.wait`; `_future`/`_reload()`/`FutureBuilder` retyped accordingly; `_DashboardContent` gains an `amoleBalance` param threaded to `LessonHud`
- [x] `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart` — added a shared `_fixtureBeansStatus` const; wired it into the two `ControllableLessonApi` setups that previously only set `skillTree`/`skillTreeError`

### Key Decisions

- **Second network call, not a widened existing one**: reusing the already-shipped `GET /api/v1/beans` endpoint (already correct, already returns `amoleBalance`) rather than widening the completed bolt `017`'s `/skill-tree` response — keeps this bolt's change surface entirely frontend, matches Inception's unit split, at the cost of one extra request per dashboard load (see `implementation-plan.md`'s "Corrected During Plan").
- **`Future.wait` over two separate `FutureBuilder`s**: keeps a single loading/error state for the whole dashboard, identical to the existing single-fetch error/retry UX — no new error-handling pattern for a partial failure.
- **Distinct icon for the Amole pill**: `Icons.paid` rather than reusing `Icons.bolt` (already XP's icon in the same pill row), so the two aren't visually interchangeable at a glance.

### Deviations from Plan

None — the plan's "Corrected During Plan" section already anticipated the second-fetch approach; implementation matches it exactly.

### Dependencies Added

None — reuses `LessonApi.getBeansStatus()`, already part of the interface.

### Developer Notes

`ControllableLessonApi.getBeansStatus()` null-checks its `beansStatus` field (`async => beansStatus!`) — any current or future dashboard test using that double must set `beansStatus`, not just `skillTree`/`skillTreeError`, or it'll throw at the first `_load()` call. `FakeLessonApi` needed no changes; it already returns a real `BeansStatus`.
