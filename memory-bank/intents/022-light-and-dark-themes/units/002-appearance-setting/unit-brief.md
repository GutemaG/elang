---
unit: 002-appearance-setting
intent: 022-light-and-dark-themes
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: ready
created: '2026-09-30T13:52:00Z'
updated: '2026-09-30T13:52:00Z'
---

# Unit Brief: Appearance Setting

## Purpose

Let the learner choose System, Light or Dark, kept on the phone and applied
at once.

## Scope

### In Scope
- An appearance preference on the phone (default System)
- `MaterialApp` `theme`, `darkTheme` and `themeMode`
- The "Appearance" row in Settings

### Out of Scope
- Saving the choice to the account (D3)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-5 | The Appearance setting | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 006-appearance-choice | System, Light or Dark in Settings | Must | Planned (bolt 070) |

### 006-appearance-choice (FR-5)

**As a** learner, **I want** to choose light, dark or my phone's setting,
**so that** the app looks the way I like.

- [ ] Settings shows "Appearance" with System, Light and Dark; System is
  the default.
- [ ] A choice applies at once on every screen, with no restart.
- [ ] System follows the phone, including a change while the app is open.
- [ ] The choice is kept on the phone, survives restarts and sign-out, and
  applies before sign-in.
- [ ] The row is one readable node with its current value.

---

## Dependencies

### Depends On
`001-theme-palette`.

### Depended On By
None.
