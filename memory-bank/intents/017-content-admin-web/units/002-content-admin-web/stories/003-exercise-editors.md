---
id: 003-exercise-editors
unit: 002-content-admin-web
intent: 017-content-admin-web
status: generated
priority: must
created: '2026-09-22T10:00:00Z'
assigned_bolt: 038-admin-exercise-editors
implemented: false
---

# Story: 003-exercise-editors

## User Story

**As a** Buna admin
**I want** a proper form for each exercise type
**So that** I can write and fix exercises without touching JSON

## Acceptance Criteria

- [ ] **Given** each of `multiple_choice`, `listening`, `sentence_construction`, `match_pairs`, `gap_fill` and `spell_tiles`, **When** an existing exercise is opened and saved unchanged, **Then** the server receives identical `content` and `answer_key`
- [ ] **Given** a choice-based type, **When** the admin marks a choice as correct, **Then** the answer key is set from it; no ids are typed
- [ ] **Given** a sequence type, **When** the admin arranges tiles in the correct order, **Then** the correct sequence is set from it, preserving repeated characters as distinct tiles
- [ ] **Given** a `422` from the server, **When** it names a field, **Then** the error shows next to that field
- [ ] **Given** a new exercise, **When** it is created, **Then** its type is chosen once and cannot be changed later

## Technical Notes

- One component per type behind a switch on `type`; TypeScript discriminated unions mirror the backend schemas.
- `spell_tiles` tiles are id-keyed for the same reason `016` gave: text is not identity.

## Dependencies

### Requires
- 002-content-tree-browser-and-editing
- 004-exercise-write-validation

### Enables
- 005-exercise-preview
