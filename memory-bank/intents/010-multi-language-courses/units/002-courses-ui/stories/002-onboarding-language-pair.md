---
id: 002-onboarding-language-pair
unit: 002-courses-ui
intent: 010-multi-language-courses
status: complete
priority: must
created: '2026-09-20T13:10:00Z'
assigned_bolt: 026-course-picker-ui
implemented: true
---

# Story: 002-onboarding-language-pair

## User Story

**As a** new learner who may not speak English
**I want** to say which language I speak and which I want to learn
**So that** I start on a course I can actually understand

## Acceptance Criteria

- [ ] **Given** onboarding, **When** the language step shows, **Then** it asks "I speak" and "I want to learn" from the course list
- [ ] **Given** the spoken language is Amharic, **When** the learning options show, **Then** Afaan Oromo is offered (and the reverse), with no English needed
- [ ] **Given** a pair with no available course, **When** shown, **Then** Continue is disabled with a coming-soon message
- [ ] **Given** the user completes signup, **When** they reach the dashboard, **Then** the chosen course is active
- [ ] **Given** the pending selection, **When** it is stored, **Then** it holds both languages and survives an app restart during onboarding
- [ ] **Given** existing onboarding tests, **When** the suite runs, **Then** they are updated and pass

## Technical Notes

- Extends `PendingOnboardingSelection` and the signup call. Interface stays English.

## Dependencies

### Requires
- `002-active-course-per-user` (signup with a pair)

### Enables
- `004-multi-course-end-to-end-verification`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Same language chosen for both | Not selectable |
| Course list unreachable during onboarding | Falls back to a message and retry; no silent default |

## Out of Scope

- Translating onboarding text
