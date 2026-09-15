---
unit: 001-auth-service
bolt: 001-auth-service
stage: model
status: complete
created: 2026-09-15T12:52:04Z
---

## Static Model: Auth Service

### Bounded Context

Identity and account lifecycle for Buna. Owns: verifying Google OAuth and Sign in with Apple credentials server-side, creating or loading the corresponding account, attaching pre-auth onboarding selections to a brand-new account only, and issuing/validating a session token that lets the client skip re-authentication across app restarts. Does not own: onboarding UI, lesson/progress/gamification data (XP ledger, streaks, Beans, Amole — future `gamification-engine` intent), or any teacher/admin role (none exists in Phase 1).

### Entities

- **User**: `id` (surrogate key), `provider_identity` (ProviderIdentity VO — the dedup key), `selected_language` (LanguageCode VO), `daily_xp_target` (DailyXPTarget VO), `created_at` — Business rules: identity is unique per `provider_identity`, never per email; `selected_language` and `daily_xp_target` are set exactly once, at registration (either from a pending onboarding payload or from documented defaults), and are never overwritten by a pending-selection payload arriving on a later, returning-user sign-in; a `User` is always student-role (no role field needed in Phase 1).
- **AuthSession**: `id` (surrogate key), `user_id` (reference to `User`), `token` (SessionToken VO), `issued_at`, `expires_at` — Business rules: one `AuthSession` row per issued token; a `User` may hold multiple concurrent `AuthSession`s (same account signed in from two devices per story 002's edge case, each getting an independent session); validating a session never mutates the referenced `User`; an expired or unknown token validates as invalid, not as an error that surfaces account data.

### Value Objects

- **ProviderIdentity**: `auth_provider` (enum: `google` | `apple`), `provider_user_id` (string) — Constraints: immutable; equality by `(auth_provider, provider_user_id)`; `provider_user_id` is always the provider's stable subject identifier (Google's `sub` claim, Apple's stable user identifier) and is **never** derived from or compared against email, because Apple's private-relay email can differ or be absent across sign-ins for the same user.
- **LanguageCode**: `code` (string) — Constraints: must be one of the set of supported course languages (Amharic only in Phase 1, but the value object itself doesn't hardcode a single-language assumption); an unsupported/invalid code on a pending selection is rejected with a validation error rather than silently defaulted.
- **DailyGoalPreset**: `minutes_per_day` (enum: 5 | 10 | 15 | 20 — Casual/Regular/Serious/Intense) — Constraints: exactly one of the four fixed presets; no arbitrary minute values.
- **DailyXPTarget**: `xp_per_day` (positive integer) — Constraints: derived from a `DailyGoalPreset` via a minutes→XP mapping formula whose exact numeric values are an explicit open decision deferred to Stage 2 (Technical Design) and shared with the future `gamification-engine` intent; always positive; immutable once set on a `User`.
- **PendingOnboardingSelection**: `language` (LanguageCode), `daily_goal` (DailyGoalPreset) — Constraints: not a persisted entity — arrives as an optional request payload alongside the auth token on first sign-in only; the whole value object is optional (client may omit it entirely, e.g. dropped by a network hiccup); when present, `language` must validate against the supported set or the entire authentication request is rejected (no partially-malformed account is created); has no effect whatsoever when the sign-in resolves to an existing (returning) `User`.
- **SessionToken**: `value` (opaque random string), `issued_at`, `expires_at` — Constraints: opaque — carries no decodable identity claims itself; treated as a secret end-to-end and must never appear in logs (per `coding-standards.md`); uniqueness of `value` is a domain-level invariant even though its storage representation (e.g. hashed at rest) is a Stage 2 decision.

### Aggregates

- **User** (Aggregate Root): Members: `User` entity; `ProviderIdentity`, `LanguageCode`, `DailyXPTarget` value objects — Invariants: (1) `provider_identity` is globally unique across all users — this is the sole dedup key, enforced at creation, never email; (2) `selected_language` and `daily_xp_target` are written exactly once, at the moment the `User` row is created, from either a validated `PendingOnboardingSelection` or documented defaults — no later authentication (same or different provider... though cross-provider linking is explicitly out of scope) may overwrite them; (3) a `User` cannot exist without a valid, non-empty `provider_user_id`.
- **AuthSession** (Aggregate Root): Members: `AuthSession` entity; `SessionToken` value object; a `user_id` reference (not a loaded `User`, to keep session validation independent of the `User` aggregate's own transactional boundary) — Invariants: (1) `token.value` is globally unique; (2) every `AuthSession` references exactly one `user_id` that must correspond to an existing `User` at issuance time; (3) an expired or otherwise invalid token fails validation cleanly without ever loading or exposing `User` data.

### Domain Events

- **UserRegistered**: Trigger: first successful authentication for a `provider_identity` never seen before (new account path) — Payload: `user_id`, `auth_provider`, `selected_language`, `daily_xp_target`, `registered_at`.
- **UserAuthenticated**: Trigger: successful authentication resolving to an existing `User` (returning-user path) — Payload: `user_id`, `auth_provider`, `authenticated_at`. Carries no selection/goal data since none changes on this path.
- **SessionIssued**: Trigger: any successful authentication (new or returning user) — Payload: `session_id`, `user_id`, `issued_at`, `expires_at`. Deliberately excludes the raw token value from the event payload — never log or propagate the secret itself.
- **AuthenticationRejected**: Trigger: an invalid, expired, or tampered provider token, or a pending-selection payload with an unsupported language code — Payload: `auth_provider`, `reason` (e.g. `invalid_token` | `expired_token` | `invalid_pending_selection` | `provider_unreachable`), `attempted_at`. No `user_id` (none reliably identified) and no token/claim contents in the payload.

### Domain Services

- **AuthenticationService**: Operations: `authenticate_with_google(id_token, pending_selection?) -> AuthResult`, `authenticate_with_apple(identity_token, pending_selection?) -> AuthResult` — Dependencies: `GoogleTokenVerifier` (external, server-side verification of the Google ID token per its `sub` claim), `AppleTokenVerifier` (external, JWT verification against Apple's published public keys), `UserRepository`, `AuthSessionRepository`, `OnboardingAttachmentPolicy`. Encapsulates the shared "verify token → find-or-create `User` by `ProviderIdentity` → attach pending selection only if newly created → issue `AuthSession`" flow common to stories 002 and 003, distinguishing a `provider_unreachable` failure from an `invalid_token` failure so the caller can surface a retryable vs. terminal error (per both stories' edge cases).
- **OnboardingAttachmentPolicy**: Operations: `resolve_selection_for_new_user(pending_selection?) -> (LanguageCode, DailyXPTarget)`, `map_minutes_to_daily_xp_target(minutes_per_day) -> DailyXPTarget` — Dependencies: none external (pure domain logic). Validates an incoming `PendingOnboardingSelection`'s language code, applies documented defaults when no pending payload was sent at all, and performs the minutes→XP mapping (exact formula: open item, see below). Only ever consulted on the account-creation branch — `AuthenticationService` must not call it when resolving to an existing `User`.
- **SessionValidationService**: Operations: `validate(token_value) -> User | Invalid` — Dependencies: `AuthSessionRepository`, `UserRepository`. Looks up the `AuthSession` by token, checks expiry, and only then loads the referenced `User`; used on every app restart per stories 002/003's session-recognition acceptance criteria.

### Repository Interfaces

- **UserRepository**: Entity: `User` — Methods: `find_by_provider_identity(auth_provider, provider_user_id) -> User | None`, `add(user: User) -> User`, `get_by_id(user_id) -> User | None`.
- **AuthSessionRepository**: Entity: `AuthSession` — Methods: `add(session: AuthSession) -> AuthSession`, `find_by_token(token_value) -> AuthSession | None`, `get_by_id(session_id) -> AuthSession | None`.

### Ubiquitous Language

- **Provider identity**: The `(auth_provider, provider_user_id)` pair that uniquely and permanently identifies an account; the only valid account-dedup key.
- **Provider-stable ID**: The identifier a provider guarantees stays constant for the same real person across sign-ins (Google's `sub`, Apple's user identifier) — distinct from and preferred over email.
- **Private-relay email**: Apple's optional email-hiding relay; may change or be absent between sign-ins for the same user, which is precisely why email must never be used for dedup.
- **First-time sign-in**: An authentication attempt whose `provider_identity` has never been seen before — triggers account creation.
- **Returning user**: An authentication attempt whose `provider_identity` matches an existing `User` — triggers a load, never a state overwrite.
- **Pending onboarding selection**: The client-held, pre-auth (anonymous) language + daily-goal choice, transmitted only once, at first successful authentication.
- **Daily goal preset**: One of the four fixed onboarding tiers (Casual/Regular/Serious/Intense, 5/10/15/20 minutes/day) a user picks before authenticating.
- **Daily XP target**: The server-side numeric value a daily goal preset maps to; consumed by the (future) gamification engine.
- **Session token**: The opaque credential issued after successful authentication that lets the client skip re-authentication on app restart; treated as a secret, never logged.
- **Account dedup**: The rule that account identity resolution always uses provider identity, never email.

### Open Items Carried Into Stage 2 (Technical Design)

- Exact minutes→daily-XP-target mapping formula (flagged in `requirements.md` as a decision shared with the future `gamification-engine` intent; `DailyGoalPreset`/`DailyXPTarget` are modeled as distinct value objects specifically so this formula can change without touching the aggregate's shape).
- Documented default `LanguageCode`/`DailyXPTarget` values for the "no pending selection sent at all" edge case (story 001, AC2) — the domain model requires *a* sensible default to exist, but does not fix its value.
- `AuthSession` revocation/logout is not covered by any of the three stories in this bolt (no logout story exists yet) — `AuthSessionRepository` therefore has no `revoke`/`delete` method; add one only if a future story requires it.
