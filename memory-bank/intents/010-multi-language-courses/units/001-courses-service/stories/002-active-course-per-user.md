---
id: 002-active-course-per-user
unit: 001-courses-service
intent: 010-multi-language-courses
status: complete
priority: must
created: '2026-09-20T13:00:00Z'
assigned_bolt: 024-courses-service
implemented: true
---

# Story: 002-active-course-per-user

## User Story

**As a** Buna learner
**I want** my chosen course saved on my account
**So that** it is still active after a restart or on another device, and a new account starts on the pair I picked

## Acceptance Criteria

- [ ] **Given** an authenticated user, **When** they switch to an available course, **Then** the new active course is returned and remains active after logout and login
- [ ] **Given** a `coming_soon` or unknown course id, **When** the user tries to switch, **Then** the request fails with a clear error and the active course is unchanged
- [ ] **Given** an existing user, **When** the migration has run, **Then** their active course is English to Amharic
- [ ] **Given** signup with a language pair (for example spoken Amharic, learning Afaan Oromo), **When** the account is created, **Then** the matching course is active
- [ ] **Given** signup with a pair that has no available course, **When** it is submitted, **Then** it is rejected and no account is created
- [ ] **Given** the active course and the old `selected_language`, **When** either is read, **Then** they do not disagree (handling decided in the ADR)

## Technical Notes

- Server validates the course id and availability (NFR-5).
- Extends the registration flow and pending onboarding selection to carry from-language.

## Dependencies

### Requires
- `001-course-model-and-migration`

### Enables
- `003-course-list-api`, `004-course-scoped-skill-tree-and-progress`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User switches to the course already active | Succeeds, no change |
| Concurrent switches from two devices | Last write wins |
| Active course later marked coming soon | Falls back to the user's previous available course or English to Amharic |

## Out of Scope

- Any client UI
