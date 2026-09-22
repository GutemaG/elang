# Buna Admin

The web site for managing Buna's lesson content: courses, sections, skills,
lessons and (from bolt 038) exercises. It talks only to the backend's
`/api/v1/admin/*` API, and only people listed in the backend's
`ADMIN_EMAILS` get past sign-in. Edits go live for learners straight away.

Vite + React + TypeScript. No UI or data-fetching library.

## Run it locally

1. Start the backend on port 8000 (see `backend/`), with your address in
   `ADMIN_EMAILS` in `backend/.env`.
2. Copy `.env.example` to `.env.local`. The defaults point at that backend.
3. Install and start:

   ```sh
   cd admin
   npm install
   npm run dev
   ```

4. Open <http://localhost:5173>. The port is fixed, because Google only
   shows its button on registered origins.

## One-time Google setup

In Google Cloud Console → APIs & Services → Credentials, open the OAuth
**web** client (the same id as `VITE_GOOGLE_CLIENT_ID` and the backend's
`GOOGLE_OAUTH_CLIENT_ID`), and add under **Authorized JavaScript origins**:

- `http://localhost:5173`
- the deployed admin address, e.g. `https://buna-admin.vercel.app`

Without it, the sign-in button does not appear.

## Settings

Both end up in the browser bundle, so neither may be secret.

| Variable | Meaning |
|----------|---------|
| `VITE_API_BASE_URL` | The backend, no trailing slash |
| `VITE_GOOGLE_CLIENT_ID` | The Google OAuth web client id |

## Checks

```sh
npm run build   # type-check and bundle into dist/
npm run lint
npm test
```

## Deploying

A Vercel project of its own, with **Root Directory** `admin`. `vercel.json`
sends every path to `index.html`, so links like `/courses/<id>` load
directly. After the first deploy:

- add the site's address to the backend's `CORS_ALLOWED_ORIGINS` on Vercel
- add it to the Google client's Authorized JavaScript origins (above)
- add it to the R2 bucket's CORS rule, for audio uploads (bolt 039)

## How sign-in works

Google's button gives an ID token, which the site exchanges at
`POST /api/v1/auth/google` for a Buna session token. The token is kept in
`sessionStorage`, so it lasts until the tab closes. `GET /api/v1/admin/me`
then decides: an admin sees the content, anyone else sees *Not authorised*.
Any `401` ends the session and returns to sign-in.

Signing out forgets the token in this tab. The backend has no sign-out
endpoint, so the token itself stays valid on the server until it expires.
