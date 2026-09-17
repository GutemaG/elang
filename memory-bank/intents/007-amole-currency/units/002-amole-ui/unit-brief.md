---
unit: 002-amole-ui
intent: 007-amole-currency
phase: inception
status: complete
created: '2026-09-17T16:15:00Z'
updated: '2026-09-17T16:15:00Z'
---

# Unit Brief: Amole UI

## Purpose

Display the Amole balance on the home dashboard. Everything else the original build prompt asked for on the frontend (the out-of-Beans modal's spend option and disabled/insufficient state) is already shipped and correct in `OutOfBeansSheet` — verified by reading `lib/features/lesson/widgets/out_of_beans_sheet.dart` and `lib/shared/models/beans_status.dart` directly during requirements-gathering.

## Scope

### In Scope
- Amole balance display on `SkillTreeDashboardScreen`, next to the existing XP/streak display
- Wiring it to the existing beans-status data the dashboard already fetches for the Beans HUD (no new network call)

### Out of Scope
- Any change to `OutOfBeansSheet` (already correct)
- Any new screen

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-5 | Amole Balance on the Home Dashboard | Must |

---

## Domain Concepts

No new domain concepts — purely a display of an existing value (`BeansStatus.amoleBalance`, already modeled in `lib/shared/models/beans_status.dart`).

---

## Technical Context

### Suggested Technology
Flutter, extending `lib/features/lesson/screens/skill_tree_dashboard_screen.dart`. Verify at Plan stage exactly where/how the existing beans-status fetch feeds the dashboard's XP/streak widgets today, and match that pattern rather than introducing a second fetch path.

### External Dependencies
None.

---

## Constraints

- Depends on `001-amole-service`'s retrofit landing first (response shape is unchanged, but don't build against the old column-backed value in the meantime if both are in flight).
- Zero regression to existing dashboard tests (`skill_tree_dashboard_screen_test.dart`).

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 018-amole-ui | simple-construction-bolt | 001 | Dashboard balance display |

---

## Notes

Much smaller than the original build prompt's "002-amole-ui" scope — the modal retrofit it described turned out to already be done.
