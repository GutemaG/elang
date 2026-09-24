---
id: 004-audio-record-upload-link
unit: 002-content-admin-web
intent: 017-content-admin-web
status: complete
priority: must
created: '2026-09-22T10:00:00Z'
assigned_bolt: 039-admin-audio-ui
implemented: true
---

# Story: 004-audio-record-upload-link

## User Story

**As a** Buna admin
**I want** to record a clip in the browser, upload a file, or paste a link for a listening exercise
**So that** adding real audio takes seconds instead of SQL

## Acceptance Criteria

- [x] **Given** a listening exercise, **When** its editor opens, **Then** it offers Record, Upload and Link, and a play button for the current clip
- [x] **Given** Record, **When** microphone permission is granted, **Then** the admin can start, stop, play back, discard and re-record before anything uploads
- [x] **Given** microphone permission is denied, **When** Record is chosen, **Then** a message explains it and Upload and Link still work
- [x] **Given** a browser that can record `audio/mp4`, **When** it records, **Then** mp4 is used; otherwise WebM is used with a visible warning that iPhones may not play it
- [x] **Given** a recording or a chosen file, **When** it is saved, **Then** it is PUT to the presigned URL, the returned public URL is saved as `audio_url`, and the new clip plays from its public URL
- [x] **Given** a pasted link, **When** it is saved, **Then** the server check runs and a rejection reason is shown inline
- [x] **Given** a file over 5 MB or a non-audio file, **When** it is chosen, **Then** it is refused before any upload
- [ ] **Given** the change is saved, **When** the Flutter app next fetches the lesson, **Then** the clip plays on a real phone (manual check, recorded in the test report)

## Technical Notes

- MediaRecorder with `MediaRecorder.isTypeSupported('audio/mp4')` first.
- PUT with exactly the `headers` the upload response returns (bolt 036). The link is signed for the base type, e.g. `audio/webm`, and R2 refuses a PUT whose Content-Type differs, such as the blob's `audio/webm;codecs=opus`. This was shown live in bolt 036's test report.
- The end-to-end phone check depends on the R2 public URL working (`system-context.md` finding 7).

## Dependencies

### Requires
- 002-content-tree-browser-and-editing
- 005-audio-upload-and-link-api

### Enables
- None
