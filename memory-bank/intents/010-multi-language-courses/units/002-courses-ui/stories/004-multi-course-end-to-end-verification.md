---
id: 004-multi-course-end-to-end-verification
unit: 002-courses-ui
intent: 010-multi-language-courses
status: complete
priority: must
created: '2026-09-20T13:10:00Z'
assigned_bolt: 027-course-offline-and-verification
implemented: true
---

# Story: 004-multi-course-end-to-end-verification

## User Story

**As a** product owner
**I want** proof that switching courses works end to end and nothing regressed
**So that** more courses can be added by adding content

## Acceptance Criteria

- [ ] **Given** the seeded courses, **When** a lesson is completed in each new course, **Then** XP, Amole and streak update and vocab rows are created in that course
- [ ] **Given** words learned in an Afaan Oromo course, **When** they become due, **Then** they appear in Practice only while that course is active
- [ ] **Given** an Amharic speaker with no English, **When** they take Amharic to Afaan Oromo, **Then** prompts read in Amharic and answers in Afaan Oromo, and the reverse for Afaan Oromo to Amharic
- [ ] **Given** a lesson in a new course, **When** downloaded and taken offline, **Then** it completes and syncs
- [ ] **Given** the existing English to Amharic course, **When** the full backend and Flutter suites run, **Then** they pass with only fixture changes
- [ ] **Given** a manual on-device check, **When** done by the user, **Then** switching, restart persistence and offline switching are confirmed

## Technical Notes

- Add a backend integration test per new course pair; widget tests for the picker at 360dp and 320dp.
- Manual check requires a full rebuild (stop, `flutter run`).

## Dependencies

### Requires
- All other stories in this intent

### Enables
- None (terminal story)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Flaky `http_auth_api_e2e_test` | Rerun once; report if it persists |

## Out of Scope

- Native-speaker review of content (tracked as a release blocker, NFR-3)
