---
stage: plan
bolt: 037-admin-web-shell
created: '2026-09-22T15:40:00Z'
---

## Implementation Plan: content-admin-web

### Objective

A new React site in `admin/` where an admin signs in with Google and
browses, adds, renames, reorders and deletes a course's sections, skills and
lessons, backed by the `/api/v1/admin/*` API from bolts 034–035. Exercises
are **listed** here; editing them is bolt 038, and audio is bolt 039.

### What the code and setup showed

1. **The Google web client already exists.** It is
   `475970937717-h80aqt3b2b7psrt918udc102r6ts61fq.apps.googleusercontent.com`,
   and it is both the Flutter app's `googleServerClientId` and the backend's
   `GOOGLE_OAUTH_CLIENT_ID` audience. A Google Identity Services (GIS)
   button using this id yields an ID token that the backend already accepts.
   **No backend change is needed.**
2. **Google will refuse the button on an unknown origin.** The GIS button
   only works on origins listed under the client's *Authorized JavaScript
   origins*. `http://localhost:5173`, and later the deployed admin address,
   must be added in Google Cloud Console → APIs & Services → Credentials.
   Only you can do that.
3. **Local CORS is already open to any `http://localhost:<port>`** (see
   `main.py`). In production the admin origin goes into Vercel's
   `CORS_ALLOWED_ORIGINS`.
4. **Toolchain:** Node 20.20 and npm 10.8 are installed. The repo has no JS
   tooling yet, so this is a new, self-contained `admin/` package.
5. **Signing in to the admin site creates a normal learner account** for a
   Google user who has never used the app, via `/auth/google`'s new-user
   branch. This is harmless, and it is the same account the app would make.
   This was accepted in bolt 034.

### Deliverables

**Project setup (`admin/`)**
- Vite + React + TypeScript (strict), with ESLint (`typescript-eslint`,
  react-hooks) and Vitest + React Testing Library on jsdom.
- `react-router-dom` provides deep links (`/courses/:courseId`). It is the
  only runtime dependency beyond React.
- `.env.example` holds `VITE_API_BASE_URL` (default
  `http://localhost:8000`) and `VITE_GOOGLE_CLIENT_ID`.
- `vercel.json` sends every path to `index.html`, so deep links load.
- The repo `.gitignore` gains `admin/node_modules/`, `admin/dist/` and
  `admin/.env*`, but not `.env.example`.
- An `admin/README.md` covers running it, the environment variables, and
  the Google origin step.

**Sign-in (story 001)**
- The GIS script is loaded in `index.html`, and the "Sign in with Google"
  button is rendered by GIS itself.
- The returned ID token goes to `POST /api/v1/auth/google`, and the session
  token is kept in `sessionStorage`, so it lasts for this tab only.
- Then `GET /api/v1/admin/me` decides the screen:
  - `200` → the app
  - `403` → **Not authorised**, showing the signed-in account and Sign out
- Any `401` from any request clears the session and returns to sign-in.
- Sign out clears the session and GIS auto-select.

**Content tree (story 002)**
- **Courses**: a list with section counts. Picking one opens
  `/courses/:id`.
- **The tree**: sections → skills → lessons, collapsible, with child counts.
  Each lesson lists its exercises (type and prompt). Listening exercises
  carry a **placeholder audio** badge when they still use the piano clip.
- **Actions on every section, skill and lesson:**
  - **Rename**: inline. A section has a title and subtitle.
  - **Add child**: add a skill to a section, or a lesson to a skill. There
    is also **Add section** at the top.
  - **Move up / Move down**: sends the full new order in one request.
  - **Delete**: first a request without confirm. The server's `409` answer
    drives a dialog:
    - `confirmation_required` shows "This deletes N skills, N lessons, N
      exercises" with a Delete button, which re-sends with `confirm=true`.
    - `content_in_use` shows "N learners have progress here; it can't be
      deleted", with only a Close button.
- After every successful write the tree reloads from the server, so it never
  shows a state the server does not have.
- A failed write shows the server's message and leaves the tree as it was.
- The course title can be renamed.

**Code layout**
- `src/api.ts`: a typed `fetch` wrapper that adds the bearer token, parses
  errors into `{status, error_code, message, details}`, and raises the
  sign-out on 401.
- `src/types.ts`: the admin API shapes, mirrored from
  `admin_schemas.py` in one file.
- `src/auth/`: session storage, `useSession`, the GIS button and the
  screens.
- `src/tree/`: the course list, the tree view, the node row with its
  actions, and the delete dialog.
- Plain CSS in `src/styles.css`, with no UI library. Light and dark follow
  the system setting.

### Dependencies

- **Runtime**: `react`, `react-dom`, `react-router-dom`.
- **Dev**: `vite`, `@vitejs/plugin-react`, `typescript`, `eslint`,
  `typescript-eslint`, `eslint-plugin-react-hooks`, `vitest`, `jsdom`,
  `@testing-library/react`, `@testing-library/user-event`,
  `@testing-library/jest-dom`.
- **Backend**: none. It already serves everything this bolt calls.
- **You, before sign-in can work locally**: add `http://localhost:5173` to
  the Google web client's Authorized JavaScript origins.

### Technical Approach

- **Server state is not copied locally.** Each screen fetches, and every
  write is followed by a refetch. At one to three admins and hundreds of
  rows, that is simpler and safer than optimistic updates.
- **Tests run without Google.** The GIS button is wrapped in one component
  that tests replace, so sign-in is tested by handing the app a fake ID
  token.
- **I cannot sign in with your Google account from here.** I will verify
  with `npm run build`, `npm run lint`, `npm test`, and by starting the dev
  server and loading it. The real Google sign-in is **yours** to try once
  the origin is added.

### Acceptance Criteria

- [ ] `npm run build`, `npm run lint` and `npm test` pass, with no type
  errors
- [ ] Signed out: only the Google button shows
- [ ] An admin's ID token → session stored for the tab → content screen
- [ ] A non-admin (`/admin/me` 403) → Not authorised screen with Sign out
- [ ] Any `401` → back to sign-in with the session cleared
- [ ] The built bundle contains only the API base URL and the public Google
  client id, and no secret
- [ ] A deep link (`/courses/:id`) loads, via the SPA rewrite in
  `vercel.json` and Vite's dev history fallback
- [ ] The tree shows every level in order, with counts and the
  placeholder-audio badge
- [ ] Add, rename, move up/down and delete update the tree from the server's
  response
- [ ] The delete dialog shows the server's counts, and a refused delete
  shows the learner count with no way to force it
- [ ] A failed request shows its message, and the tree is left unchanged
- [ ] Gzipped JS is under 500 KB
