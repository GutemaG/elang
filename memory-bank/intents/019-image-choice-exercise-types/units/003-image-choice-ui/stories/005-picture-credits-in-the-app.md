---
id: 005-picture-credits-in-the-app
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
status: complete
priority: must
created: '2026-09-25T06:15:00Z'
assigned_bolt: 054-picture-offline-and-credits
implemented: true
---

# Story: 005-picture-credits-in-the-app

## User Story

**As the** owner
**I want** the sample pictures' authors and licences credited in the app
**So that** the app meets the pictures' licence terms

## Acceptance Criteria

- [x] **Given** settings, **When** opened, **Then** there is a "Licences" entry
- [x] **Given** the entry, **When** tapped, **Then** Flutter's licence page opens, listing the package licences and the picture credits
- [x] **Given** each credited picture, **When** listed, **Then** it shows the author, the source and the licence, from the committed credits file
- [x] **Given** the credits file, **When** a picture is added to it, **Then** the app lists it with no code change

## Technical Notes

- There is no licences page today (finding 2). Picture credits are registered with `LicenseRegistry.addLicense`, read from a bundled copy of the credits file.
- Bolt 049 moves settings onto the library; the entry uses whichever settings row exists when this bolt runs.

## Dependencies

### Requires
- 003-sample-picture-questions (unit 001, bolt 051): the credits file

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A CC0 picture | Listed, though its licence asks for no credit |

## Out of Scope

- Credits for pictures that admins upload later (their licensing is the author's responsibility)
