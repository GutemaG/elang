---
id: 005-seed-curriculum-content
unit: 001-lesson-service
intent: 002-core-lesson-loop
status: complete
priority: must
created: '2026-09-15T18:00:00Z'
assigned_bolt: 004-lesson-content-service
implemented: true
---

# Story: 005-seed-curriculum-content

## User Story

**As a** developer/tester
**I want** a small, real, hand-authored Amharic curriculum seeded into the database
**So that** the full lesson loop can be exercised end-to-end without needing a full course

## Acceptance Criteria

- [ ] **Given** a fresh database, **When** the seed process runs, **Then** at least 2 skills exist, each with multiple lessons
- [ ] **Given** a seeded lesson, **When** its content is fetched, **Then** it contains a mix of all 3 supported exercise types (multiple-choice, listening, sentence-construction)
- [ ] **Given** the seeded content, **When** reviewed, **Then** it is real, correct English→Amharic vocabulary/phrases — not lorem-ipsum or placeholder text
- [ ] **Given** a listening exercise in the seed data, **When** its content is fetched, **Then** it includes a valid audio URL (hosted on Cloudflare R2 per system-context.md, or a documented local/dev equivalent for local testing)

## Technical Notes

- This is explicitly a proof-of-loop seed set, not a Phase 1 course — see requirements.md's Business Constraints.
- Audio asset production/upload to R2 for local dev vs. real deployment is a Technical Design/Construction detail; a documented workaround (e.g. a small set of dev-only audio files) is acceptable if real R2 credentials aren't available during Construction, mirroring how `001-auth-onboarding` treated missing real OAuth credentials as a non-blocking placeholder concern.
- Seed data should be idempotent (safe to re-run against a dev database) — an Alembic data migration or a dedicated seed script, per Technical Design.

## Dependencies

### Requires
- 001-serve-skill-tree-and-lesson-content (defines the schema this story seeds into)

### Enables
- All other stories in this unit (nothing is testable end-to-end without seed content)
- Frontend stories that need real content to develop/test against

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Seed script run twice against the same database | No duplicate rows, no crash (idempotent) |
| Seed content includes Amharic Fidel-script text | Rendered/stored correctly as UTF-8, matching the Highland Pulse design system's Ge'ez/Amharic typography notes |

## Out of Scope

- A complete Phase 1 course (this is a small proof set only)
- Any UI (owned by `002-core-lesson-loop-ui`)
