---
bolt: 034-admin-api-foundation
created: '2026-09-22T10:10:00Z'
status: accepted
supersedes: null
superseded_by: null
---

# ADR-16: Admins are identified by the Google-verified email, stored on `users`

## Context

Intent `017-content-admin-web` decided at Checkpoint 1 that an admin is anyone
whose email is in `ADMIN_EMAILS`. The backend, however, had never stored an
email:
- `users` held only (`auth_provider`, `provider_user_id`).
- `TokenVerifier.verify()` returned only the provider's `sub` and discarded
  the other verified claims.

Story `001-admin-authorization` also requires that removing an email revoke
access on the **next request**, with no re-login.

## Decision

1. **Verifiers return an identity, not just a subject.**
   `TokenVerifier.verify()` returns a `VerifiedIdentity(subject, email)`.
   - Google sets `email` only when the token's `email_verified` claim is
     `true`.
   - Apple always returns `email=None`. Apple can hand out private relay
     addresses, so Apple accounts are never admins in v1.
2. **`users.email` stores the latest verified email.** It is a nullable
   column, not unique and not indexed.
   - New accounts are created with the email.
   - A returning user's email is rewritten only when it changes, including to
     `None`, through a dedicated `UserRepository.set_email`. That way the
     authentication path still never writes `daily_xp_target`,
     `selected_language` or `active_course_id` (User invariants 2 and 5).
3. **Email never identifies an account.** Account lookup and dedup remain
   (`auth_provider`, `provider_user_id`), and `ProviderIdentity`'s rule
   "never derived from or compared against email" is unchanged.
4. **`require_admin` checks every request.** It is a router-level dependency
   on `/api/v1/admin`, layered on `get_current_user`, and it checks
   `users.email` against `ADMIN_EMAILS` on every request:
   - The comparison is trimmed and case-insensitive.
   - An empty list means nobody is an admin.
   - A missing or invalid session is `401`; a valid non-admin is `403`
     (`not_admin`).

## Alternatives Considered

- **An allow-list of Google `sub` ids.** No schema change, but a sub is not
  visible to a person, so the list would be unusable by hand.
- **Check the email once at sign-in and mark the session as admin.**
  Revoking access would then wait for session expiry, which is up to 30 days
  with sliding renewal. That fails the story.
- **A separate admin sign-in endpoint and admin-sessions table.** This is a
  second authentication system for one to three people. The existing
  `/auth/google` flow already verifies the token that carries the email.
- **An `is_admin` column.** Rejected at Checkpoint 1: access would change
  through SQL instead of one Vercel variable.

## Consequences

- **More personal data.** The backend now stores an email address, the first
  personal data beyond a provider id. It is used only for the admin check and
  is not returned by any learner endpoint.
- **Existing accounts start with `email = NULL`.** Each user's email is
  filled in at their next Google sign-in. Signing in to the admin site does
  that, so nobody needs a manual step.
- **Revocation waits for a redeploy.** `ADMIN_EMAILS` is read through the
  cached `get_settings()`. On Vercel, changing an environment variable
  requires a redeploy, so "the next request" means the first request after
  the redeploy. Tests assert revocation by changing the setting between two
  requests.
- **No new Google audience is needed.** The Flutter app already obtains ID
  tokens for the web client id (`serverClientId`), and the admin site uses
  that same client id.
