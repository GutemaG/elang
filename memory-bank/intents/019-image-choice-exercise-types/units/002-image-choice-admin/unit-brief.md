---
unit: 002-image-choice-admin
intent: 019-image-choice-exercise-types
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: stories-defined
created: '2026-09-25T06:15:00Z'
updated: '2026-09-25T06:15:00Z'
---

# Unit Brief: Image Choice Admin

## Purpose

Let a content admin build both picture question types in the admin site:
pick a picture, have it shrunk and uploaded, describe it, mark the right
one, and see the question as the learner will.

## Scope

### In Scope
- A picture module in `admin/src/`: file checks, shrinking, encoding and
  upload through the backend's link
- A picture-choices editor with 2 to 4 slots, used by both types
- Both types in "add exercise", the exercise form and the preview

### Out of Scope
- A shared picture library (answer 1b)
- Cropping or editing pictures in the browser

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-3 | Picture storage: the upload call | Must |
| FR-4 | Admin editors for both types | Must |

Security, accessibility (required alt text) and compatibility (admin
browsers) NFRs apply.

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 2 |
| Must Have | 2 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-picture-upload-with-shrinking | Pick a picture and have it shrunk and uploaded | Must | Planned |
| 002-picture-question-editors-and-preview | Build, check and preview both picture question types | Must | Planned |

---

## Dependencies

### Depends On
`001-image-choice-service` (bolt 050): the upload link and the content
shape.

### Depended By
None.

---

## Constraints

- Follows the admin site's existing editors, fields and tests; the audio
  field is reused as it is.
- Shrinking uses the browser's canvas. WebP where the browser can encode
  it, otherwise JPEG, lowering quality step by step to stay at or under
  300 KB.

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 052-image-choice-admin | simple-construction-bolt | 001, 002 | Admins can build and preview both types |
