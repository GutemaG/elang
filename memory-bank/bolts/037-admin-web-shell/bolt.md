---
id: 037-admin-web-shell
unit: 002-content-admin-web
intent: 017-content-admin-web
type: simple-construction-bolt
status: planned
stories:
  - 001-admin-web-scaffold-and-sign-in
  - 002-content-tree-browser-and-editing
created: '2026-09-22T10:00:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 035-admin-content-api
enables_bolts:
  - 038-admin-exercise-editors
  - 039-admin-audio-ui
requires_units: []
blocks: false
---

# Bolt: 037-admin-web-shell

## Overview

Admin web shell and content tree.

## Objective

An admin signs in to the new React site and browses, adds, renames, reorders and deletes sections, skills and lessons.

## Stories Included

- **001-admin-web-scaffold-and-sign-in** (Must)
- **002-content-tree-browser-and-editing** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `035-admin-content-api`

### Enables
- `038-admin-exercise-editors`
- `039-admin-audio-ui`

## Notes

First code in `admin/`. It also sets up the second Vercel project and adds the admin origin to CORS and to the Google OAuth client.
