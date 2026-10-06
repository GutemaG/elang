---
stage: plan
bolt: 088-path-lesson-nodes
created: '2026-10-06T09:11:00Z'
---

## Implementation Plan: path-lessons-app

### Objective

Stories 002-005 (FR-2 to FR-5): one bubble per lesson on the home path,
under a label with its skill's title; lesson states and taps; no "Lesson
N of M"; trees without `lessons` drawn as today.

### What the code says (checked before planning)

- **F1** `SkillTreeNode` (`shared/models/skill_tree.dart`) is one skill:
  `lessonId` (the next lesson), `lessonsDone` / `lessonCount`; saved
  copies go through its `toJson` / `fromJson`.
- **F2** The dashboard (`skill_tree_dashboard_screen.dart`) draws
  `_CategoryNodes` from `tree.nodesIn(category)`; a tap opens
  `showSkillPopover`, then `LessonScreen(lessonId: node.lessonId,
  isReview: completed, skillProgress: SkillLessonProgress.forNode(node))`.
  It also prefetches open nodes' lessons, finds the active node for the
  jump button, and counts completed nodes for the section header.
- **F3** `SkillPathNode` maps a node onto the design system's `PathNode`
  (ring from `isPartlyDone`, "Continue"); `PathNode` draws a "Lv N"
  crown badge (`_CrownBadge`).
- **F4** Tests find a node by `SkillPathNode.node.title`
  (`test/helpers/skill_path.dart`).

### Decisions

- **D1 Model.** `SkillLesson(id, title, done)`; `SkillTreeNode.lessons`
  (default empty), read from `lessons` and kept in `toJson` / `fromJson`.
- **D2 Stops.** `PathStop` is one bubble: its skill, the lesson to start,
  its title, its state, whether it is a lesson stop and the first of its
  skill. `SkillTreeResponse.stopsIn(category)` gives one stop per lesson
  for a skill with lessons, else one per skill (`PathStop.ofSkill`, as
  today). Lesson states: locked skill, all locked; completed skill, all
  completed; active skill, done ones completed, the first not done
  active, later ones locked.
- **D3 Path.** `_CategoryNodes` draws stops; a lesson stop that is the
  first of its skill has the skill label above it (`PathSkillLabel`:
  the title, read as a heading, and the crown badge, made public as
  `PathCrownBadge`, when the skill is completed). The zig-zag index runs
  over all stops of the section. The section header counts completed
  stops of all stops. The jump button's active stop is the first active
  stop.
- **D4 Taps.** `showStopPopover`: a skill stop is `showSkillPopover` as
  today; a lesson stop is titled with the lesson, with "Ready when you
  are." / Start (active), "Finish the lesson above to unlock this one."
  (locked in an active skill), "Finish the skills above to unlock this
  one." (locked skill), the completed-skill review note / Review, or
  "You've done this lesson. Play it again any time." / Start (done in an
  unfinished skill). The lesson started is the stop's; `isReview` is the
  skill being completed; `skillProgress` only for a skill stop. Prefetch
  and the download note use the stop's lesson.
- **D5 No parts.** Lesson stops get no ring and no "Continue"; with no
  `skillProgress` the summary shows no skill-progress card (the level-up
  sheet still names the skill unlocked).
- **D6 Strings.** `finishLessonAbove`, `lessonDonePlayAgain` and
  `inSkill` (the bubble's screen-reader phrase) in English, Amharic and
  Afaan Oromo.

### Deliverables

- `skill_tree.dart` (lessons, stops), `http_lesson_api.dart`,
  `skill_path_node.dart`, the dashboard, `path_node.dart` (public badge),
  arb files and generated localizations, the test helper
- Tests: the model (parse, save and read back, stops for each skill
  state, a skill without lessons); the dashboard (a bubble per lesson,
  labels, crown, popovers, the tapped lesson starts, review, no ring, a
  tree without lessons as today)

### Acceptance Criteria

- [x] A skill with N lessons shows N bubbles under its label
- [x] Lesson states and popovers as in D2 and D4; the tapped lesson starts
- [x] No ring, "Lesson N of M" or skill-progress card with lesson bubbles
- [x] A tree without lessons looks as before; saved copies keep lessons
- [x] `flutter analyze` clean; `flutter test` passes, apart from the
  e2e suite that needs a running backend

## Implement (2026-10-06T09:20:00Z)

- `shared/models/skill_tree.dart`: `SkillLesson(id, title, done)`;
  `SkillTreeNode.lessons`, read and saved with the node; `PathStop`
  (`ofSkill`, `ofLessons`, `isReview`, `isDoneInUnfinishedSkill`,
  `isPartlyDone`) and `SkillTreeResponse.stopsIn(category)`.
- `http_lesson_api.dart` reads `lessons` (none from an older backend).
- `skill_path_node.dart`: `SkillPathNode` draws a `PathStop` (no ring,
  "Continue" or crown on a lesson bubble; the screen-reader phrase names
  its skill); `PathSkillLabel` (title as a heading, the crown badge once
  completed); `showStopPopover` with the lesson states of D4, falling back
  to `showSkillPopover` for a whole-skill bubble.
- `path_node.dart`: the crown badge is public as `PathCrownBadge`.
- Dashboard: stops per section; the label above each skill's first
  lesson; the zig-zag over all stops; the header counts stops; the jump
  button's active stop; prefetch and the download note per stop's
  lesson; a tap starts the stop's lesson, a review when its skill is
  completed, with no `skillProgress` for a lesson bubble.
- Strings `finishLessonAbove`, `lessonDonePlayAgain`, `inSkill` in
  English, Amharic and Afaan Oromo; localizations regenerated.
- Deviation: none.

## Test (2026-10-06T09:32:00Z)

- `test/shared/models/path_stops_test.dart` (7): lessons read, saved and
  read back; none from an older copy; a stop per lesson in order with the
  first carrying the label; locked and completed skills; an active skill
  (done, current, waiting); a lesson done out of order; a skill without
  lessons as one stop.
- `test/features/lesson/screens/path_lesson_nodes_test.dart` (6): a
  bubble per lesson under three labels, the crown on the label, no ring,
  the header counting lessons; each lesson's state and one Start bubble;
  a tree without lessons as before ("Lesson 2 of 3"); each popover
  (current, locked in the skill, locked skill, done, review); the tapped
  lesson starts with no skill progress; a done lesson plays again and a
  completed skill's lesson is a review.
- `http_lesson_api_test.dart`: lessons read into stops; none in an older
  response.
- The screen sweep's tree now has lessons, so the labels and crowns are
  checked at every size, theme and language.
- Updated for the new type: `skill_lesson_progress_test.dart`,
  `dashboard_section_header_test.dart`, `test/helpers/skill_path.dart`.

Results: `flutter analyze` clean; `flutter test` 3501 passed, 7 failed,
all 7 in `http_auth_api_e2e_test.dart`, which needs a backend running on
localhost:8000 (unrelated to this bolt).
