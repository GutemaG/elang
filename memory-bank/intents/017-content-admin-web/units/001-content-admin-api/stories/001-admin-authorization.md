---
id: 001-admin-authorization
unit: 001-content-admin-api
intent: 017-content-admin-web
status: complete
priority: must
created: '2026-09-22T10:00:00Z'
assigned_bolt: 034-admin-api-foundation
implemented: true
---

# Story: 001-admin-authorization

## User Story

**As a** Buna admin
**I want** only the people I list to be able to change content
**So that** a leaked learner token can never edit lessons

## Acceptance Criteria

- [ ] **Given** no bearer token, **When** any `/admin/*` endpoint is called, **Then** it returns `401`
- [ ] **Given** a valid session for a user whose verified email is not in `ADMIN_EMAILS`, **When** any `/admin/*` endpoint is called, **Then** it returns `403`
- [ ] **Given** a session for a user whose verified email is in `ADMIN_EMAILS` (case-insensitive, whitespace-trimmed), **When** `GET /admin/me` is called, **Then** it returns `200` with that email
- [ ] **Given** an admin with a live session, **When** their email is removed from `ADMIN_EMAILS`, **Then** the next `/admin/*` request returns `403` with no re-login
- [ ] **Given** `ADMIN_EMAILS` is unset or empty, **When** anyone calls `/admin/*`, **Then** it returns `403` (fail closed)
- [ ] **Given** a Google token whose `email_verified` is false, **When** the user signs in, **Then** no email is recorded and the user is never an admin
- [ ] **Given** the admin site origin is in `cors_allowed_origins`, **When** the browser preflights `/admin/*`, **Then** the request is allowed; other origins are not
- [ ] **Given** this story is complete, **When** the learner endpoints are called, **Then** their behaviour and tests are unchanged

## Technical Notes

- The backend stores no email today (`system-context.md` finding 1). Decide at Plan how the verified email is kept (proposed: nullable `users.email`, rewritten from the verified ID token on every Google sign-in) and record it as an ADR.
- Apple sign-in may hide the real email; Apple users are simply never admins in v1. State it in the ADR.
- Check whether the Flutter app already requests ID tokens for the web client id. If yes, the admin site reuses it and `GoogleTokenVerifier` is unchanged; if not, accept a list of audiences like `apple_verifier.py`.
- `require_admin` is a FastAPI dependency layered on the existing session dependency, applied at the router level so a new admin endpoint cannot forget it.

## Dependencies

### Requires
- None

### Enables
- 003-content-tree-and-crud-api
- 005-audio-upload-and-link-api
