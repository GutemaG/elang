---
stage: plan
bolt: 018-amole-ui
created: '2026-09-17T20:00:00Z'
---

## Implementation Plan: amole-ui

### Objective

Show the current Amole balance on the home dashboard, next to the existing streak/Beans/XP HUD, updating after any lesson completion or refill with no manual refresh.

### Corrected During Plan (read real source first)

The Inception unit-brief assumed the dashboard "already fetches beans-status data for the existing Beans HUD" and that this bolt could just reuse that fetch. **That's wrong** — reading `skill_tree_dashboard_screen.dart` and `lesson_hud.dart` shows the dashboard's `LessonHud` (streak/beans/XP pills) is fed entirely from `GET /api/v1/skill-tree`'s response (`SkillTreeResponse.beans`/`.beansMax`/`.totalXp`/`.streakCount`), which carries **no Amole field at all**. The only place that already calls `GET /api/v1/beans` (`LessonApi.getBeansStatus()`, which does return `amoleBalance`) is `LessonScreen._showOutOfBeans()`, an unrelated, lazily-triggered call inside a lesson.

**Decision**: rather than widening the already-shipped `/api/v1/skill-tree` backend response (which would mean reopening completed bolt `017`'s unit, `001-amole-service`, for an out-of-Inception-scope change) or leaving Amole HUD-less, this bolt adds a **second, parallel fetch** to `getBeansStatus()` from the dashboard itself, alongside its existing `getSkillTree()` call — the same endpoint `LessonScreen` already calls today, just from a second call site. This keeps unit `002-amole-ui` entirely frontend-only, exactly as Inception scoped it, at the cost of one extra network call per dashboard load (not "zero new network calls" as originally assumed).

### Deliverables

- `LessonHud` gains a 4th pill for Amole balance (distinct icon from XP's `Icons.bolt`, to avoid visual confusion — using `Icons.paid`).
- `SkillTreeDashboardScreen` fetches `getBeansStatus()` in parallel with `getSkillTree()` (`Future.wait`), combined into one small private result type, and re-fetches both on every `_reload()` (already called on returning from any lesson — covers both "just completed a lesson" and "just refilled via the out-of-Beans modal" without new wiring).
- Combined-fetch failure (either call fails) shows the existing `_ErrorState`/retry flow — no new error-handling pattern.

### Dependencies

- `LessonApi.getBeansStatus()` — already exists (used today by `LessonScreen`), no API-client change needed.
- No backend changes (per the correction above).

### Technical Approach

- Replace `_future`'s type from `Future<SkillTreeResponse>` to a `Future<_DashboardData>` (a tiny private record-like class holding `tree` and `beansStatus`), built via `Future.wait([lessonApi.getSkillTree(), lessonApi.getBeansStatus()])` (or two awaits combined with `Future.wait` preserving both types via a small helper — exact Dart construct decided at Implement time, functionally equivalent either way).
- `LessonHud(streakCount:, beans:, beansMax:, totalXp:, amoleBalance:)` — new required param, positioned as a 4th `_HudPill` alongside the existing three, following the exact same `_HudPill` construction pattern (no new widget primitive).
- Zero widget contains: `OutOfBeansSheet` is untouched (already correct, confirmed at Inception).

### Acceptance Criteria

- [ ] Dashboard shows current Amole balance next to streak/beans/XP on load
- [ ] Balance updates after returning from a lesson (completion award) or a refill (spend), via the existing `_reload()` path — no new refresh mechanism
- [ ] Balance of 0 displays as `0`, not hidden
- [ ] Combined fetch failure shows the same retry UI as today's skill-tree fetch failure
- [ ] Zero regression to `skill_tree_dashboard_screen_test.dart`'s existing assertions
- [ ] `flutter analyze` clean, `flutter test` passing
