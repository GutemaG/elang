---
intent: 027-generated-voice-audio
phase: inception
status: units-decomposed
updated: 2026-10-12T09:55:00Z
---

# Generated Voice Audio - Unit Decomposition

## Units Overview

The work is split into six small units: three on the backend, two in the
admin, and one optional unit that touches both.

- Each unit has one or more small bolts.
- Stories are written inside each unit brief and numbered across the
  intent.

### Unit 1: 001-voice-settings-service

**Description:** The `voice_settings` table and its defaults, plus the
admin API that reads and changes them.

**Requirements:** FR-3, FR-4, FR-5 (the prefix rule; the catalog check
is added in bolt 092)

**Deliverables:**
- Domain constants: the supported languages and the default voices.
- The model, a migration and the repository.
- `GET /admin/voice/settings` and `PUT /admin/voice/settings/{language}`.
- Tests.

**Dependencies:** none.

**Estimated complexity:** S

### Unit 2: 002-addis-voice-client

**Description:** The settings and client for Addis AI, plus the catalog
and credit routes.

**Requirements:** FR-1, FR-2, FR-6, FR-7, and the catalog check of FR-5

**Deliverables:**
- `addis_*` settings and the `AddisVoiceClient`, with retries and typed
  errors.
- Tests that use a fake transport, so they need no network.
- `GET /admin/voice/voices` (cached) and `GET /admin/voice/usage`.
- The catalog check on `PUT /admin/voice/settings`.

**Dependencies:** `001-voice-settings-service`, for the catalog check
only.

**Estimated complexity:** M

### Unit 3: 003-voice-generation-api

**Description:** `POST /admin/voice/generate`, which returns mp3 bytes
for a text, gender and speed.

**Requirements:** FR-8, FR-9, FR-10, FR-11

**Deliverables:**
- A use case that resolves the voice and speed from the settings.
- The route, which returns `audio/mpeg` with headers that CORS exposes.
- The error mapping and the audit log.
- Tests.

**Dependencies:** `001-voice-settings-service` and
`002-addis-voice-client`.

**Estimated complexity:** S

### Unit 4: 004-voices-admin-page

**Description:** The Voices page: one card per language with voice
pickers, previews and speed, plus Save, Try it and the credit line.

**Requirements:** FR-12, FR-13, FR-14, FR-15

**Deliverables:**
- The route, the nav item, the page and its cards.
- The voice API helpers in the admin.
- Tests.

**Dependencies:** units 1, 2 and 3. Try it needs the generation route.

**Estimated complexity:** M

### Unit 5: 005-generate-tab

**Description:** The fourth tab, Generate, in `AudioField`, with its
controls, the clip editor, "Use this clip", and wiring into the
Workbook, Sounds and exercise forms.

**Requirements:** FR-16, FR-17, FR-18, FR-19, FR-20

**Deliverables:**
- The `voice` prop on `AudioField` and the `GeneratePanel`.
- The generate helper, the shared "configured" flag and the stored
  gender choice.
- The panel wired to `ClipEditor` and `ClipUploader`.
- Each caller passing its language and text.
- Tests.

**Dependencies:** `003-voice-generation-api`, and the settings read from
unit 1.

**Estimated complexity:** M

### Unit 6: 006-generated-clip-label (Could)

**Description:** Stored clips that were generated carry a source tag in
their name and show a "Generated · {Name}" label.

**Requirements:** FR-21

**Deliverables:**
- An optional `source` on the three presign routes.
- The uploaders pass it through.
- The current-clip label.
- Tests.

**Dependencies:** `005-generate-tab`.

**Estimated complexity:** S

## Requirement-to-Unit Mapping

- **FR-1** Connection settings → `002-addis-voice-client`
- **FR-2** Addis client → `002-addis-voice-client`
- **FR-3** Settings store → `001-voice-settings-service`
- **FR-4** Read settings → `001-voice-settings-service`
- **FR-5** Change settings → `001-voice-settings-service`; the catalog
  check is in `002-addis-voice-client`
- **FR-6** Voice catalog → `002-addis-voice-client`
- **FR-7** Credit → `002-addis-voice-client`
- **FR-8** Generate → `003-voice-generation-api`
- **FR-9** Text rules → `003-voice-generation-api`
- **FR-10** Error mapping → `003-voice-generation-api`, with the shared
  exceptions in `002`
- **FR-11** Audit log → `003-voice-generation-api`
- **FR-12** to **FR-15** → `004-voices-admin-page`
- **FR-16** to **FR-20** → `005-generate-tab`
- **FR-21** → `006-generated-clip-label`

## Unit Dependency Graph

```text
[001-voice-settings-service] ──┬──> [002-addis-voice-client] ──┐
                               │                               v
                               └──────────────────> [003-voice-generation-api]
                                                               │
                                     ┌─────────────────────────┤
                                     v                         v
                         [004-voices-admin-page]       [005-generate-tab]
                                                               │
                                                               v
                                                [006-generated-clip-label]
```

## Execution Order

| Order | Bolt | Unit | What it builds |
|---|---|---|---|
| 1 | 089-voice-settings-store | 001 | Table, migration, defaults and repository |
| 2 | 090-voice-settings-api | 001 | GET and PUT settings with the prefix rule |
| 3 | 091-addis-voice-client | 002 | Settings, client, retries and typed errors |
| 4 | 092-voice-catalog-and-usage | 002 | The voices and usage routes, and the catalog check on PUT |
| 5 | 093-voice-generate-api | 003 | The generate route, text rules, errors and log |
| 6 | 094-voices-page | 004 | Page, nav, cards and Save |
| 7 | 095-voices-page-try-and-credit | 004 | Previews, Try it, missing voices and credit |
| 8 | 096-generate-tab-controls | 005 | The tab and its controls, up to a playable take |
| 9 | 097-generate-tab-editor-and-use | 005 | Clip editor, Generate again and Use this clip |
| 10 | 098-generate-tab-wiring | 005 | Workbook, Sounds and exercise fields |
| 11 | 099-generated-clip-label | 006 | Source tag and label (Could) |

Bolts 094–095 and 096–098 can run in either order once bolt 093 is done.
