---
id: 001-admin-web-scaffold-and-sign-in
unit: 002-content-admin-web
intent: 017-content-admin-web
status: complete
priority: must
created: '2026-09-22T10:00:00Z'
assigned_bolt: 037-admin-web-shell
implemented: true
---

# Story: 001-admin-web-scaffold-and-sign-in

## User Story

**As a** Buna admin
**I want** to open the admin site and sign in with my Google account
**So that** I can reach the content from any browser

## Acceptance Criteria

- [ ] **Given** the repo, **When** `admin/` is built with `npm run build`, **Then** a Vite + React + TypeScript app builds with no type errors and ESLint passes
- [ ] **Given** a signed-out visitor, **When** they open the site, **Then** they see only a Google sign-in button
- [ ] **Given** an admin signs in, **When** the backend accepts the token, **Then** the session token is kept for the tab and the content screen opens
- [ ] **Given** a signed-in non-admin (`403` from `/admin/me`), **When** the site loads, **Then** it shows a not-authorised screen with sign-out
- [ ] **Given** an expired or refused session, **When** any request returns `401`, **Then** the site returns to sign-in
- [ ] **Given** the built bundle, **When** it is inspected, **Then** it contains only the API base URL and the public Google client id -- no secret
- [ ] **Given** the site is deployed as its own Vercel project, **When** a deep link is opened, **Then** it loads (SPA rewrite)

## Technical Notes

- Google Identity Services script for the button; exchange the ID token at the existing `POST /auth/google`.
- Keep the session token in memory plus `sessionStorage`, not `localStorage`: an admin token should not outlive the tab.
- A small typed `api.ts` wrapper; no data-fetching library unless the Plan stage makes the case.
- Config through `VITE_API_BASE_URL` and `VITE_GOOGLE_CLIENT_ID`, with an `.env.example`.

## Dependencies

### Requires
- None

### Enables
- 002-content-tree-browser-and-editing
