---
intent: 001-auth-onboarding
phase: inception
status: context-defined
updated: 2026-09-15T12:35:35Z
---

# Auth & Onboarding - System Context

## System Overview

The Buna mobile client (Flutter) walks a new user through a splash screen, onboarding carousel, and pre-auth language/daily-goal selection, then authenticates them via Google OAuth or Sign in with Apple against the FastAPI backend, which creates/loads the `users` row and attaches the pending onboarding selections on first successful auth.

## Context Diagram

```mermaid
C4Context
    title System Context - 001-auth-onboarding

    Person(user, "Learner", "New or returning Buna user, mobile-only")
    System(mobile, "Buna Mobile Client", "Flutter app: splash, carousel, language/goal selection, sign-in UI")
    System(backend, "Buna Backend API", "FastAPI: session/account creation, onboarding-selection persistence")
    SystemDb(db, "PostgreSQL", "users table + onboarding fields")
    System_Ext(google, "Google OAuth", "Identity provider - primary sign-in")
    System_Ext(apple, "Sign in with Apple", "Identity provider - required alongside Google per App Store policy")

    Rel(user, mobile, "Interacts with")
    Rel(mobile, backend, "Calls (REST, HTTPS)")
    Rel(mobile, google, "Initiates OAuth flow (native SDK)")
    Rel(mobile, apple, "Initiates Sign in with Apple flow (native SDK)")
    Rel(backend, google, "Verifies ID token")
    Rel(backend, apple, "Verifies identity token")
    Rel(backend, db, "Reads/writes users, onboarding fields")
```

## External Integrations

- **Google OAuth**: Primary sign-in provider. Mobile client obtains an ID token via the native Google Sign-In SDK; backend verifies it server-side before creating/loading the account.
- **Sign in with Apple**: Required alongside Google per App Store Review Guideline 4.8. Same verify-then-create/load pattern, using Apple's stable user identifier (not email) for account dedup.

No other external systems are in scope for this intent — Redis, Celery, and Cloudflare R2 (from the project's overall tech stack) are not touched by auth/onboarding itself.

## High-Level Constraints

- OAuth-only authentication in Phase 1 — no email/password flow, no backend-side password storage.
- Must run against the project's chosen stack: FastAPI + PostgreSQL (backend), Flutter/Dart (mobile client) — see `memory-bank/standards/tech-stack.md`.
- Onboarding selections (language, daily goal) must exist as pre-auth client state and attach atomically to the account on first successful sign-in (resolved in requirements.md).

## Key NFR Goals

- Session tokens stored in platform secure storage (Keychain/Keystore), never plain prefs.
- OAuth tokens and identity payloads are never logged (ties to `coding-standards.md` logging rules).
- Pending onboarding selections must survive the OAuth browser-handoff (app backgrounding/kill) without loss.
