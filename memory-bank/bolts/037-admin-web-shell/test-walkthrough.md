---
stage: test
bolt: 037-admin-web-shell
created: '2026-09-22T17:20:00Z'
---

## Test Report: content-admin-web

### Summary

- **Tests**: 50/50 pass (`npm test`, Vitest on jsdom), in about 7 s.
- **Types and build**: `npm run build` (`tsc -b && vite build`) is clean.
- **Lint**: `npm run lint` is clean.
- **Falsification**: six deliberate breakages were each caught. See below.
- **Against the real backend**: the site's types and routes were checked
  against the running backend's OpenAPI schema.
- The backend suite is untouched by this bolt (no backend change).

### Test Files

- [x] `admin/src/api.test.ts` — the fetch wrapper (10 cases):
  - the bearer token and JSON body are sent; nothing is sent when signed out
  - a `204` yields no body
  - the backend's `error_code`, `message` and `details` survive intact, so
    the delete dialog can read the counts
  - a `401` reports the lost session **and** still raises; a `403` does not
  - FastAPI's own `{"detail": [...]}` validation errors are read
  - a non-JSON body (a proxy page) and a dead connection give readable
    messages rather than crashing
- [x] `admin/src/auth/session.test.ts` — the stored session (5 cases):
  - it round-trips through `sessionStorage`, and **never** touches
    `localStorage`
  - it is empty before sign-in and after sign-out
  - the email is read from a Google ID token's payload, and unreadable
    tokens give `null` rather than throwing
- [x] `admin/src/tree/levels.test.ts` — routes and ordering (8 cases):
  - every route string matches the admin API
  - a move swaps with the right neighbour, refuses to go past either end,
    and does not mutate the list it was given
- [x] `admin/src/signin.test.tsx` — sign-in, with Google's button replaced
  (8 cases):
  - signed out, only the button shows, and **no request is made**
  - signing in sends the ID token, stores the session for the tab, and
    opens the content; later requests carry the token
  - a session kept over a reload is re-checked without signing in again
  - a refused Google token, and an unavailable backend, each show the
    server's message and stay signed out
  - a non-admin (`403`) sees *Not authorised* with their address, cannot
    see the content, and can sign out
  - a `401` — on the first check, or on a later request — returns to
    sign-in and forgets the token
  - signing out clears the session and tells Google not to sign in
    automatically
- [x] `admin/src/tree.test.tsx` — the tree and its writes (21 cases), over
  a fake backend that records every request:
  - **Showing**: the course header and counts; expanding reaches skills,
    lessons and exercises; the **placeholder audio** and **local audio**
    badges; an empty lesson says so; siblings are ordered by
    `order_index` even when they arrive shuffled; an unknown course says
    "This course does not exist"; the course list links into the tree
  - **Renaming**: a lesson sends `{title}` and the tree is **reloaded**
    rather than patched locally; a section sends title *and* subtitle; the
    course title can be renamed; an empty title cannot be saved, and
    Cancel sends nothing
  - **Adding**: a section (title and subtitle) and a skill, which opens its
    section so the new row is visible; a lesson offers no "add child",
    since exercises come in bolt 038
  - **Moving**: the **whole** sibling list is sent in the new order, for
    sections and for lessons; the buttons are disabled at each end
  - **Deleting**: asked first without `confirm`; the `409` drives the
    dialog, which shows the server's counts ("2 skills, 2 lessons and 3
    exercises"), and only then is `?confirm=true` sent; `content_in_use`
    shows "3 learners have progress…" with **no** Delete button and no
    second request; Cancel sends nothing; a delete the server accepts
    outright needs no dialog
  - **A refused write**: the server's message appears in a banner, the form
    stays open with what was typed, the tree is refreshed from the server,
    and the banner can be dismissed; a `401` on a write ends the session

### Falsification

Each breakage was applied to the source, the suite run, and the source
restored:

| Breakage | Result |
|---|---|
| The tree is not reloaded after a write | 4 tests fail |
| A move sends only the moved item's id | 2 tests fail |
| The confirmed delete drops `confirm=true` | 1 test fails |
| A `401` no longer ends the session | 4 tests fail |
| The first delete is sent with `confirm=true` | 2 tests fail |
| The placeholder-audio badge is dropped | 1 test fails |

### Checked against the real backend

The backend was started on a spare port and its OpenAPI schema compared
with `src/types.ts`:

- **Every field** of `AdminCourse`, `AdminCourseList`, `AdminCourseTree`,
  `AdminTreeSection`, `AdminTreeSkill`, `AdminTreeLesson`,
  `AdminTreeExercise`, `AdminNode` and `AdminMeResponse` matches.
- `AuthResponse` has a `user` object the site does not read; that is
  deliberate, and the site only takes `session_token`.
- **Every route** the site calls exists in the API.

Earlier, at Stage 2, the CORS preflight from `http://localhost:5173` was
accepted by the local backend, and a bad token returned the
`401 invalid_session` body the site parses.

### Acceptance Criteria Validation

- ✅ **Build, lint and tests pass with no type errors**: 50 tests, clean
  build and lint
- ✅ **Signed out: only the Google button**: `signin.test.tsx`
- ✅ **An admin's token → session for the tab → content**: same file, plus
  the `localStorage` check
- ✅ **A non-admin → Not authorised with Sign out**: same file
- ✅ **Any 401 → back to sign-in, session cleared**: three cases, across
  start-up, a read and a write
- ✅ **The bundle holds only the API base URL and the public client id**:
  scanned at Stage 2, re-checked on this build
- ✅ **A deep link loads**: `vercel.json` rewrite, Vite's dev fallback
  (checked live at Stage 2), and `/courses/:id` rendered directly in tests
- ✅ **The tree shows every level in order, with counts and the badge**:
  `tree.test.tsx`
- ✅ **Add, rename, move and delete update from the server's response**:
  `tree.test.tsx`, and falsification proves the reload is load-bearing
- ✅ **The delete dialog shows the server's counts; a refused delete cannot
  be forced**: `tree.test.tsx`
- ✅ **A failed request shows its message and leaves the tree as the server
  has it**: `tree.test.tsx`
- ✅ **Gzipped JS under 500 KB**: 87.6 KB (276.9 KB raw)

### Issues Found

- **None in the site's own behaviour.** Three test expectations were wrong
  at first, not the code: two waited for an element that had already gone,
  and one expected the row's title while the rename form was still open —
  it stays open on a refused save so the text can be corrected.

### Notes

- **The real Google sign-in is still unproven.** Everything up to and
  including the ID token is tested with a stand-in button; only you can
  try the real one, after adding `http://localhost:5173` to the Google web
  client's Authorized JavaScript origins.
- **No coverage report.** Vitest's coverage provider is not installed; it
  would add a dependency for a number, and the falsification runs above say
  more about whether the tests bite.
- **Nothing was written to `dev.db`**, and the temporary backend used for
  the schema check was stopped afterwards.
