---
intent: 008-srs-and-practice
phase: inception
status: complete
created: '2026-09-17T16:40:00Z'
updated: '2026-09-17T17:10:00Z'
---

# Requirements: SRS & Practice

## Intent Overview

Add a retention engine: resurface vocabulary a user is weak on via spaced repetition (Leitner boxes), through a new Practice entry point that reuses the existing exercise-engine UI.

**Corrected during requirements-gathering by reading real source** — the original build prompt assumed partial groundwork existed ("`vocab_items` and `user_vocab_progress` exist in the schema... but there is no confirmation grading writes to it"). Neither table exists anywhere in this codebase; they are mentioned only aspirationally in `memory-bank/standards/data-stack.md` and `coding-standards.md`. `exercises` has no `vocab_item_id` column (confirmed against `database-schema.md`'s `exercises` table: `id, lesson_id, order_index, type, prompt, content, answer_key, created_at` — no vocab reference at all). This intent is **greenfield for its data model**, not a retrofit of an existing-but-unused link — the retrofit is only that *grading itself* (already shipped, `complete_lesson`) needs new side-effects, not that a dormant FK needs activating.

There is also no tabbed/bottom-navigation shell in the app today (`main.dart` is single-route, dashboard-first) — "a Practice tab" is a UI-structure decision for Technical Design, not an existing nav slot to plug into.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Give the app a mechanism to resurface weak vocabulary instead of pure forward progression | A vocab item a user got wrong resurfaces for review on a defined schedule | Must |
| Make the due-review count a visible, motivating entry point | Due-count badge visible and accurate | Must |
| Reuse the existing exercise-engine UI for practice sessions | Zero new exercise-rendering code | Must |

---

## Functional Requirements

### FR-1: Vocab Item Content Model
- **Description**: New `vocab_items` table (canonical word/phrase + translation, content — not per-user). New `exercises.vocab_item_id` nullable FK, since not every exercise type necessarily maps cleanly to one discrete vocab item on day one (e.g. `sentence_construction` may reference multiple items or none) — nullable, not required, avoids forcing every existing seeded exercise to be retrofitted with a vocab link before this ships.
- **Acceptance Criteria**:
  - `vocab_items` seeded with real content covering at least the existing seeded curriculum's exercises
  - Exercises that do reference a single clear vocab item are linked via `vocab_item_id`
  - No existing exercise/lesson/skill behavior changes for exercises with `vocab_item_id IS NULL`
- **Priority**: Must

### FR-2: Per-User Vocab Progress Tracking (retrofit of shipped grading)
- **Description**: New `user_vocab_progress` table (per-user, per-vocab-item: box level, `next_review_at`, last-seen). `complete_lesson` gains a side-effect: for every exercise in the completed lesson that has a `vocab_item_id`, insert a row on first appearance, update on every subsequent appearance.
- **Acceptance Criteria**:
  - A vocab item's first graded appearance for a user creates a `user_vocab_progress` row at box 1
  - Every subsequent graded appearance (in a lesson or in Practice, per FR-6) updates that row per the Leitner algorithm (FR-3)
- **Priority**: Must

### FR-3: Leitner-Box Spacing Algorithm
- **Description**: 5 boxes, intervals 1 → 3 → 7 → 14 → 30 days. A correct answer moves the item up one box (capped at box 5) and sets `next_review_at = now + that box's interval`. An incorrect answer resets to box 1, `next_review_at = tomorrow`.
- **Acceptance Criteria**:
  - Box transitions and interval math match the rule above exactly, including the box-5 ceiling (no box 6)
  - "Tomorrow" for an incorrect answer is a fixed 1-day interval, not box 1's own interval re-derived (both happen to be 1 day here, but the rule is stated independently so a future box-1-interval change can't silently break the incorrect-answer behavior)
- **Priority**: Must

### FR-4: Due-Items and Due-Count Endpoints
- **Description**: `GET` due items (`WHERE user_id = ? AND next_review_at <= now() ORDER BY next_review_at LIMIT N`) for session assembly, and a separate lightweight due-count endpoint for the UI badge.
- **Acceptance Criteria**:
  - Due-items returns items in ascending `next_review_at` order, capped at the requested limit
  - Due-count is cheap (a `COUNT`, not a full row fetch) and matches what the due-items query would return
- **Priority**: Must

### FR-5: Explicit Offline Behavior
- **Description**: Practice requires a decision, not an implicit gap. **Resolved (Checkpoint 1)**: Practice is disabled entirely when offline — no locally-computed due-set from a cached `user_vocab_progress` copy. Grading (via `complete_lesson`, per FR-2) already only happens for regular lessons through the existing offline-sync-queue path (`003-offline-caching-and-sync`); Practice sessions are not queued for later sync if started offline, because they aren't started offline at all.
- **Acceptance Criteria**:
  - The Practice entry point is visibly disabled (not hidden) when the device is offline, consistent with this app's existing "disable, don't hide" convention (`out_of_beans_sheet.dart`'s insufficient-Amole state, `005`'s notification toggle)
  - No offline queueing code is built for Practice completions
- **Priority**: Must

### FR-6: Practice Tab / Entry Point
- **Description**: A new UI entry point showing the due-count, launching a practice session assembled from due vocab items' linked exercises, reusing the existing exercise-engine widgets (`multiple_choice`, `listening`, `sentence_construction`, `match_pairs` — no new exercise-rendering code). Exact navigation mechanism (bottom nav tab vs. a dashboard card/button) is a Technical Design decision, since no tabbed shell exists today — read `main.dart`'s and the dashboard's real current navigation structure at Construction before choosing.
- **Acceptance Criteria**:
  - Due-count is visible before entering a session
  - A session only includes exercises linked to currently-due vocab items
  - Session completion writes through the same grading/XP path as a regular lesson where applicable (Amole triggers from intent `007`, if it has landed, apply consistently — Practice is not a second, inconsistent reward path)
- **Priority**: Must
- **Open question carried to Technical Design**: exact entry-point UI (tab bar vs. dashboard element) and exact session-assembly-to-completion wiring (does a Practice session produce a `LessonAttempt`-shaped record, or a new, smaller "practice attempt" record?) are not fixed here.

---

## Non-Functional Requirements

### Data Integrity
| Requirement | Standard | Notes |
|-------------|----------|-------|
| A vocab item's progress is never silently lost or double-updated by a retried/offline-synced completion | New | Must compose correctly with `003-offline-caching-and-sync`'s existing idempotent-replay mechanism — a delayed offline lesson sync must update vocab progress exactly once, same idempotency discipline as XP/Beans already have |

### Performance
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Due-count check is cheap enough to call on every dashboard load | New | `COUNT` query, indexed on `(user_id, next_review_at)` |

---

## Constraints

### Technical Constraints
- Zero regression to any existing lesson-completion, offline-sync, or exercise-rendering behavior for exercises with no `vocab_item_id`.
- No new exercise-rendering widgets — Practice must reuse `002-core-lesson-loop-ui`'s/`012-match-pairs-ui`'s existing widgets.
- Coordinate with intent `007-amole-currency` if it lands first, so Practice completions trigger Amole consistently rather than needing a second retrofit later.

### Business Constraints
- None identified beyond normal project pacing.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| Not every exercise needs a `vocab_item_id` on day one — a partial link (covering enough of the seeded curriculum to make Practice meaningful) is acceptable for Phase 1 | If Practice feels sparse, more exercises need linking later — additive work, not a rewrite (`vocab_item_id` is nullable) | Nullable FK, explicitly scoped in FR-1 |
| Practice sessions can reuse `complete_lesson`'s grading/XP path without needing a parallel "lesson" shell object | If a due-set doesn't map cleanly onto `Lesson`'s aggregate shape, a smaller dedicated completion path is needed instead | Flagged as an explicit open question in FR-6, not assumed away |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Offline behavior for Practice | User | Checkpoint 1 | **Resolved**: disabled entirely when offline, not computed from a cached copy |
| Practice entry-point UI (tab vs. dashboard element) | — | Technical Design | Not resolved here — no tabbed nav shell exists today; a real design choice once `main.dart`'s/dashboard's current navigation is read at Construction |
| Whether a Practice session completion is a `LessonAttempt`-shaped record or a new record type | — | Technical Design | Not resolved here |

---

## Dependencies

- Retrofits `complete_lesson` (`005-lesson-engagement-service`) with vocab-progress side-effects — same category of change as intent `007`'s Amole retrofit.
- Reuses (does not modify) the exercise-engine UI from `002-core-lesson-loop-ui`/`006-core-lesson-loop-ui`/`012-match-pairs-ui`.
- Should coordinate with, but does not hard-block on, `007-amole-currency` — sequenced after it by user preference.
- Composes with `003-offline-caching-and-sync`'s existing idempotent-replay mechanism for delayed lesson syncs.
