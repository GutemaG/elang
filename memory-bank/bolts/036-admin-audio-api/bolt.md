---
id: 036-admin-audio-api
unit: 001-content-admin-api
intent: 017-content-admin-web
type: simple-construction-bolt
status: planned
stories:
  - 005-audio-upload-and-link-api
created: '2026-09-22T10:00:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 034-admin-api-foundation
enables_bolts:
  - 039-admin-audio-ui
requires_units: []
blocks: false
---

# Bolt: 036-admin-audio-api

## Overview

Admin audio API.

## Objective

The backend issues presigned R2 upload URLs and checks pasted audio links, with no key ever leaving the server.

## Stories Included

- **005-audio-upload-and-link-api** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `034-admin-api-foundation`

### Enables
- `039-admin-audio-ui`

## Notes

The link check is an outbound fetch driven by user input: guard it against SSRF. Document the R2 bucket CORS rule.
