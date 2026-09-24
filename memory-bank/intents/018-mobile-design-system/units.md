---
intent: 018-mobile-design-system
phase: inception
created: '2026-09-24T12:55:00Z'
---

# Units: mobile-design-system

## Overview

Three Flutter units, split along the real seam between making the components
and using them:

1. **The library.** Tokens, fonts, shared components, the gallery and the rules
   test. It changes no screen, so it can land, and be reviewed in the gallery,
   before any screen looks different.
2. **The question kit, and the lesson screen on it.** They belong together:
   the kit's only consumer is the lesson screen, and building them in one unit
   keeps grading behaviour under test the whole time.
3. **Every other screen** moved onto the library, finishing with a consistency
   sweep that empties the rules test's allow-list.

**The rules test starts with an allow-list.** It lands in unit 1, listing every
file that has not moved yet. Each bolt removes the files it migrates. The last
bolt leaves the list empty. This keeps the suite green after every bolt
(NFR-5) while still stopping any new violation.

## Units

### 001-design-foundation-ui (frontend)

**Purpose**: The shared design library:
- tokens, shadows, radii and motion
- bundled fonts
- `AppButton` and `AppIconButton`
- `AppPage` and its backgrounds
- `AppCard` and its family
- sheets and dialogs
- status pieces
- the debug gallery
- the rules test

**Assigned Requirements**: FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-9, FR-10, FR-11 (the reference-design process, applied by every unit)
**Complexity**: Moderate. Many small components, little logic. The risk is getting shadows, press effects and fonts to match the mockups.
**Depends on**: nothing
**Bolts**: `042-design-foundation`, `043-design-surfaces`

### 002-question-kit-ui (frontend)

**Purpose**: One frame, prompt, answer tile and action bar for every question type, and the lesson screen rebuilt on them.
**Assigned Requirements**: FR-7, and FR-8 for the lesson screen: its five question types, the mistake review, and its loading, error and offline states
**Complexity**: High. It replaces the three tile widgets that grading, the shake, the used words and match pairs rely on, in the most heavily tested screen.
**Depends on**: `001-design-foundation-ui`
**Bolts**: `044-question-kit`, `045-lesson-screen-on-kit`

### 003-screen-migration-ui (frontend)

**Purpose**: Move every remaining screen and sheet onto the library, then run the consistency sweep.
**Assigned Requirements**: FR-8 for every screen except the lesson screen; NFR-1 to NFR-4 verified app-wide
**Complexity**: Moderate. Mostly replacing decoration code. Tests that find widgets by type are the main risk.
**Depends on**: `001-design-foundation-ui`. Its last story also needs `002-question-kit-ui`, because the sweep covers the whole app.
**Bolts**: `046-onboarding-screens-on-kit`, `047-dashboard-on-kit`, `048-lesson-complete-and-sheets-on-kit`, `049-settings-downloads-and-sweep`

## Requirement-to-Unit Mapping

| FR | Requirement | Unit |
|----|-------------|------|
| FR-1 | Complete design tokens | 001-design-foundation-ui |
| FR-2 | Buttons | 001-design-foundation-ui |
| FR-3 | Page shell and backgrounds | 001-design-foundation-ui |
| FR-4 | Cards and surfaces | 001-design-foundation-ui |
| FR-5 | Sheets and dialogs | 001-design-foundation-ui |
| FR-6 | Status and feedback pieces | 001-design-foundation-ui |
| FR-7 | Question-type kit | 002-question-kit-ui |
| FR-8 | Every screen moves onto the shared components | 002 (the lesson screen) and 003 (all others) |
| FR-9 | Bundled fonts | 001-design-foundation-ui |
| FR-10 | Component gallery | 001-design-foundation-ui |
| FR-11 | Every design follows a reference | 001 owns the process; every story in every unit records its reference |

## Dependency Graph

```text
042-design-foundation ──► 043-design-surfaces ──┬──► 044-question-kit ──► 045-lesson-screen-on-kit ──┐
                                                ├──► 046-onboarding-screens-on-kit                   │
                                                ├──► 047-dashboard-on-kit                            │
                                                └──► 048-lesson-complete-and-sheets-on-kit           │
                                                                     └───────────────────────────────┴──► 049-settings-downloads-and-sweep
```

Bolts 044, 046, 047 and 048 each need only the library, so their order after 043 is free. The plan runs them in the numbered order. Bolt 049 goes last because its sweep covers every screen.

## Notes

- **Spell-from-tiles (bolt 033, intent 016)** is planned and not started. It should be built on the kit, so it should run after `044-question-kit`. The alternative is to build it first and rework it in 045.
- **Reference designs (FR-11)** are chosen in each bolt's Plan stage. The Stitch mockup is used where one exists. Otherwise the plan names at least one fetched external reference, and what was borrowed from it, before any code is written.
