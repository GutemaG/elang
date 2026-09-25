---
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: stories-defined
created: '2026-09-25T06:15:00Z'
updated: '2026-09-25T06:15:00Z'
---

# Unit Brief: Image Choice UI

## Purpose

Show both picture question types in the app, in the same frame as the
other five, in lessons, downloaded lessons and practice, with pictures that
are ready when needed and credited where the licence asks.

## Scope

### In Scope
- `PictureTile` and its grid in the question kit, with gallery entries
- `ImageChoiceExercise` and `AudioImageChoiceExercise`: models, parsing,
  grading, fake API content
- Both types on the lesson screen, and so in practice
- Offline packs: download, local paths, delete and size, for pictures and
  the new type's audio; the cached-copy rule
- Early loading of a lesson's pictures
- A "Licences" entry with the picture credits

### Out of Scope
- `LessonController` changes beyond what the new types need (none
  expected: they grade like multiple choice)
- Moving settings onto the library (bolt 049)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-5 | Picture tile and lesson screens | Must |
| FR-6 | Offline lessons | Must |
| FR-7 | Practice sessions | Must |
| FR-8 | Sample content: the credits in the app | Must |
| FR-9 | Older app versions | Must |
| FR-10 | Pictures ready before their question | Should |

Performance, accessibility, reliability and compatibility NFRs apply.

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 5 |
| Must Have | 4 |
| Should Have | 1 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-picture-tile-in-the-kit | A picture answer tile that looks and reacts like every other tile | Must | Planned |
| 002-picture-questions-in-lessons-and-practice | Both picture questions in lessons and practice | Must | Planned |
| 003-offline-packs-with-pictures | Downloaded lessons carry their pictures | Must | Planned |
| 004-pictures-ready-before-their-question | A lesson's pictures load before they are needed | Should | Planned |
| 005-picture-credits-in-the-app | Picture credits in the app's licences | Must | Planned |

---

## Dependencies

### Depends On
`001-image-choice-service` (bolt 050) for the real shape; bolt 051 for the
credits file used by story 005. The question kit (bolts 044, 045) is done.

### Depended By
None.

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| Cloudflare R2 | Pictures at public URLs | Medium on the web: needs CORS |

---

## Constraints

- The tile uses only the kit and Highland Pulse tokens; the rules-test
  allow-list may not grow.
- Each story's Plan names its reference design (FR-11 of intent 018), for
  example Duolingo's picture-choice grid.
- Pictures are decoded at tile size.
- No overflow at 320 and 360 px, at 1.0× and 1.3× text; tap targets at
  least 48 px; reduced motion followed.

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 053-picture-tile-and-lesson | simple-construction-bolt | 001, 002 | Both types playable in lessons and practice |
| 054-picture-offline-and-credits | simple-construction-bolt | 003, 004, 005 | Offline, early loading and credits |
