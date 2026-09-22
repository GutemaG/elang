---
stage: implement
bolt: 037-admin-web-shell
created: '2026-09-22T16:40:00Z'
---

## Implementation Walkthrough: content-admin-web

### Summary

A new React site in `admin/`. An admin signs in with Google, picks a
course, and browses its sections → skills → lessons → exercises. Sections,
skills and lessons can be added, renamed, moved up or down, and deleted;
the course can be renamed. Every write is followed by a fresh load of the
tree from the server. No backend change was needed.

### Structure Overview

- **`src/api.ts`**: one fetch wrapper. It adds the bearer token, turns the
  backend's `{error_code, message, details}` (and FastAPI's own `{detail}`)
  into an `ApiError`, and reports every `401` so the session ends.
- **`src/auth/`**: the session. It is kept in `sessionStorage`, and one
  provider holds the state `signed_out | checking | admin | not_admin`,
  decided by `GET /admin/me`. The Google button is the only code that
  touches Google.
- **`src/tree/`**: the course list, the tree, one generic row for all three
  levels, the inline title form, and the delete dialog. The tree provides
  `run(write)` (write, then reload) and `requestDelete` to every row through
  a context.
- **`src/App.tsx`**: the session state picks the screen. Only an admin
  reaches the routes `/` and `/courses/:courseId`.

### Completed Work

- [x] `admin/package.json`, `tsconfig*.json`, `vite.config.ts`,
  `eslint.config.js`: Vite 8, React 19, TypeScript 6.0 (strict, with
  `noUncheckedIndexedAccess`), ESLint with typescript-eslint and
  react-hooks, and Vitest 4 on jsdom. The dev server is pinned to port 5173
  with `strictPort`.
- [x] `admin/index.html`: loads the Google Identity Services script, and is
  marked `noindex`.
- [x] `admin/.env.example`: `VITE_API_BASE_URL` and `VITE_GOOGLE_CLIENT_ID`,
  both public.
- [x] `admin/vercel.json`: the SPA rewrite, so deep links load.
- [x] `admin/README.md`: running it, the settings, the Google origin step,
  and deploying.
- [x] `.gitignore`: `admin/node_modules/`, `admin/dist/` and `admin/.env*`,
  except `.env.example`.
- [x] `src/api.ts`, `src/config.ts`, `src/types.ts` (mirrors
  `admin_schemas.py`) and `src/vite-env.d.ts` (the env variables, and the
  slice of GIS the site uses).
- [x] `src/auth/session.ts`: storage, plus `emailFromIdToken`, which reads
  the Google token's email **for display only**.
- [x] `src/auth/SessionContext.tsx`: the provider, `signInWithGoogle` and
  `signOut`.
- [x] `src/auth/GoogleButton.tsx`, `SignInScreen.tsx`,
  `NotAuthorisedScreen.tsx`.
- [x] `src/tree/levels.ts`: the routes for each level, and `moved()`, which
  swaps an item with its neighbour to give the full new order.
- [x] `src/tree/CourseList.tsx`, `CourseTree.tsx`, `NodeRow.tsx`,
  `InlineForm.tsx`, `ExerciseList.tsx`, `DeleteDialog.tsx`,
  `TreeActions.ts`.
- [x] `src/styles.css`: plain CSS, with light and dark following the system.
- [x] `src/test/setup.ts`: jest-dom matchers, and cleanup between tests. The
  tests themselves come in Stage 3.

### Key Decisions

- **The delete is asked first without `confirm`.** The backend always
  answers an unconfirmed delete with `409`:
  - `confirmation_required` opens a dialog listing what goes, e.g. "This
    also deletes 2 lessons and 11 exercises".
  - `content_in_use` opens a dialog saying "N learners have progress…",
    with only Close.

  So the counts are the server's, never guessed.
- **A failed write still reloads the tree.** It may have failed because the
  server moved on, for example when another admin deleted the item. The
  error stays in a banner above the reloaded tree. The exception is a
  `401`, which signs out instead.
- **Moves send every sibling's id.** Up and down swap two neighbours and
  `PUT` the whole list, which is what the backend's reorder requires. The
  buttons are disabled at each end and while any write is in flight.
- **Fetches on mount are written as promise callbacks with a "still
  mounted" flag.** This satisfies react-hooks' `set-state-in-effect` rule,
  and a late answer cannot overwrite a newer screen.
- **Expanded rows stay expanded across reloads**, because rows are keyed by
  id. Adding a child expands its parent, so the new item is visible.
- **Sign-out is client-side only.** The backend has no sign-out endpoint, so
  the token stays valid on the server until it expires. This is noted in
  the README.

### Deviations from Plan

- **Versions**: Vitest 5 needs Node 22, and TypeScript 7 is not yet
  supported by typescript-eslint. On Node 20.20 that means **Vitest 4.1**
  and **TypeScript 6.0**. Vite 8 and React 19 are as planned.
- **Exercise type labels** use the backend's six real types
  (`multiple_choice`, `listening`, `sentence_construction`, `match_pairs`,
  `gap_fill`, `spell_tiles`). An unknown type shows its raw name.
- **Local-media badge**: besides the planned "placeholder audio" badge, a
  "local audio" badge marks clips that play only from the local backend.

### Dependencies Added

- **Runtime**: `react`, `react-dom`, `react-router-dom`.
- **Dev**: `vite`, `@vitejs/plugin-react`, `typescript`, `@types/react`,
  `@types/react-dom`, `@types/node`, `eslint`, `@eslint/js`,
  `typescript-eslint`, `eslint-plugin-react-hooks`, `globals`, `vitest`,
  `jsdom`, `@testing-library/react`, `@testing-library/dom`,
  `@testing-library/user-event`, `@testing-library/jest-dom`.
- `npm audit`: 0 vulnerabilities.

### Checks run at this stage

- `npm run build`: no type errors. JS is **87 KB gzipped** (276 KB raw), well
  under the 500 KB limit. CSS is 1.3 KB gzipped.
- `npm run lint`: clean.
- **Bundle scan**: the only configuration strings are `localhost:8000` and
  the public Google client id. The only "password" matches are React DOM's
  input-type names.
- **Dev server** on 5173: `/` and the deep link `/courses/abc` both return
  the app.
- **Against the running local backend**:
  - the CORS preflight from `http://localhost:5173` is allowed
  - a bad token gets `401 invalid_session`, the body shape `api.ts` parses

### Developer Notes

- `admin/.env.local` was created locally from `.env.example`. It is
  gitignored.
- Before a real sign-in, add `http://localhost:5173` to the Google web
  client's Authorized JavaScript origins.
- The dev server is left running on <http://localhost:5173>.
