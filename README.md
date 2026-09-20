# Buna (elang)

A gamified Amharic / Afaan Oromo language-learning app. Flutter/Dart mobile
client + FastAPI/Python backend, currently at the end of the
**auth & onboarding** slice: splash → onboarding carousel → language/daily-goal
selection → Google/Apple sign-in → session persisted on-device.

## Repo layout

```
lib/                Flutter app (features/auth/, shared/)
backend/             FastAPI auth service (DDD-structured, SQLite for local dev)
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
- **CORS error in the browser console on Web** (`No 'Access-Control-Allow-Origin' header...`): the backend only allows `http://localhost:<port>` origins when `ENVIRONMENT=local` (the default). If you're hitting this against a non-local backend, add the real origin to `CORS_ALLOWED_ORIGINS` in `.env`.
- **`UnimplementedError: authenticate is not supported on the web`**: expected — Google's Web identity flow (GIS) requires the click to land directly on Google's own rendered button, not a custom one, for anti-phishing reasons. The app already handles this: Web renders Google's real button (`GoogleWebSignInButton`), which looks different from the custom pill button used on mobile — that's Google's restriction, not a bug.
- **`The given origin is not allowed for the given client ID`**: whatever `http://localhost:<port>` your browser session is actually on isn't in the Web OAuth client's Authorized JavaScript origins. Either always launch with `flutter run -d chrome --web-port 5000` (matching what's registered) or add the actual port you're using in Cloud Console.
- **`google.accounts.id.initialize() is called multiple times`**: harmless — happens because re-entering the sign-in screen creates a fresh wrapper that re-initializes the same underlying Google JS singleton. Google just uses the latest call; no action needed.
- **Full restart required after changing `AuthConfig` or `.env`**: hot reload won't pick up config or plugin-initialization changes — stop and re-run.
- **Session validity check is local-only**: the splash screen only checks the stored token's `expiresAt` locally; it never asks the backend "is this still valid." A `GET /api/v1/auth/session` endpoint already exists for this but isn't wired in yet (deliberate scope decision — see `memory-bank/bolts/003-auth-onboarding-ui/`).
- **`.env` and `.mcp.json` are gitignored on purpose** — `backend/.env` holds real OAuth/session config, `.mcp.json` holds a live Stitch API key. Never commit either; `backend/.env.example` is the template to copy from.

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
