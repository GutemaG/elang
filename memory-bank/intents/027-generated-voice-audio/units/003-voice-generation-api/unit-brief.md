---
unit: 003-voice-generation-api
intent: 027-generated-voice-audio
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-12T09:55:00Z'
updated: '2026-10-12T09:55:00Z'
---

# Unit Brief: Voice Generation API

## Purpose

Turn a text into an mp3 take that the admin can check in the browser.
Nothing is stored on our side.

## Scope

### In Scope
- The `generate_voice` use case. It resolves the language (directly or
  from `lesson_id`), the voice (from the settings or a `voice_id`
  override) and the speed (from the request or the settings).
- `POST /api/v1/admin/voice/generate`. It returns `audio/mpeg` bytes
  with `X-Voice-Id`, `X-Voice-Name`, `X-Duration-Seconds` and
  `X-Credits-Remaining`. These headers are added to CORS
  `expose_headers`.
- The text rules, the mapping from the domain voice exceptions to HTTP
  errors, and the audit log.
- Tests with a fake Addis client.

### Out of Scope
- Storing clips. The admin's existing uploaders do that.
- The UI.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-8 | Generate a clip | Must |
| FR-9 | Text rules | Must |
| FR-10 | Error mapping | Must |
| FR-11 | Audit log | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 008-generate-a-clip | Admins get an mp3 take for a text, gender and speed | Must | Planned (bolt 093) |
| 009-text-rules | Empty or overlong text is refused before spending | Must | Planned (bolt 093) |
| 010-plain-generation-errors | Each failure has a plain message and a fitting status | Must | Planned (bolt 093) |
| 011-generation-audit-log | Each generation is logged without its text | Must | Planned (bolt 093) |

### 008-generate-a-clip (FR-8)

**As an** admin, **I want** to send a text and get a playable take back,
**so that** I can check it before keeping it.

- [ ] A body of `{language: "om", text: "Maqaan koo Saaraa dha.",
  gender: "female"}` uses `om-obse` at the saved speed. It returns 200
  with `audio/mpeg` bytes, `X-Voice-Id: om-obse`, `X-Voice-Name: Obse`,
  `X-Duration-Seconds` and `X-Credits-Remaining`.
- [ ] Sending `{lesson_id, ...}` instead of `language` uses the lesson's
  learning language. An unknown lesson gets 404.
- [ ] Sending both `language` and `lesson_id`, or neither, gets 422.
- [ ] `speed` in the body overrides the saved speed. 0–100 is allowed,
  and anything else gets 422 on `speed`.
- [ ] `voice_id` in the body overrides the saved voice. It must start
  with `{language}-`, or the request gets 422 on `voice_id`.
- [ ] A browser on the admin origin can read the four `X-` headers, so
  they are listed in CORS `expose_headers`.
- [ ] No R2, media or database writes happen. A test checks that the
  storage fake is untouched.
- [ ] The route is admin-only.

### 009-text-rules (FR-9)

**As the** owner, **I want** bad text refused for free, **so that**
credit isn't wasted.

- [ ] Text is trimmed before it is sent.
- [ ] Empty text after trimming gets 422 on `text`: "Type the words to
  say". The Addis fake is not called.
- [ ] Text of 501 characters gets 422 on `text`: "Up to 500 characters:
  a word, a phrase or a sentence". Text of exactly 500 characters is
  allowed.
- [ ] Text with "…" or other punctuation is sent unchanged.

### 010-plain-generation-errors (FR-10)

**As an** admin, **I want** to know in words why a take failed,
**so that** I know whether to retry, change the text or tell the owner.

- [ ] Each row of the FR-10 table is covered by a test that has the
  fake client raise that exception. The test checks the HTTP status,
  the error code or field, and the message.
- [ ] No response contains Addis's own message, the key or a signed URL.

### 011-generation-audit-log (FR-11)

**As the** owner, **I want** a trace of who generated what voice and how
long it was, **so that** I can explain the spending.

- [ ] A success logs `admin_write action=generate entity=voice
  language=om voice=om-obse chars=22 seconds=1.83 admin={email}`.
- [ ] A failure logs `admin_voice_failed code=VOICE_CREDIT_EXHAUSTED
  addis_code=... admin={email}`.
- [ ] The text appears in no log record. A test checks the captured
  logs.

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| 001-voice-settings-service | The default voice and speed |
| 002-addis-voice-client | `generate` and the exceptions |

### Depended By
| Unit | Reason |
|------|--------|
| 004-voices-admin-page | Try it |
| 005-generate-tab | Generate |

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 093-voice-generate-api | simple-construction-bolt | 008, 009, 010, 011 | The generate route, end to end |
