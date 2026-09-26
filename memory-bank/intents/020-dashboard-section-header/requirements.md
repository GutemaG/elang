---
intent: 020-dashboard-section-header
phase: construction
status: complete
created: '2026-09-26T07:35:10Z'
updated: '2026-09-26T09:48:49Z'
---

# Requirements: dashboard-section-header

## Intent Overview

Replace the dashboard's stack of coloured section banners with one fixed
section header. Only the learner's current section is shown in colour.
Section boundaries in the path become quiet grey text. A button brings
the learner back to their current lesson.

This follows Duolingo's path screen:

- **One coloured card, fixed under the stats bar,** always naming the
  unit you are in. It changes title and colour as you scroll from one
  unit into the next.
- **Units in the path are separated only by a grey title between two
  thin lines.**
- **A round arrow button in the corner** jumps back to where you are.

**Why:** today every section has its own full-colour banner. In the
path, they appear as several differently coloured blocks on one screen
(green, then brown), which the learner finds disturbing and not
beautiful.

**Type:** A change to an existing screen (brown-field): the skill-tree
dashboard, as intents 011 and 018 (bolt 047) left it.

**Process:** the user asked for a requirements list only, with no units,
stories or bolts. The work is built and checked directly against this
list (2026-09-26).

## Decisions from the user (2026-09-26)

| # | Question | Answer |
|---|----------|--------|
| 1 | Process | A new intent, a requirements list only, built directly |
| 2 | The header's look | A solid colour card like Duolingo's. Its colour changes with the section: green, then gold, then terracotta, in turn |
| 3 | The header's content | The section title, its subtitle, "N/M Completed" and the progress bar, as today's banners carry |
| 4 | Section boundaries in the path | Only the section's title, greyed out and in italics (the user's words), between thin lines |
| 5 | Jumping back | A button that takes the learner back to their current place |

## Reference Design

- **Duolingo's path screen** (the user's screenshot, 2026-09-26):
  - **The unit card:** a solid-colour card under the stats bar, with an
    eyebrow and a title. It is always visible, and its colour and text
    follow the unit on screen.
  - **Between units:** a grey unit title centred between two hairlines.
  - **The jump button:** a rounded square with an arrow at the bottom
    right, pointing towards the learner's current lesson.
- **Adapted to Highland Pulse:**
  - **The card's look:** the library's card with a shelf and a solid
    tone fill. The tones are Acacia green, Simien gold and Rift
    terracotta.
  - **The header's text:** title, subtitle, count and bar (decision 3)
    rather than Duolingo's eyebrow.
  - **The divider:** the title in italics, at the user's request.
  - **The jump button:** the library's round icon button.

## Functional Requirements

### FR-1: One fixed section header
- **Description:** a single section header is pinned directly under the
  dashboard's stats bar, from the moment the dashboard loads. It replaces
  the per-section banners that were pinned only while their own section
  scrolled past.
- **Acceptance Criteria:**
  - **One header only:** exactly one section header exists on the
    dashboard, whatever the number of sections, and none scrolls away.
  - **Its content:**
    - the section's title and subtitle, each on one line and ellipsised
    - "N/M Completed"
    - a progress bar of completed skills over skills in the section
  - **Its colour:** it is a solid card in the section's tone, with
    matching text and shelf. Sections take green, gold and terracotta in
    turn, counting from the first section.
  - **Its height:** fixed and the same for every section, so the page
    never jumps when the header changes. It is measured from the real
    text of every section's title and subtitle, as today's banner
    height is (no guessed constants).

### FR-2: The header follows the scroll
- **Description:** the header always shows the section the learner is
  looking at.
- **Acceptance Criteria:**
  - **At the top of the path,** it shows the first section.
  - **Scrolling down:** when a section's divider passes under the
    header, the header switches to that section's title, subtitle,
    progress and colour.
  - **Scrolling back up:** it switches back as soon as that divider
    comes out from under the header again.
  - **The change:** a short cross-fade. It is instant when the system
    asks for reduced motion.
  - **Performance:** the header rebuilds only when the section changes,
    not on every scroll frame (NFR-1).
  - **After a refresh or a course switch,** the header shows the first
    section of the loaded course, as the view scrolls back to the top.

### FR-3: Quiet section dividers in the path
- **Description:** inside the scrolling path, every section after the
  first begins with a divider instead of a banner.
- **Acceptance Criteria:**
  - **The divider:** the section's title, grey and in italics, centred
    between two thin grey lines. It has no card, colour, shelf or
    progress.
  - **Long titles** wrap to at most two lines, and the lines on either
    side shrink but never disappear.
  - **The first section has no divider:** the header already names it
    at the top.
  - **Screen readers** read a divider as a heading.
  - **One colour on screen:** apart from the path nodes' own states, the
    fixed header is the only coloured block in the path.

### FR-4: Jump to the current lesson
- **Description:** a round button in the bottom-right corner brings the
  learner back to their current lesson: the active skill node.
- **Acceptance Criteria:**
  - **When it shows:** only while the active node is out of view, either
    above the fixed header or below the bottom of the screen. It is
    hidden while the node is visible, and when the course has no active
    node.
  - **Its arrow** points up when the node is above the view, and down
    when it is below.
  - **Tapping it** scrolls smoothly until the active node is in view,
    centred under the header where possible. It scrolls on far enough
    that the node's section divider is tucked under the header, so the
    header names that section. The scroll is instant with reduced
    motion.
  - **Access:** at least a 48 px tap target, with the tooltip and
    spoken label "Jump to your current lesson".
  - **Placement:** it sits above the home indicator and never covers the
    course panel while that is open.

### FR-5: Everything else is unchanged
- **Acceptance Criteria:** none of the following change:
  - **The path:** its layout, zig-zag, node states, labels, download
    badges and taps.
  - **The page:** the practice card, the sync and offline banners, the
    stats bar and the course panel.
  - **Loading, error and signed-out pages.**
  - **The completed counts,** which are computed as today.

## Non-Functional Requirements

### NFR-1: Performance
- **Scroll smoothness:** it stays smooth. Working out the current section
  and whether the jump button shows costs a few position reads per frame
  at most, and causes a rebuild only when either result changes.

### NFR-2: Layout
- **No overflow:** the dashboard, with the header in each section's
  colour, shows no overflow at 320×568, 360×640 and 430×932, at 1.0× and
  1.3× text.

### NFR-3: Design system
- **Library only:** the solid header card, the divider and the jump
  button come from `lib/shared/`, as library pieces or variants with
  gallery cases.
- **Rules test:** it stays strict, with no allow-list.

### NFR-4: Accessibility
- **The header** is one heading node with the title, subtitle and
  progress.
- **Contrast:** all of its text, the subtitle included, meets 4.5:1 on
  each tone's fill (measured: 7.75 on green, 4.57 on gold, 7.77 on
  terracotta).
- **Reduced motion:** it turns off the header's fade and the jump
  button's scroll animation.

### NFR-5: Quality
- **Checks:** `flutter analyze` is clean, and the full suite passes.
- **Existing tests:** the dashboard tests that pinned intent 011's
  per-section banners are rewritten for the new behaviour. That change
  is expected, and is recorded as such.

## Constraints

- **Client only:** no backend or API change. Sections and progress come
  from the existing skill-tree response.
- **The header stays inside the dashboard's `CustomScrollView`,** as a
  pinned sliver under the stats bar, so the scroll-to-top on a course
  switch and the course panel keep working as they do.

## Assumptions

- **A section with no skills** still gets a divider, and the header
  shows "0/0 Completed" with an empty bar there, as the banner does
  today.
- **The learner's current place is the course's active node.** When
  every node is completed or locked, there is no active node and the
  jump button stays hidden.

## Out of Scope

- **Duolingo's extras:** the guidebook button, the "SECTION N, UNIT M"
  eyebrow, and unit illustrations.
- **Colouring the path nodes** in their section's tone.
- **Bottom navigation.**

## Delivery (2026-09-26)

Built directly against this list, with no units or bolts. Nothing is
committed yet.

- ✅ **FR-1, one fixed header:**
  - `CategoryBanner` is now the one pinned header: a filled `AppCard` in
    the section's tone, with onFill text and a bar made for a filled card.
  - Its height comes from `CategoryBanner.extentOfAll`, the tallest
    section, so it is the same for every section.
  - The title gets two thirds of the row, so a full name like
    "Foundations & Greetings" fits.
  - An opaque band behind the header stops the path peeking through the
    gaps around the card.
- ✅ **FR-2, the header follows the scroll:**
  - It switches when a divider's line (the middle of the divider) passes
    under the header's bottom edge, both ways.
  - The change is a 200 ms cross-fade, or instant with reduced motion.
  - The header rebuilds only when the section changes.
  - A course switch resets it to the first section.
- ✅ **FR-3, quiet dividers:**
  - `PathSectionDivider` in the library: a grey italic title between
    hairlines, at most two lines, each hairline at least 24 px.
  - Screen readers read it as a heading.
  - The first section has none.
- ✅ **FR-4, the jump button:**
  - A library `AppIconButton` at the bottom right, with an arrow up or
    down.
  - It shows while the active node's middle is out of view, and is
    hidden when there is no active node or the course panel is open.
  - Tapping it centres the node where possible, and scrolls far enough
    to tuck the node's divider under the header, so the header names its
    section. It is instant with reduced motion.
- ✅ **FR-5, everything else:** the path, practice card, banners, stats
  bar, course panel and status pages are unchanged.
- ✅ **NFR-2, layout:** no overflow at 320×568, 360×640 and 430×932, at
  1.0× and 1.3×, scrolled through every section.
- ✅ **NFR-3, design system:**
  - New library pieces, each with gallery cases:
    - `AppTone.fillShelf`
    - `AppCard.filled`
    - `AppProgressBar.onFilled`
    - `PathSectionDivider`
  - The rules test passes with no allow-list.
- ✅ **NFR-4, accessibility:**
  - The header is one heading with its title, subtitle and progress.
  - Its contrast is at least 4.57:1.
  - Reduced motion is honoured.
- ✅ **NFR-5, checks:**
  - `flutter analyze` is clean, and the full suite passes.
  - The tests that pinned intent 011's per-section banners are rewritten
    for the new behaviour: the scroll, categories and dashboard-kit tests.
  - New tests: `dashboard_section_header_test.dart`, plus library tests
    in `app_card_test.dart`.
- ⏳ **NFR-1, scroll smoothness on a device:** needs checking by hand in
  profile mode, like bolt 047's scroll check.
