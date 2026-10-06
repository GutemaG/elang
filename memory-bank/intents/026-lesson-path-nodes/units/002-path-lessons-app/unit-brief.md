---
unit: 002-path-lessons-app
intent: 026-lesson-path-nodes
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-06T08:57:00Z'
updated: '2026-10-06T08:57:00Z'
---

# Unit Brief: Path Lessons App

## Purpose

Show every lesson as its own bubble on the home path, so finishing a
lesson is visible at once and no bubble is "Lesson 1 of 3".

## Scope

### In Scope
- Reading and saving `lessons` on each skill node
- The path's stops: one per lesson, or one per skill without `lessons`
- The skill label above a skill's first lesson, with its crown
- Lesson states, the popover and what a tap starts
- No ring, "Lesson N of M" or skill-progress card with lesson bubbles
- New strings in English, Amharic and Afaan Oromo
- Tests

### Out of Scope
- The lesson flow itself, practice, downloads screen

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-2 | One bubble per lesson | Must |
| FR-3 | Lesson states and taps | Must |
| FR-4 | No parts of a skill | Must |
| FR-5 | Older backend | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 002-one-bubble-per-lesson | A bubble per lesson, under its skill's label | Must | Complete (bolt 088) |
| 003-lesson-states-and-taps | Each lesson's state, popover and tap | Must | Complete (bolt 088) |
| 004-no-parts-of-a-skill | No "Lesson N of M" anywhere | Must | Complete (bolt 088) |
| 005-older-backend-and-saved-copies | Old trees drawn as today; saved copies keep lessons | Must | Complete (bolt 088) |

### 002-one-bubble-per-lesson (FR-2)

**As a** learner, **I want** each lesson to be its own stop, **so that**
I can see where I am.

- [x] A skill with N lessons shows N bubbles, in order; the zig-zag runs
  on through the section.
- [x] The skill's title is a label above its first bubble, read as a
  heading; a completed skill's label shows its crown level.
- [x] The section header counts lessons done of lessons.
- [x] The jump button goes to the current lesson.

### 003-lesson-states-and-taps (FR-3)

**As a** learner, **I want** a finished lesson to turn green and the next
one to open, **so that** progress is clear.

- [x] Locked skill: its lessons are locked, and the popover says to
  finish the lesson above.
- [x] Active skill: done lessons are green; the first not done is active
  with "Start"; later ones are locked.
- [x] Completed skill: its lessons are green, and a tap is a review of
  that lesson.
- [x] A done lesson of an unfinished skill can be played again, and its
  popover says so.
- [x] The popover is titled with the lesson's title and offers that
  lesson's download.

### 004-no-parts-of-a-skill (FR-4)

**As a** learner, **I want** no talk of parts of a skill, **so that** a
lesson is simply a lesson.

- [x] No ring and no "Lesson N of M" on a lesson bubble or its popover.
- [x] No skill-progress card on the lesson summary; the level-up sheet
  still says which skill unlocked.

### 005-older-backend-and-saved-copies (FR-5)

**As a** learner on an older backend or offline, **I want** the path to
work as before, **so that** nothing breaks.

- [x] A tree without `lessons` is drawn one bubble per skill, as today.
- [x] The saved copy keeps `lessons`; offline shows the same path.

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| 001-path-lessons-service | The `lessons` field |

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 088-path-lesson-nodes | simple-construction-bolt | 002-005 | The lesson bubbles |
