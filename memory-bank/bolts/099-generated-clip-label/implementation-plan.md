---
stage: plan
bolt: 099-generated-clip-label
created: '2026-10-12T17:40:00Z'
---

## Implementation Plan: generated-clip-label

### Objective

Story 021 (FR-21, Could). A clip kept from the Generate tab is stored
under a name that starts with `gen-{voice}`, for example
`om/lesson-1/gen-om-obse-1a2b3c4d5e6f.mp3`. The current-clip panel
recognises that name and shows a **Generated · Obse** pill, so an
admin can see which clips a native speaker should still check. No
database change is needed.

### What the code says (checked before planning)

- **F1 Presign endpoints.** Three endpoints hand out upload links, each
  building its key from the same pieces, ending in
  `{token_hex(6)}.{ext}`:

  | Endpoint | Use case | Request | Key |
  |---|---|---|---|
  | lesson audio | `admin_audio_use_cases.presign_upload` | `AudioUploadRequest {lesson_id, content_type, size}` | `{lang}/{lesson}/…` |
  | Workbook | `curriculum_use_cases.presign_row_audio` | `CurriculumUploadRequest {row_ref, …}` | `{lang}/curriculum/{row}/…` |
  | Sounds | `sound_use_cases.presign_upload` | `SoundUploadRequest {content_type, size}` | `{lang}/sounds/…` |

  `ImageUploadRequest` extends `AudioUploadRequest`.
- **F2 Local key check.** The local store only accepts keys that match
  `KEY_PATTERN`: `[a-z]{2,3}/[A-Za-z0-9_-]{1,64}/[0-9a-f]{12}\.(m4a|mp3|webm|ogg)`.
  A `gen-…-` prefix would be refused locally unless the pattern allows
  it. Workbook keys have a fourth segment and already don't match
  locally. That is an existing limit, left as it is.
- **F3 Admin uploaders.** All three go through `uploadThroughLink(api,
  route, owner, file, type, words)`, where `owner` is merged into the
  presign body. They are:
  - `uploadClip`;
  - the Workbook's inline `upload`;
  - `uploadSound`.

  `AudioField` gives each panel a `ClipUploader = (clip, type) =>
  Promise<string>`.
- **F4 Current-clip pill.** `CurrentClip` in `AudioField.tsx` shows one
  pill: "Placeholder clip", "Local backend only" or "Hosted".

### Decisions

- **D1 Source rule (backend).** `app/domain/voices.py` gains
  `GENERATED_SOURCE = re.compile(r"gen-(am|om)-[a-z0-9-]{1,40}")` and
  `key_prefix(source: str | None) -> str`.
  - It returns `""` when `source` is None.
  - It returns `f"{source}-"` when `source` fully matches.
  - Anything else raises `InvalidContentError("source", "That is not a
    generated voice's tag")`.
- **D2 Requests and keys.** Each of the three requests gets `source: str
  | None = None`. Each use case takes `source` and builds its name as
  `f"{key_prefix(source)}{token_hex(6)}.{ext}"`. Without `source`, every
  key is byte-for-byte what it is today. Image uploads leave out the
  inherited field and ignore it.
- **D3 Local key pattern.** The 12-hex part of `KEY_PATTERN` becomes
  `(?:gen-(?:am|om)-[a-z0-9-]{1,40}-)?[0-9a-f]{12}`, so a generated clip
  uploads and plays locally too. The image pattern is unchanged.
- **D4 Admin uploader.** `ClipUploader` gets an optional third argument,
  `source?: string`.
  - `uploadThroughLink` sends it in the presign body only when it is
    set.
  - `uploadClip`, the Workbook upload and `uploadSound` pass it through.
  - `useClipUpload.send(clip, type, cleaning?, source?)` hands it to the
    store.
  - The Generate panel sends `gen-${take.clip.voiceId}`, and only when
    the voice ID looks like `am-*` or `om-*`.
  - Record and Upload never send a source.
- **D5 Current-clip pill.** `CurrentClip` matches
  `/\/gen-(am|om)-([a-z0-9]+)(?:-[a-z0-9-]*)?-[0-9a-f]{12}\.\w+$/` on
  the URL's path. If it matches, it shows a second pill, **Generated ·
  {Name}**, with the tooltip "Made with Addis AI". The name is the voice
  ID's first word after the language, with a capital first letter:
  `om-obse` gives "Obse" and `am-yohanes-calm` gives "Yohanes". A URL
  with no `gen-` name shows no extra pill.

### Deliverables

- **Backend:**
  - `app/domain/voices.py`;
  - the three request schemas;
  - the three use cases and their routers;
  - `local_audio_storage.KEY_PATTERN`.
- **Admin:**
  - `upload/link.ts`, `audio/upload.ts`, `sounds/model.ts` and
    `workbook/LessonPage.tsx`, for the source;
  - `audio/clipHooks.tsx` and `audio/GeneratePanel.tsx`, for `send`;
  - `audio/AudioField.tsx`, for the uploader type and the pill.
- **Tests:**
  - **Backend unit:** `key_prefix` (none, valid, invalid).
  - **Backend integration**, one per presign route:
    - with `source` the key has the `gen-…-` name;
    - without it the key is unchanged;
    - a bad source gives 422 on `source`.
  - **Backend local storage:** the local pattern accepts a generated key
    and still refuses `..` and a bad prefix.
  - **Admin:**
    - Use this clip presigns with `source: gen-om-obse`, and Upload sends
      no source;
    - the current clip shows "Generated · Obse" for a `gen-om-obse-…`
      URL and "Generated · Yohanes" for `gen-am-yohanes-calm-…`;
    - a plain URL shows no extra pill.

### Dependencies

- Bolt 098, complete.

### Acceptance Criteria

- [ ] A kept take is stored as `…/gen-{voice}-{hex}.{ext}` through all
  three endpoints, and other uploads are unchanged.
- [ ] A bad `source` gives 422.
- [ ] The local store accepts generated keys.
- [ ] The current clip shows **Generated · {Name}** for generated clips
  only.
- [ ] Backend: ruff, mypy (no new errors) and pytest pass. Admin: lint,
  `tsc -b`, `vitest` and build pass.

## Implement (2026-10-12T18:00:00Z)

### Backend

- **`app/domain/voices.py`:** adds `GENERATED_SOURCE` and
  `key_prefix(source)`. It returns `""` when there is no source,
  `"{source}-"` when the source is valid, and raises
  `InvalidContentError("source", …)` otherwise.
- **Upload requests:** `AudioUploadRequest`, `CurriculumUploadRequest`
  and `SoundUploadRequest` each get `source: str | None = None`. Images
  inherit the field from the audio request but ignore it.
- **Upload keys:** the three `presign_upload` use cases each take a
  `source` and build the key as `…/{prefix}{hex}.{ext}`. Their routers
  pass `body.source` through.
- **`local_audio_storage.KEY_PATTERN`:** now allows an optional
  `gen-(am|om)-…-` prefix before the 12 hex characters.

### Admin

- **`upload/link.ts`:** adds `sourced(source)`, which returns
  `{source}` or `{}` for the presign body.
- **`ClipUploader`** (in `clipHooks.tsx`) gains an optional `source`.
  `useClipUpload.send(…, cleaning?, source?)` passes it to the store.
- **Uploaders:** `uploadClip`, `uploadSound`, the letter page's upload,
  the Workbook row's upload and `AudioField`'s default uploader all
  pass `source` through.
- **`GeneratePanel`:** "Use this clip" sends `gen-{voiceId}`, but only
  when the voice ID looks like `am-…` or `om-…`.
- **`AudioField.CurrentClip`:** the new `generatedVoiceOf(url)` reads the
  voice from the stored name. The clip then shows a neutral pill,
  "Generated · {Name}", with the tooltip "Made with Addis AI".

### Deviations

None.

### Checks

- **Backend:** ruff passes, and mypy shows the same 4 errors as before.
  The upload, sounds, curriculum and local-store tests pass (98).
- **Admin:** `tsc -b` and `eslint` pass, and `vitest` passes 822 tests.

## Test (2026-10-12T18:30:00Z)

### Backend

- **`tests/unit/test_voice_settings_domain.py`** (12 new cases):
  `key_prefix` returns `""` for None and `{source}-` for 3 valid tags. It
  refuses 8 bad ones, with field `source`:
  - an empty tag;
  - no `gen-` prefix;
  - the language `ti`;
  - an empty voice;
  - upper case;
  - a slash;
  - `..`;
  - 41 characters.
- **`test_admin_audio_endpoints.py`** (+2): lesson audio tagged
  `gen-om-obse` gives `am/{lesson}/gen-om-obse-{hex}.mp3`, and a `..` tag
  gives 422 on `source`.
- **`test_sound_charts.py`** (+1): a tagged sound gives
  `om/sounds/gen-om-obse-{hex}.mp3`, and `obse` gives 422.
- **`test_curriculum.py`** (+1): a tagged row gives
  `am/curriculum/W001/gen-am-loza-{hex}.mp3`. An untagged upload is
  unchanged, and `gen-om-` gives 422.
- **`test_local_audio_storage.py`** (+6 cases): the local pattern accepts
  two generated keys. It refuses `gen-ti-…`, an empty voice, `..` and a
  prefix that doesn't start with `gen-`.

### Admin

- **`src/audio/generate.test.tsx`** (+7):
  - Use this clip passes `gen-om-obse` to the field's uploader, and the
    stored clip then shows "Generated · Obse" with the tooltip "Made with
    Addis AI".
  - `generatedVoiceOf` gives Obse, Yohanes and Loza (including a local
    `/media` URL with a query string). It gives nothing for a plain name
    and for a `gen-` name with no hex.
  - A plain clip shows "Hosted" and no Generated pill.
- **`src/audio/audio.test.tsx`** (+1): an uploaded file's presign has no
  `source`.

### Issues found

None.

### Results

- **Backend:**
  - pytest: 1902 passed.
  - ruff check and format: clean.
  - mypy: the same 4 errors as before.
- **Admin:**
  - `vitest`: 41 files, 830 tests passed.
  - lint and `tsc -b`: clean.
  - `vite build`: succeeds.
