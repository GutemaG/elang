# Buna (elang)

A gamified Amharic / Afaan Oromo language-learning app. Flutter/Dart mobile
client + FastAPI/Python backend, currently at the end of the
**auth & onboarding** slice: splash → onboarding carousel → language/daily-goal
selection → Google/Apple sign-in → session persisted on-device.

## Repo layout

```
lib/                Flutter app (features/auth/, shared/)
backend/             FastAPI backend: learner API and /api/v1/admin/* (DDD-structured, SQLite for local dev)
admin/               Content admin web site (Vite + React + TypeScript), see admin/README.md
memory-bank/         specsmd planning artifacts (intents, units, stories, bolts, ADRs) —
                     the design decisions and "why" behind everything below
stich-screens/       Exported Stitch "Highland Pulse" design reference (screenshots + HTML)
database-schema.md   Current DB schema (grows per intent)
docs/authoring-      How to write seed content for each of the six exercise types
  exercises.md       (shapes, worked examples, generators, pitfalls)
```

## Prerequisites

- Flutter SDK (Dart `^3.13.3`)
- [`uv`](https://docs.astral.sh/uv/) for the Python backend
- Android SDK / `platform-tools` on PATH if testing on a physical Android device
- A Google Cloud project with an OAuth consent screen + client IDs (see below) — required for real Google sign-in to work at all

## First-time setup

**Backend:**
```powershell
cd backend
uv sync
copy .env.example .env      # then fill in real values, see below
uv run alembic upgrade head
uv run uvicorn app.main:app --reload --port 8000
```
Verify: `curl http://localhost:8000/health` → `{"status":"ok"}`.

**Flutter app:**
```powershell
flutter pub get
flutter devices             # see what's available: windows, chrome, a phone, etc.
flutter run -d <device-id>
```

## Google OAuth setup (required for real sign-in)

1. Google Cloud Console → **OAuth consent screen** (a.k.a. "Google Auth Platform"): App name, support email, External audience, add your own Google account as a **Test user** (the app stays in Testing status until formally verified — anyone not listed gets blocked).
2. **Clients → Create Client**, twice:
   - **Web application** — add `http://localhost:<port>` as an Authorized JavaScript origin (see the CORS/origin gotcha below for why the port matters); leave Authorized redirect URIs empty (not used by this flow).
   - **Android** — package name from `android/app/build.gradle.kts` (`applicationId`), plus your debug keystore's SHA-1:
     ```powershell
     keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
     ```
3. Put the **Web** client ID in two places:
   - `lib/shared/config/auth_config.dart` — `googleClientId` and `googleServerClientId`
   - `backend/.env` — `GOOGLE_OAUTH_CLIENT_ID`

   (Client *IDs* are not secrets and are fine to commit; a client *secret*, if one is ever generated, must never go in either of these files or in git.)

Apple sign-in is wired but gated to iOS only for now (see Known limitations).

## Known gotchas (what you'll likely hit)

- **"Something went wrong" on Google sign-in, no backend log activity at all (physical device)**: `localhost` on a phone means *the phone itself*, not your dev machine. Fix: `adb reverse tcp:8000 tcp:8000` while the phone is USB-connected — this tunnels the phone's `localhost:8000` back to your PC. Needs to be re-run if the phone reconnects.
- **CORS error in the browser console on Web** (`No 'Access-Control-Allow-Origin' header...`): the backend only allows `http://localhost:<port>` origins when `ENVIRONMENT=local` (the default). If you're hitting this against a non-local backend, add the real origin to `CORS_ALLOWED_ORIGINS` (a wildcard such as `https://*.vercel.app` works too, see [Deployment](#deployment)).
- **`UnimplementedError: authenticate is not supported on the web`**: expected — Google's Web identity flow (GIS) requires the click to land directly on Google's own rendered button, not a custom one, for anti-phishing reasons. The app already handles this: Web renders Google's real button (`GoogleWebSignInButton`), which looks different from the custom pill button used on mobile — that's Google's restriction, not a bug.
- **`The given origin is not allowed for the given client ID`**: whatever `http://localhost:<port>` your browser session is actually on isn't in the Web OAuth client's Authorized JavaScript origins. Either always launch with `flutter run -d chrome --web-port 5000` (matching what's registered) or add the actual port you're using in Cloud Console.
- **`google.accounts.id.initialize() is called multiple times`**: harmless — happens because re-entering the sign-in screen creates a fresh wrapper that re-initializes the same underlying Google JS singleton. Google just uses the latest call; no action needed.
- **Full restart required after changing `AuthConfig` or `.env`**: hot reload won't pick up config or plugin-initialization changes — stop and re-run.
- **Session validity check is local-only**: the splash screen only checks the stored token's `expiresAt` locally; it never asks the backend "is this still valid." A `GET /api/v1/auth/session` endpoint already exists for this but isn't wired in yet (deliberate scope decision — see `memory-bank/bolts/003-auth-onboarding-ui/`).
- **`.env` and `.mcp.json` are gitignored on purpose** — `backend/.env` holds real OAuth/session config, `.mcp.json` holds a live Stitch API key. Never commit either; `backend/.env.example` is the template to copy from.

## Deployment

Five pieces, each set up once:

```
                 ┌──────────────────────┐        ┌───────────────┐
 Flutter app ───►│ Backend (Vercel)     │───────►│ Neon Postgres │
                 │ FastAPI, /api/v1/*   │        └───────────────┘
 Admin site ────►│                      │── signs upload links ──┐
 (Vercel)        └──────────────────────┘                        ▼
    │                                                   ┌───────────────┐
    └──── PUTs recorded clips straight to ─────────────►│ Cloudflare R2 │
 Flutter app ◄─── plays clips from the public r2.dev ───│ bucket        │
                                                        └───────────────┘
 Google Cloud: one OAuth web client, shared by the app, the admin site and the backend
```

Both Vercel projects deploy from `main`, so **pushing to `main` redeploys
them**. Environment variables are read at deploy time. The admin site's are
even baked into its JavaScript when it is built. So **after adding or
changing a variable, redeploy that project.** Saving the variable alone
changes nothing.

### 1. Backend (the Vercel project for `backend/`)

Set these as Production environment variables. The values below are
examples; the real ones live only on Vercel.

| Variable | Example | Notes |
|----------|---------|-------|
| `ENVIRONMENT` | `production` | Anything but `local` turns off the localhost CORS rule and the local audio store. |
| `DATABASE_URL` | `postgresql+asyncpg://user:****@ep-xxx-pooler.eu-central-1.aws.neon.tech/neondb?sslmode=require` | Neon. `sslmode` and `channel_binding` are translated for asyncpg automatically. |
| `GOOGLE_OAUTH_CLIENT_ID` | `123456-abc.apps.googleusercontent.com` | The **web** client id. |
| `ADMIN_EMAILS` | `you@gmail.com,editor@gmail.com` | Who may use the admin site. Empty means nobody. |
| `CORS_ALLOWED_ORIGINS` | `https://*.vercel.app` | Comma-separated browser origins; see below. |
| `AUDIO_BASE_URL` | `https://pub-<id>.r2.dev` | The R2 bucket's **public** address, with no trailing `/`. Saved clips are `<AUDIO_BASE_URL>/<key>`. |
| `R2_ACCOUNT_ID` | `<cloudflare account id>` | From the R2 dashboard. |
| `R2_BUCKET` | `ethio-lang` | |
| `R2_ACCESS_KEY_ID` | `<token access key id>` | From an R2 API token (see below). |
| `R2_SECRET_ACCESS_KEY` | `<token secret>` | **Secret.** Mark it sensitive on Vercel. Never commit it or put it in a `VITE_` variable. |

**`CORS_ALLOWED_ORIGINS`.** A `*` stands for one name.
`https://*.vercel.app` admits `https://admin-ethio-lang.vercel.app` and its
preview URLs. It does not admit `http://…`, `https://a.b.vercel.app` or
look-alike hosts. Exact entries work too, and the two kinds can be mixed:
`https://buna.et,https://*.vercel.app`.

**Database migrations are not run by the deploy.** Before pushing a change
that adds an Alembic migration, apply it to Neon from your machine
(PowerShell):

```powershell
cd backend
$env:DATABASE_URL = "postgresql+asyncpg://user:****@ep-xxx-pooler....neon.tech/neondb?sslmode=require"
uv run alembic current        # where Neon is now
uv run alembic upgrade head   # apply what's missing
Remove-Item Env:DATABASE_URL  # back to the local SQLite in .env
```

Check: `curl https://<backend>.vercel.app/health` → `{"status":"ok"}`.

### 2. Admin site (the Vercel project for `admin/`)

Set **Root Directory** to `admin`. The framework is Vite, and
`admin/vercel.json` sends every path to `index.html`.

| Variable | Example | Notes |
|----------|---------|-------|
| `VITE_API_BASE_URL` | `https://<backend>.vercel.app` | No trailing `/`. |
| `VITE_GOOGLE_CLIENT_ID` | `123456-abc.apps.googleusercontent.com` | The same web client id as the backend. |

Both end up in the browser bundle, so neither may be secret. More in
[admin/README.md](admin/README.md).

### 3. Google Cloud (the OAuth web client)

Under **Authorized JavaScript origins**, list exact addresses, with no
wildcards and no trailing `/`:

```
http://localhost
http://localhost:5000                   # Flutter web
http://localhost:5173                   # admin site, local
https://admin-ethio-lang.vercel.app     # admin site, deployed
```

Leave **Authorized redirect URIs** empty. Every client here uses Google's
pop-up or FedCM flow, never a redirect. Changes can take a few minutes to
apply.

### 4. After a deploy, check

1. Open the admin site and sign in.
   - *Not authorised*: your email is not in `ADMIN_EMAILS`, or the backend
     was not redeployed after adding it.
   - *Could not reach the server*: `CORS_ALLOWED_ORIGINS` doesn't cover the
     admin address.
2. Open a listening exercise and record a clip. Press **Use this
   recording**, then **Save**, then play the clip. The next section explains
   what happens along the way.

## Audio storage (Cloudflare R2)

A listening exercise plays its `audio_url`. The admin site can record a
clip, upload a file, or paste a link. Recorded and uploaded clips are stored
like this:

```
Admin site                          Backend                         R2
──────────                          ───────                         ──
1. POST /api/v1/admin/audio/uploads
   {lesson_id, content_type: "audio/mp4", size: 39512}
                                    signs a PUT link for exactly
                                    that key, type and size,
                                    valid for 10 minutes
   ◄── {upload_url, headers: {"Content-Type": "audio/mp4"},
        public_url, ...}
2. PUT <upload_url>: the file, with exactly those headers
   and no Authorization header ─────────────────────────────────────► stores the object
3. The public_url becomes the exercise's clip; the admin presses Save:
   PUT /api/v1/admin/exercises/{id}  {content: {audio_url: public_url, ...}}
4. The app fetches the lesson and plays audio_url from the public r2.dev address.
```

Here are the two addresses for one clip. The key is
`<language>/<lesson id>/<random>.m4a`.

```
upload_url  https://<account-id>.r2.cloudflarestorage.com/ethio-lang/am/24064d90-…/d5b89c5fc7d7.m4a?X-Amz-Algorithm=…&X-Amz-Signature=…
public_url  https://pub-<id>.r2.dev/am/24064d90-…/d5b89c5fc7d7.m4a
```

The upload address is private and works once. Only the public address is
saved.

Files must be `audio/mp4` (m4a), `audio/mpeg` (mp3), `audio/webm` or
`audio/ogg`, and at most 5 MB. The browser checks this before uploading, and
the backend checks it again when signing.

### Which store the backend uses

- **R2**, whenever `AUDIO_BASE_URL` and all four `R2_*` variables are set.
- **The backend itself**, when R2 isn't fully set up and
  `ENVIRONMENT=local`. Uploads go to `PUT /api/v1/audio-files/<key>`, signed
  the same way, and are served from `/media/audio/<key>`. Those `/media/…`
  addresses only play where the local backend can be reached: the browser,
  the Android emulator (through `10.0.2.2`), or a phone on the same Wi-Fi.
- **Nowhere**, in every other case. Uploads answer `503` and the admin site
  says there is nowhere to store audio. Pasted links still work.

To use the local store while `backend/.env` holds R2 settings, comment out
one of them (for example `# R2_ACCESS_KEY_ID=…`) and restart the backend.

### One-time R2 setup (Cloudflare dashboard → R2)

1. **Bucket.** Create one, for example `ethio-lang`.
2. **API token.** Go to *Manage R2 API tokens → Create API token*. Give it
   **Object Read & Write**, limited to this bucket.
   - It shows an *Access Key ID* and a *Secret Access Key* once. They become
     `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` on the backend's Vercel
     project.
   - The account id becomes `R2_ACCOUNT_ID`.
3. **Public access.** Go to the bucket's *Settings → Public Development URL →
   Allow*. Copy the exact `https://pub-<id>.r2.dev` it shows into
   `AUDIO_BASE_URL`.
   - r2.dev is rate-limited and meant for development. For real traffic,
     connect a custom domain to the bucket later and point `AUDIO_BASE_URL`
     at that.
4. **CORS.** Go to the bucket's *Settings → CORS Policy → Add*. Without this
   rule the browser's upload is refused. Example:

   ```json
   [
     {
       "AllowedOrigins": ["https://admin-ethio-lang.vercel.app", "http://localhost:5173"],
       "AllowedMethods": ["PUT", "GET", "HEAD"],
       "AllowedHeaders": ["content-type"],
       "MaxAgeSeconds": 3600
     }
   ]
   ```

   To check it from a terminal, run the command below. A `200` with an
   `access-control-allow-origin` header means the rule is on.

   ```sh
   curl -i -X OPTIONS "https://<account-id>.r2.cloudflarestorage.com/ethio-lang/am/test.m4a" \
     -H "Origin: https://admin-ethio-lang.vercel.app" \
     -H "Access-Control-Request-Method: PUT" \
     -H "Access-Control-Request-Headers: content-type"
   ```

5. Redeploy the backend.

### When audio goes wrong

| What you see | Cause and fix |
|--------------|---------------|
| *Could not reach the audio store…* in the admin site | The bucket has no CORS rule for this site, and the `curl` check above answers `403 CORS not configured for this bucket`. Add the admin address to the CORS policy. |
| *This server has nowhere to store audio yet* | The R2 variables are missing on a non-local backend. Set all five and redeploy. |
| The upload works, but the clip doesn't play (404) | `AUDIO_BASE_URL` isn't the bucket's current public address, or public access is off. Compare it with *Settings → Public Development URL*, fix it and redeploy. Clips saved with the wrong address must be uploaded and saved again. |
| *The audio store refused the upload, perhaps because its link expired* | More than 10 minutes passed between the link being signed and the upload. Press the button again. |
| It plays on Android but not on iPhone | The clip is WebM, or Opus in mp4. The admin site records AAC in mp4 where the browser can (Chrome, Edge, Safari), and warns when it can't. Record in one of those browsers, or upload an m4a or mp3. |

## Testing

```powershell
# Flutter — unit/widget tests (fast, no backend needed)
flutter test test/ --exclude-tags=e2e

# Flutter — real end-to-end tests (needs the backend running on :8000)
flutter test test/shared/services/http_auth_api_e2e_test.dart

# Backend
cd backend
uv run pytest
uv run ruff check .
uv run mypy .
```

## Where the design decisions live

`memory-bank/` is the source of truth for *why* things are built the way they are — requirements, domain model, ADRs (session-token hashing, Apple JWT verification), and stage-by-stage implementation walkthroughs for every bolt. Worth checking before assuming something is a bug rather than a deliberate scope decision.
