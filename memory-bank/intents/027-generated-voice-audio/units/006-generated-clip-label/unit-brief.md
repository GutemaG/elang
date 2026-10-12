---
unit: 006-generated-clip-label
intent: 027-generated-voice-audio
unit_type: full-stack
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-12T09:55:00Z'
updated: '2026-10-12T09:55:00Z'
---

# Unit Brief: Generated Clip Label

## Purpose

Make it easy to see which stored clips were generated, and by which
voice. Generated items can then be checked by a native speaker before
they are marked Reviewed.

## Scope

### In Scope
- **Backend:** an optional `source` on the three presign routes (lesson
  audio, Workbook and Sounds), checked against `^gen-(am|om)-[a-z0-9-]{1,40}$`.
  It is put at the start of the object name: `.../{source}-{hex}.{ext}`.
- **Admin uploaders:** `uploadClip`, and the Workbook and Sounds
  uploaders, accept and pass `source`. The Generate panel passes
  `gen-{voiceId}`.
- **Current clip:** `CurrentClip` recognises the name and shows a
  "Generated · {Name}" pill.
- Tests on both sides.

### Out of Scope
- Database columns, and relabelling clips stored before this.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-21 | Generated-clip label | Could |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 021-generated-clip-label | A stored clip says it was generated, and by whom | Could | Planned (bolt 099) |

### 021-generated-clip-label (FR-21)

**As an** admin, **I want** generated clips marked, **so that** I know
which ones a native speaker should check.

- [ ] A presign with `source: "gen-om-obse"` gives a key like
  `om/{lesson}/gen-om-obse-1a2b3c4d5e6f.m4a`. Without `source`, keys are
  unchanged.
- [ ] A `source` that doesn't match the pattern gets 422 on `source`.
- [ ] A clip kept from the Generate tab is stored with its source tag.
  Record and Upload never send one.
- [ ] The current clip shows a "Generated · Obse" pill, with the tooltip
  "Made with Addis AI".
- [ ] The name is the voice ID's first word after the language,
  capitalised: `am-yohanes-calm` → "Yohanes".
- [ ] Clips with other names show no pill.

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| 005-generate-tab | The panel that passes the tag |

### Depended By
None.

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 099-generated-clip-label | simple-construction-bolt | 021 | Source tag and label |
