---
unit: 002-content-admin-web
intent: 017-content-admin-web
phase: inception
status: stories-defined
created: '2026-09-22T10:00:00Z'
updated: '2026-09-22T10:00:00Z'
---

# Unit Brief: Content Admin Web

## Purpose

A new React site in `admin/` where admins sign in with Google and manage
courses' sections, skills, lessons, exercises, audio and vocabulary through
the `/admin/*` API.

## Scope

### In Scope
- Vite + React + TypeScript scaffold, ESLint, `.env.example`, its own Vercel
  project with an SPA rewrite
- Google sign-in, session handling, a not-authorised screen
- A content tree with add, rename, reorder (up/down) and guarded delete
- One editor per exercise type, with inline server errors
- Audio: record (MediaRecorder), upload a file, paste a link, play
- Exercise preview (Should), vocabulary screen (Could)

### Out of Scope
- Any change to the Flutter app
- UI component libraries (plain CSS)
- Drag-and-drop reordering, audio editing or trimming, offline use of the
  admin site

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Admin sign-in (client) | Must |
| FR-2 | Browse the content tree | Must |
| FR-3 | Create, edit, reorder and delete content | Must |
| FR-4 | Per-type exercise editors | Must |
| FR-5 | Audio: record, upload or link | Must |
| FR-7 | Preview an exercise | Should |
| FR-8 | Vocabulary management (client) | Could |

---

## Story Summary

| Story | Priority | Bolt |
|-------|----------|------|
| 001-admin-web-scaffold-and-sign-in | Must | 037 |
| 002-content-tree-browser-and-editing | Must | 037 |
| 003-exercise-editors | Must | 038 |
| 004-audio-record-upload-link | Must | 039 |
| 005-exercise-preview | Should | 038 |
| 006-vocabulary-screen | Could | 040 |

## Dependencies

- Depends on: `001-content-admin-api`
- Depended by: none

## Technical Context

- This is a new toolchain in the repo (Node/npm). Add the `admin/` build
  outputs and `node_modules/` to `.gitignore`.
- TypeScript types for exercise content mirror
  `backend/app/infrastructure/api/lesson_schemas.py`. Keep them in one
  `types.ts` so a seventh exercise type is a single, visible edit.
- Test with Vitest + React Testing Library. The load-bearing test is the
  editor round-trip over every exercise type.
