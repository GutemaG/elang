---
intent: 018-mobile-design-system
phase: inception
status: complete
created: '2026-09-24T12:00:00Z'
updated: '2026-09-24T12:55:00Z'
---

# Requirements: Mobile Design System

## Intent Overview

Every screen of the Flutter app looks and behaves the same way: the same page
background, cards, shadows, buttons, sheets, prompts and answer tiles, drawn by
one set of reusable components rather than rebuilt on each page. The result
should also be more attractive than today, following the Stitch mockups and,
where they have nothing to show, well-regarded designs from other apps.

**Why now.** The colour, spacing and type tokens already exist
(`lib/shared/theme/`), and almost no screen hard-codes a hex value. But each
screen composes its own cards, shadows, sheets and prompts, so the result still
differs from page to page:

- **Cards**: four border colours, 1-4 px wide, with no shadow, a 3 px shelf, a
  4 px shelf, or a blurred shadow; radii of 16, 20, 24 and 32.
- **Answer tiles**: `ChoiceTile`, the match-pairs chip and the word-bank chip
  are three near-copies, and their state tints (`#FFF7ED`, `#E8F8F0`,
  `#FDF0EE`) are pasted into two files.
- **Buttons**: `TactileButton` with colours passed in by hand on every use,
  plus plain Material `TextButton`s in nine places.
- **Sheets**: shape, background and header rebuilt in each of five sheets;
  the settings sheet and two dialogs use Flutter's defaults.
- **Question prompts**: four different prompt styles across five question
  types.
- **Font**: Plus Jakarta Sans is named but not bundled, so Android and iPhone
  each fall back to their own system font.

**Design references.**
- Tokens and rules: `stich-screens/extracted/stitch_ethiopian_language_learning_app/highland_pulse/DESIGN.md`.
- Composition: the Stitch mockups beside it (`*/screen.png` and `*/code.html`):
  splash, onboarding, language, daily goal, sign-in, dashboard, lesson
  complete (2), level-up modal and out-of-beans modal. They add details
  DESIGN.md only hints at, for example:
  - shadows made of a solid shelf plus a faint soft shadow
    (`0 4px 0 #EDE5D8, 0 4px 16px rgba(35,26,17,.08)`)
  - a faint diagonal lattice on the dashboard background
  - a Tibeb-stripe accent on featured cards and the modal footer
  - tinted stat cards
  - white secondary buttons with a coloured shelf
- **There are no mockups** for the lesson and its question types, settings,
  downloads or the course picker. For those, reference designs are found and
  studied first (FR-11).

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Every page looks consistent | No screen, sheet or question type draws its own card, shadow, button, sheet, prompt or answer tile. An automated rules test (NFR-1) enforces this | Must |
| The app looks polished and attractive | Every screen matches its Stitch mockup, or the reference design recorded for it, side by side in the gallery and on a phone | Must |
| New screens and question types are fast to build | Spell-from-tiles (bolt 033) is built only from shared components, with no new decoration code | Must |

---

## Functional Requirements

### FR-1: Complete design tokens
- **Description**: `lib/shared/theme/` holds every value a component needs.
  - **Colours**: the existing tokens, plus:
    - the answer-state tints: selected `#FFF7ED`, correct `#E8F8F0`, incorrect `#FDF0EE`, chosen option `#F0F7F2`
    - the tile border and shelf: `#E5DDD0` and `#D5CCBD`
    - the secondary button shelf: `#C77317`
    - the locked-node colours: `#E8DFD3` face, `#BAAFA1` icon
    - the active-node shelf: `#C47318`
    - the streak, gem and XP accents: `#FF5A1F`, `#10B981`, `#0EA5E9`
    - the muted text colour: `#786A5E`
    - the track colour: `#E2D9CC`
  - **Shadows** (`AppShadows`):
    - a shelf of any colour and depth
    - card, tile and button shadows, each a shelf plus a faint soft shadow as in the mockups
    - the overlay shadow (`0 16 32 -8 rgba(43,33,24,.16)`)
    - the celebration glow (`0 0 20 rgba(224,135,34,.35)`)
  - **Radii**: tile = 20 and card = 24 are added to `AppRadii`.
  - **Motion** (`AppMotion`): press 100 ms, state change 150 ms, shake 400 ms, and their curves.
- **Acceptance Criteria**:
  - Every value above exists as a named token.
  - No file outside `lib/shared/theme/` contains a `Color(0x…)` literal, a numeric `BorderRadius.circular(…)` or a hand-built `BoxShadow` (NFR-1).
- **Priority**: Must

### FR-2: Buttons
- **Description**: One `AppButton` with these variants:
  - **primary**: green face, dark-green shelf
  - **secondary**: white face, coloured border and shelf, as in "Review Mistakes" and "Practice for Free Beans"
  - **accent**: gold face and shelf, as in "Refill with Amole"
  - **destructive**: terracotta face and shelf
  - **text**: a flat link for Skip, Cancel, "Not now" and "I'll do it later"

  Each variant has:
  - an optional leading icon, and an optional trailing icon or badge (e.g. "350 Amole")
  - full width or hug-content sizing
  - disabled and loading states
  - the press effect (moves down by the shelf depth, and the shelf flattens)

  There is also one `AppIconButton` for close, back and similar icon actions: round, on a soft surface, as in the out-of-beans mockup.
- **Acceptance Criteria**:
  - Every button in the app is an `AppButton` or `AppIconButton`.
  - No `TextButton`, `ElevatedButton`, `FilledButton`, `OutlinedButton` or bare `IconButton` exists outside `lib/shared/widgets/`.
  - Every button's tap target is at least 48×48.
  - A disabled or loading button ignores taps.
  - A loading button keeps its size.
- **Priority**: Must

### FR-3: Page shell and backgrounds
- **Description**: One `AppPage` that every full screen uses. It provides:
  - **The background**, in one of three styles:
    - **plain**: cream `#FFF8F5`
    - **patterned**: cream with the faint diagonal lattice from the dashboard mockup
    - **celebration**: cream with a soft radial glow behind the hero, from the lesson-complete mockup
  - the safe area and the 20 px side margins
  - **An optional top bar**: leading close or back, a centred title or logo, and trailing actions or stat pills
  - **An optional bottom action dock** pinned above the safe area, holding the page's main buttons
  - scrolling content between the top bar and the dock
  - an optional Tibeb stripe (a green, gold and terracotta band) as a footer accent
- **Acceptance Criteria**:
  - Every screen in FR-8 is built on `AppPage`.
  - No screen sets its own `Scaffold` background colour, safe area or side margins.
  - The same kind of screen always gets the same background: onboarding and settings are plain, the dashboard is patterned, and lesson-complete and level-up are celebration.
- **Priority**: Must

### FR-4: Cards and surfaces
- **Description**:
  - **`AppCard`**: DESIGN.md "Tactile Level 1", with a white face, 2 px border, 24 px radius, and a shelf plus soft shadow. It has these options:
    - a **tone** (neutral, primary, secondary or tertiary) that tints the border and shelf, as in the lesson-complete stat cards
    - an optional Tibeb stripe along the top edge, as in the milestone and refill-timer cards
    - an optional tap action with the press effect
    - compact and regular padding
  - **Built on `AppCard`:**
    - **`StatCard`**: icon circle, big value, label and an optional ribbon ("+1 TODAY")
    - **`InfoBanner`**: a tinted pill with an icon and a message, e.g. "Daily goal complete"
    - **`ListRow`**: icon, title, subtitle and trailing control, for settings and downloads
    - **`SectionHeader`**: the heading above a group of rows or cards
- **Acceptance Criteria**:
  - Every card-like container in the app is one of these.
  - No screen builds a `BoxDecoration` with a border, shadow or radius of its own.
- **Priority**: Must

### FR-5: Sheets and dialogs
- **Description**:
  - **`showAppSheet()`**: one bottom sheet, with a 32 px top radius, the cream background, a drag handle and the warm backdrop.
  - **`showAppDialog()`**: for yes/no confirmations.
  - **`SheetHero`**: the content layout both of them use:
    - an illustration circle with a soft glow and an optional badge (e.g. "0/5")
    - a title coloured by tone
    - an optional second-language line (e.g. "ቡና አለቀ!")
    - the body text
    - an action stack: primary, then secondary, then a text link
- **Acceptance Criteria**: These all use `showAppSheet` or `showAppDialog` with `SheetHero`:
  - the exit-lesson, level-up, review-skill and out-of-beans sheets
  - the course picker
  - the settings daily-goal sheet
  - the settings and downloads confirmation dialogs

  No `showModalBottomSheet` or `showDialog` call exists outside `lib/shared/widgets/`.
- **Priority**: Must

### FR-6: Status and feedback pieces
- **Description**:
  - **`StatPill`**: streak, beans (hearts), gems and XP. A translucent white pill with a tinted border and a coloured icon, as in the dashboard HUD.
  - **`CountBadge`** and **`RibbonBadge`**: e.g. "3/5 Completed" and "+1 TODAY".
  - **`AppProgressBar`**: a sunken track with a fill, an optional gradient and an optional label.
  - **`IconBadge`**: a round tinted circle holding an icon.
  - **`EmptyState`, `ErrorState`, `LoadingState`**:
    - illustration circle, title, text and an optional action
    - used for "You're offline", "Couldn't load this lesson" and the empty downloads list
  - **`SyncStatusBanner`**: restyled onto `InfoBanner`.
- **Acceptance Criteria**:
  - The dashboard header, lesson header, lesson complete, out-of-beans and downloads screens show stats, progress and empty or error states only through these.
  - `LinearProgressIndicator` and `CircularProgressIndicator` appear only inside them.
- **Priority**: Must

### FR-7: Question-type kit
- **Description**: Shared pieces that every question type is built from:
  - **`ExerciseLayout`**: the same frame for every question type:
    - a top bar (close, progress bar, beans)
    - the prompt
    - a scrolling answer area
    - an `AnswerActionBar` docked at the bottom
  - **`QuestionPrompt`**: one prompt style, replacing today's four:
    - the instruction line (e.g. "Complete the sentence")
    - the question in large bold type
    - an optional translation line
    - an optional speaker chip that plays the prompt's audio
    - an optional pronunciation line in muted `body-sm`, as DESIGN.md asks for under Fidel
  - **`AnswerTile`**: one tile for all answers:
    - **states**: idle, selected, correct, incorrect, used (dimmed in the word bank) and disabled
    - **shapes**:
      - **row**: multiple choice, listening and gap-fill
      - **pill**: word bank and spell tiles
      - **grid cell**: match pairs
    - a check or cross icon on correct and incorrect
    - the shake on incorrect
  - **`AudioPlayButton`**: a big tactile round button with a shelf and a "playing" state.
  - **`AnswerSlotLine`**: the line the built sentence sits on (word bank, spell tiles), and the gap in a gap-fill sentence.
  - **`AnswerActionBar`**: the Check and Continue buttons. After grading, it shows a tinted feedback panel ("Correct!" or "Not quite") above Continue, in green or terracotta.
- **Acceptance Criteria**:
  - The five question types (multiple choice, listening, sentence construction, match pairs and gap fill) are built only from these pieces.
  - `ChoiceTile`, `_MatchPairsTileChip` and `_WordChip` are gone. Their behaviour, including grading on tap, the shake and the dimmed used words, is kept exactly.
  - Every question type has the same top bar, prompt style, side margins, tile spacing and action bar position.
- **Priority**: Must

### FR-8: Every screen moves onto the shared components
- **Description**: These screens are rebuilt from FR-2 to FR-7, matching their mockup, or their FR-11 reference where there is no mockup:
  - splash, onboarding carousel, language selection, daily goal and sign-in
  - the skill-tree dashboard, with its header, category banner, path nodes and course picker
  - the lesson and its five question types
  - the mistake-review card, the lesson-complete screen and every lesson sheet
  - settings and download management
  - the home placeholder
- **Acceptance Criteria**:
  - Each screen passes the rules test (NFR-1).
  - Each screen matches its reference, checked side by side in the gallery and on a phone.
  - Every existing behaviour test still passes. Tests change only where they found a widget by a type that has been replaced, and the change keeps what they check.
- **Priority**: Must

### FR-9: Bundled fonts
- **Description**:
  - **Plus Jakarta Sans** is bundled (weights 400, 500, 700 and 800, SIL Open Font License).
  - **Noto Sans Ethiopic** is bundled as its fallback, so Amharic Fidel uses the same font on every device.
  - Text in Ethiopic script gets the 15-20% extra line height DESIGN.md asks for, so vowel marks are never clipped.
  - Both fonts work offline, with no `google_fonts` download at run time.
- **Acceptance Criteria**:
  - Latin and Fidel text use the bundled fonts on both Android and iPhone.
  - A Fidel prompt in a tile shows no clipped marks at text scales 1.0 and 1.3.
- **Priority**: Must

### FR-10: Component gallery
- **Description**: A gallery screen that is only reachable in debug builds. It shows:
  - every token (colours, shadows and radii)
  - every component in every state and variant, with sample Latin and Fidel text

  It is where a design is checked against its reference.
- **Acceptance Criteria**:
  - Every component from FR-2 to FR-7 appears in the gallery with all its states.
  - The gallery cannot be opened in a release build.
  - A widget test builds the whole gallery at 360 px and at 430 px width with no overflow.
- **Priority**: Must

### FR-11: Every design follows a reference
- **Description**: Before a component or screen is built, its reference design is chosen and written into its story:
  - the Stitch mockup, when there is one
  - otherwise at least one design from another well-regarded app or design system, found and studied first. For example:
    - Duolingo for the lesson, question types and answer feedback
    - Material 3 or popular Dribbble and Mobbin patterns for settings, lists and dialogs

  The story records what was taken from it (layout, spacing, emphasis and states) and how it was adapted to the Highland Pulse tokens.
- **Acceptance Criteria**:
  - Every component and screen story names its reference and what was taken from it.
  - No other product's logo, icons or illustrations are copied. Only layout and interaction patterns are borrowed.
- **Priority**: Must

---

## Non-Functional Requirements

### NFR-1: Consistency is enforced, not just intended
| Requirement | Metric | Target |
|-------------|--------|--------|
| Rules test | A test scans `lib/` and fails on any `Color(0x…)` outside `lib/shared/theme/`. Outside `lib/shared/`, it also fails on a hand-built `BoxShadow`, a numeric `BorderRadius.circular`, a Material button, `showModalBottomSheet`/`showDialog`, or a `Scaffold` background | 0 violations |
| One source per decision | Each colour, shadow, radius and duration is defined once | 0 duplicated literals |

### NFR-2: Accessibility
| Requirement | Metric | Target |
|-------------|--------|--------|
| Tap targets | Minimum size of every tappable component | ≥ 48×48 dp |
| Contrast | Body text against its background | ≥ 4.5:1 |
| Contrast | Large text and icons | ≥ 3:1 |
| Text scaling | Gallery and every screen at 1.3× text scale | No overflow |
| Screen readers | Semantics labels, button and selected flags | Kept on every migrated widget |
| Reduced motion | When the system asks for less motion | No shake or press movement |

### NFR-3: Performance and size
| Requirement | Metric | Target |
|-------------|--------|--------|
| Smooth pages | The patterned background and shadows while scrolling the dashboard in profile mode | No dropped frames; the pattern repaints only on resize |
| App size | Growth from the bundled fonts | ≤ 2 MB |

### NFR-4: Layout
| Requirement | Metric | Target |
|-------------|--------|--------|
| Phone widths | Every screen and the gallery at 360×640 and 430×932 | No overflow, no horizontal scroll |

### NFR-5: No behaviour change
| Requirement | Metric | Target |
|-------------|--------|--------|
| Regression safety | Existing Flutter test suite | 100% pass after every bolt |
| Analysis | `flutter analyze` | 0 issues |

---

## Constraints

### Technical Constraints

**Project-wide standards**: Required standards will be loaded from memory-bank standards folder by Construction Agent

**Intent-specific constraints**:
- Only the Flutter app (`lib/`, `test/`, `pubspec.yaml`, `assets/`) changes. The backend and the admin site do not.
- Behaviour does not change: lesson grading, navigation, sync, sign-in and sounds stay as they are. One addition is allowed: FR-7's feedback panel shows "Correct!" or "Not quite" from the grade the controller already has.
- Components live in `lib/shared/widgets/`, and the question kit in `lib/features/lesson/widgets/exercise/`. Existing names (`TactileButton`, `SelectableOptionCard`) may stay as thin wrappers, or be replaced along with their tests.

### Business Constraints
- Screens move over in bolts, and the app works and looks whole after every bolt.

---

## Out of Scope

- Dark mode, tablet layouts and landscape.
- New mascot illustrations or other artwork. The existing images are placed with the new components, and no new art is drawn.
- New features, such as the bottom navigation tabs (Practice, Leaderboard, Profile) seen in the mockups, or new stats.
- The spell-from-tiles screen itself. It stays bolt 033, built afterwards on FR-7.
- The backend and the admin site.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| DESIGN.md and the Stitch mockups are the visual standard (Checkpoint 1: 1a) | Screens are unified to the wrong look | Each bolt's first stage shows the gallery before screens change |
| Plus Jakarta Sans and Noto Sans Ethiopic may be bundled (both SIL OFL) | A licence problem | Keep the OFL text next to the font files |
| Skip, Cancel and "Not now" become text links (Checkpoint 1: 2a). Real alternative actions use the secondary button, as in the mockups | Mixed styles for similar actions | The gallery shows when each is used |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Look standard | User | 2026-09-24 | Resolved: DESIGN.md plus the Stitch mockups (1a) |
| Secondary actions | User | 2026-09-24 | Resolved: flat text links (2a) |
| Scope | User | 2026-09-24 | Resolved: every screen (3a) |
| Font | User | 2026-09-24 | Resolved: bundle Plus Jakarta Sans and Noto Sans Ethiopic (4a) |
| Verification | User | 2026-09-24 | Resolved: debug gallery plus widget tests, no golden tests (5a) |
| Reference designs | User | 2026-09-24 | Resolved: every design follows a fetched reference (FR-11) |
