# Tech Stack

## Overview
Buna is a gamified language-learning mobile app (English → Amharic for Phase 1 MVP). A single Flutter/Dart codebase ships the iOS/Android client; a Python/FastAPI service backs it with PostgreSQL, Redis, and Celery for the gamification and content pipeline.

## Languages
- **Dart** — Flutter mobile client (single codebase, iOS + Android)
- **Python** — FastAPI backend service

Dart/Flutter gives one codebase for both mobile platforms with strong typing and hot-reload iteration speed. Python + FastAPI gives async I/O, automatic OpenAPI docs, and pydantic-based validation for the gamification ledgers (XP, Beans, Amole) and SRS queries.

## Framework
- **Flutter** — mobile client (iOS/Android)
- **FastAPI** — backend API service

FastAPI's async support matters for this project because several MVP flows are read/write-heavy under concurrency (XP ledger writes, Bean deductions, SRS due-item queries) and benefit from non-blocking I/O against Postgres/Redis.

## Authentication
- **Google OAuth** — primary sign-in
- **Sign in with Apple** — required alongside Google per App Store guidelines (any app offering third-party login must offer Apple's)

No email/password flow for MVP — auth-only, student-only user model (no teacher/admin/content-manager role in the app).

## Infrastructure & Deployment
- **Mobile CI/CD**: Codemagic — cloud macOS build runners; publishes to Google Play Console (internal testing) and App Store Connect/TestFlight
- **Media storage**: Cloudflare R2 + CDN — native-speaker audio recordings (human-recorded for MVP, no AI TTS dependency)
- **Cache / live leaderboard**: Redis (sorted sets) — deferred use for leaderboard is Phase 2, but Redis is provisioned from Phase 1 since Celery also depends on it as a broker
- **Async jobs**: Celery — streak checks, league rotation (Phase 2), notifications
- **Animation**: Rive or Lottie — mascot/celebration animations in the Flutter client

Backend hosting target (VM/container platform, region) is not yet specified — flag as TBD when Operations planning starts; Codemagic only covers the mobile build/release pipeline, not backend deployment.

## Package Manager
- **Dart/Flutter**: `pub` (via `flutter pub`) — the only real option in the Flutter ecosystem
- **Python**: **uv** (fast, modern, lockfile-based) — confirmed 2026-09-15 ahead of `001-auth-service`'s Stage 4 (Implement).

## Decision Relationships
- FastAPI's async model pairs with Celery+Redis for anything that shouldn't block a request (streak jobs, notifications).
- Google OAuth + Sign in with Apple are coupled: Apple's requirement is triggered specifically because Google OAuth is offered as third-party login.
- Codemagic is scoped to mobile only; a separate decision is needed for backend/API hosting.
