---
intent: 018-mobile-design-system
created: '2026-09-24T12:00:00Z'
completed: '2026-09-24T12:58:00Z'
status: complete
---

# Inception Log: mobile-design-system

## Overview

**Intent**: One set of reusable Flutter components (page background, cards,
shadows, buttons, sheets, question prompts, answer tiles) so every screen and
question type looks the same and nothing differs from page to page.
**Type**: refactoring (brown-field: the existing screens move onto shared
components; behaviour does not change)
**Created**: 2026-09-24

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ approved (Checkpoint 2) | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units.md, units/{unit-name}/unit-brief.md |
| Stories | ✅ | units/{unit-name}/stories/*.md |
| Bolt Plan | ✅ approved (Checkpoint 3) | memory-bank/bolts/042-049 |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 11 |
| Non-Functional Requirements | 5 (consistency, accessibility, performance and size, layout, no behaviour change) |
| Units | 3 |
| Stories | 17 |
| Bolts Planned | 8 (042-049) |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-design-foundation-ui | 8 | 042, 043 | Must |
| 002-question-kit-ui | 4 | 044, 045 | Must |
| 003-screen-migration-ui | 5 | 046, 047, 048, 049 | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-24 | Create a new intent for app-wide visual consistency | User: "everything should be consistent and it should not differ from page to page" | Yes |
| 2026-09-24 | DESIGN.md plus the Stitch mockups are the visual standard | Checkpoint 1: 1a | Yes |
| 2026-09-24 | Skip, Cancel and "Not now" become flat text links in one style | Checkpoint 1: 2a | Yes |
| 2026-09-24 | Every screen is in scope | Checkpoint 1: 3a | Yes |
| 2026-09-24 | Bundle Plus Jakarta Sans with a Noto Sans Ethiopic fallback | Checkpoint 1: 4a; the same font on every device | Yes |
| 2026-09-24 | Check with a debug-only gallery and widget tests, no golden tests | Checkpoint 1: 5a | Yes |
| 2026-09-24 | Requirements approved | Checkpoint 2: "1" | Yes |
| 2026-09-24 | Three units: library, question kit plus lesson screen, other screens | The library lands and is reviewed in the gallery before any screen changes; the kit's only consumer is the lesson screen | Yes |
| 2026-09-24 | The rules test lands first with an allow-list that only shrinks, emptied by bolt 049 | Keeps the suite green after every bolt (NFR-5) while blocking new violations | Yes |
| 2026-09-24 | Artifacts approved | Checkpoint 3: "1" | Yes |
| 2026-09-24 | Every design follows a reference: the Stitch mockup, or a fetched design from another app | User: "for every design try to fetch other design and follow to make it beautiful and attractive" | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete

## Next Steps

1. Begin Construction with unit `001-design-foundation-ui`, bolt `042-design-foundation`
2. Execute: `/specsmd-construction-agent --unit="001-design-foundation-ui" --bolt-id="042-design-foundation"`

## Dependencies

Bolt 033 (spell-from-tiles UI, planned) should be built on this intent's
question-type components.
