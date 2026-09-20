---
bolt: 027-course-offline-and-verification
created: '2026-09-21T00:40:00Z'
status: accepted
supersedes: null
superseded_by: null
---

# ADR-14: Offline course switching: a per-course dashboard cache and a locally pending switch

## Context

Switching course is a server call (`PUT /users/me/active-course`, ADR-13), and the server's active course decides which skill tree, Practice words and completions the API returns (ADR-12). The client had no skill-tree cache at all, so the dashboard was blank offline. Story 003 requires each course's data to stay separate, and requires switching offline to a course that was cached, but not to one that never was.

## Decision

1. The client keeps one cached dashboard (skill tree plus the Amole balance seen with it) **per course id**, written after every successful dashboard load, together with the last course list and the last known active course.
2. When the network fails (a failure with no backend `error_code`), the dashboard shows the active course's cached copy with an "Offline, showing saved progress" note. A failure that carries an `error_code` (an expired session, for example) is a real answer and is never treated as offline.
3. **Offline switch rule**: allowed only to a course whose dashboard is cached. It becomes the active course locally and is recorded as **pending**. A never-cached course is refused with a message and the current course stays active.
4. **Reconciliation**: before each dashboard load and each course-list load, a pending choice is sent to the server. Success clears it. If the server rejects it (course no longer available), it is dropped and the server's active course wins. While still offline it stays pending.
5. Downloaded lesson packs need no per-course keying: they are keyed by the globally unique lesson id, and the backend gates a completion by the lesson's own course (ADR-12), so a completion queued in course A syncs to A after a switch. Packs gain nullable `course_id` and `course_title` columns for display only; existing packs read as English to Amharic.

## Rationale

The server stays the source of truth whenever it is reachable. The device and server can disagree only for the short time between an offline switch and the next successful contact, and nothing written in that window depends on the active course, because lessons are gated by their own course. Caching whole dashboards per course is the smallest thing that satisfies "never show A's tree for B" and "open from cache".

## Alternatives Considered

- **No offline switching**: simpler, but fails two of story 003's acceptance criteria.
- **Cache only the active course**: cannot switch offline at all.
- **Store the active course only on the server and refuse everything offline**: leaves the dashboard blank offline, as before.

## Consequences

- One more local file (`course_cache.json`) and a small wrapper around the course API.
- Cached progress can be stale (lessons finished offline show on the next online load).
- The cache is not cleared on log out; a different account on the same device would see the previous account's saved copy until its own first online load. The lesson pack store and sync queue already behave this way. Tracked as a follow-up.
- The lesson-pack database moves to version 2 (two nullable columns).
