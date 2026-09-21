---
id: 039-admin-audio-ui
unit: 002-content-admin-web
intent: 017-content-admin-web
type: simple-construction-bolt
status: planned
stories:
  - 004-audio-record-upload-link
created: '2026-09-22T10:00:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 036-admin-audio-api
  - 037-admin-web-shell
enables_bolts: []
requires_units: []
blocks: false
---

# Bolt: 039-admin-audio-ui

## Overview

Record, upload or link audio.

## Objective

An admin records, uploads or links a clip for a listening exercise, and it plays in the app on a phone.

## Stories Included

- **004-audio-record-upload-link** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `036-admin-audio-api`
- `037-admin-web-shell`

### Enables
- None

## Notes

Blocked for its final manual check until the R2 public URL serves files (currently 404).
