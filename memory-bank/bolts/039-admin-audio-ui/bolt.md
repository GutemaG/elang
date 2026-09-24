---
id: 039-admin-audio-ui
unit: 002-content-admin-web
intent: 017-content-admin-web
type: simple-construction-bolt
status: complete
stories:
  - 004-audio-record-upload-link
created: '2026-09-22T10:00:00Z'
started: '2026-09-24T09:10:00Z'
completed: '2026-09-24T09:35:41Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-24T09:20:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-24T09:17:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-24T09:35:41Z'
    artifact: test-walkthrough.md
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

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Dependencies

### Requires
- `036-admin-audio-api`
- `037-admin-web-shell`

### Enables
- None

## Notes

Complete. The manual checks (a real upload after Google sign-in, and playback on a phone) are left to the user; see `test-walkthrough.md`. Local development now stores uploads on the backend: `R2_ACCESS_KEY_ID` is commented out in `backend/.env` until R2 serves files.
