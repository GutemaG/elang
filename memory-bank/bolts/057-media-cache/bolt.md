---
id: 057-media-cache
unit: 002-offline-caching-and-sync-ui
intent: 003-offline-caching-and-sync
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-29T08:39:52Z'
started: '2026-09-29T08:39:52Z'
completed: '2026-09-29T09:18:55Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-29T08:44:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-29T09:09:51Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-29T09:18:55Z'
    artifact: implementation-plan.md
requires_bolts:
  - 054-picture-offline-and-credits
enables_bolts: []
requires_units: []
blocks: false
---

# Bolt: 057-media-cache

## Overview

A question's clip streams from R2 every time it plays, and pictures are
kept in memory only (asked 2026-09-29). Clips and pictures are kept on the
device after their first download, fetched ahead as soon as a lesson's
data arrives, and played from there.

## Objective

A question's audio starts at once when it appears, from the device, and
its pictures show without waiting, on every open after the first and in
most first opens too.

## Stories Included

None as separate files. The acceptance criteria are in
`implementation-plan.md` (one md per bolt).

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Dependencies

### Requires
- `054-picture-offline-and-credits` (pictures in downloaded lessons)

### Enables
- None

## Notes

The user's decisions (2026-09-29): pictures as well as audio; the dashboard
fetches the next lesson's media on mobile data too; the cache holds up to
500 MB across all courses, since a user can clear it.
