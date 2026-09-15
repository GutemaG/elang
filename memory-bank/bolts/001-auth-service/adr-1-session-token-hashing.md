---
bolt: 001-auth-service
created: 2026-09-15T13:00:03Z
status: accepted
superseded_by: null
---

# ADR-1: Session tokens stored as SHA-256 hashes, not plaintext or a slow password hash

## Context

The `AuthSession` aggregate (Stage 1 domain model) issues an opaque `SessionToken` on every successful sign-in, used by the client to skip re-authentication across app restarts. Stage 2 (Technical Design) had to decide how `auth_sessions.token_hash` stores this value at rest — the domain model explicitly deferred this ("storage representation is a Stage 2 decision"). The token is validated on essentially every authenticated request (session check at splash, and implicitly on any future authenticated endpoint), so lookup speed matters; it also must never be recoverable from the database if the database itself is compromised.

## Decision

Store `SHA-256(token_value)` in `auth_sessions.token_hash`. The raw token is generated server-side with `secrets.token_urlsafe(32)` (~256 bits of entropy), returned to the client exactly once at issuance, and never persisted in recoverable form. Validation hashes the incoming token and does an equality lookup against the unique index on `token_hash`.

## Rationale

A session token is a high-entropy, machine-generated random value — not a low-entropy, human-chosen secret like a password. Password hashing algorithms (bcrypt, argon2) are deliberately slow to resist offline brute-force guessing against a small keyspace of likely human passwords. That threat model doesn't apply here: brute-forcing a 256-bit random token by hash comparison is infeasible regardless of hash speed. Using a slow hash would only add unnecessary latency to every session-validation request (a hot path — validated on every app-restart flow and beyond) for no real security benefit, and would prevent using a simple indexed equality lookup.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Plaintext storage | Simplest, direct lookup | Token fully recoverable if DB is read (backup leak, SQL injection, insider access) | Violates basic "secrets aren't stored in the clear" hygiene for no benefit |
| bcrypt/argon2 (password-style hashing) | Battle-tested for password storage; resists offline brute force | Deliberately slow (by design) — adds latency to a hot, frequently-hit validation path; also incompatible with a simple indexed equality lookup (these algorithms are designed to require re-hashing to compare, not indexed lookup) | Solves a threat (brute-forcing low-entropy human secrets) that doesn't apply to a 256-bit random token |
| Fast hash, e.g. SHA-256 (chosen) | Fast, indexable, still means a raw DB read doesn't hand over usable tokens | Not resistant to brute force *if* the token itself were low-entropy (it isn't) | N/A — this is the decision |

## Consequences

### Positive
- Session validation stays a single fast, indexed equality lookup — no added latency on a hot path.
- A raw database read/leak does not hand over usable session tokens.
- No new dependency (`hashlib.sha256` is stdlib) — nothing to add to `tech-stack.md`.

### Negative
- If Buna ever needs to support human-chosen, low-entropy credentials in the same table (not currently planned — Phase 1 is OAuth-only), this hashing choice would not be appropriate for those and would need its own decision.

### Risks
- None specific to this decision at current scope. If session token generation entropy is ever reduced (it shouldn't be — `secrets.token_urlsafe(32)` is deliberately fixed at 32 bytes), this decision would need revisiting.

## Related

- **Stories**: 002-google-oauth-authentication, 003-apple-sign-in-authentication (both issue/validate session tokens)
- **Standards**: `memory-bank/standards/coding-standards.md` (Security/logging conventions — token never logged, complements this ADR)
- **Previous ADRs**: None (first ADR in this project)
