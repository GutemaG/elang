---
intent: 026-lesson-path-nodes
phase: inception
status: complete
created: 2026-10-06T08:56:00Z
updated: 2026-10-06T08:57:00Z
---

# Requirements: One path node per lesson

## Intent Overview

The home path draws one bubble per skill. A skill with three lessons is
one bubble whose popover says "Lesson 1 of 3"; a ring fills as each
lesson is done, and the bubble only turns green once all three are. The
learner sees one stop that keeps opening different questions, which is
confusing.

Each lesson becomes its own bubble on the path, in order, under a small
label with its skill's title. Progress, crowns, unlocking, XP and offline
downloads keep their current rules.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| A lesson is a stop on the path | A skill with N lessons shows N bubbles; a finished lesson turns green at once | Must |
| No "Lesson 1 of 3" | Neither the popover nor the lesson screens speak of parts of a skill | Must |
| Nothing lost | Existing learners' progress, crowns and unlocks look the same after the update | Must |
| Old apps keep working | An app without this change still shows one bubble per skill | Must |

## Scope

In scope:

- The skill tree sends each skill's lessons, in order, with whether each
  is done in the current pass.
- The app draws a bubble per lesson, the skill's title above its first
  bubble, and the crown on that label.
- Lesson states on the path and what a tap does.
- Dropping the skill-part wording from the popover, the lesson screen
  and the lesson summary.

Out of scope:

- Changing how progress is stored (per skill, with the set of lessons done
  in the current pass) or how crowns are earned.
- The admin site: sections, skills and lessons stay as they are.
- Crowns per lesson.

---

## Functional Requirements

### FR-1: Lessons in the skill tree
- **Description**: Each skill in `GET /api/v1/skill-tree` also carries
  `lessons`: its lessons in their order, each with `id`, `title` and
  `done` (done in the skill's current pass).
- **Acceptance Criteria**:
  - The field is added; nothing existing changes, so older apps work.
  - Order is the lessons' `order_index`, the same order as today's
    `lesson_id` choice.
  - It costs no extra query per skill.
- **Priority**: Must

### FR-2: One bubble per lesson
- **Description**: When the skill tree has lessons, the path shows one
  bubble per lesson, in skill then lesson order, and the zig-zag runs on
  through the whole section.
- **Acceptance Criteria**:
  - A label with the skill's title sits above its first lesson bubble;
    a completed skill's label shows its crown level.
  - The section header's count is of lessons.
  - The jump button finds the learner's current lesson.
- **Priority**: Must

### FR-3: Lesson states and taps
- **Description**: A lesson's state comes from its skill's state and its
  `done` flag.
- **Acceptance Criteria**:
  - Locked skill: every lesson locked; the popover says to finish what is
    above.
  - Completed skill: every lesson completed; a tap reviews that lesson,
    as a review of the skill does today (no XP, no beans).
  - Active skill: done lessons are completed (green) and a tap plays that
    lesson again; the first lesson not done is active; the ones after it
    are locked until the one before is done.
  - A tap always starts the tapped lesson; its popover offers the
    download for that lesson.
- **Priority**: Must

### FR-4: No parts of a skill
- **Description**: With lesson bubbles, no screen speaks of "Lesson N of
  M" or of lessons left in a skill.
- **Acceptance Criteria**:
  - The popover has no "Lesson N of M"; the bubble has no ring.
  - The lesson screen and its summary show no skill-progress card; a
    skill unlocked is still announced.
- **Priority**: Must

### FR-5: Older backend
- **Description**: When the skill tree has no `lessons` (a backend before
  this change, or an old saved copy), the path is drawn as today.
- **Acceptance Criteria**:
  - Saved copies of the tree keep the lessons, so offline shows the same
    path as online.
- **Priority**: Must

---

## Non-Functional Requirements

### Performance
| Requirement | Metric | Target |
|-------------|--------|--------|
| Skill tree | Queries | Same number as before |
| Path | Scrolling | No extra rebuild per frame |

### Accessibility
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Lesson bubble | Screen reader label | Lesson title, skill title, state |
| Skill label | Header | Read as a heading |

### Localization
| Requirement | Notes |
|-------------|-------|
| New strings | In English, Amharic and Afaan Oromo; the sweep's allow-list stays empty |

---

## Constraints

- Progress stays per skill: `user_skill_progress.completed_lesson_ids_this_cycle`.
- No migration.

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| Lessons are meant to be done in order | A learner wanting to skip ahead cannot | Lessons after the current one open when the one before is done, as skills do |
| Playing a done lesson of an unfinished skill again counts as today | None: the server already treats it that way | - |
