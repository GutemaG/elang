---
last_updated: 2026-09-15T13:00:03Z
total_decisions: 2
---

# Decision Index

This index tracks all Architecture Decision Records (ADRs) created during Construction bolts.
Use this to find relevant prior decisions when working on related features.

## How to Use

**For Agents**: Scan the "Read when" fields below to identify decisions relevant to your current task. Before implementing new features, check if existing ADRs constrain or guide your approach. Load the full ADR for matching entries.

**For Humans**: Browse decisions chronologically or search for keywords. Each entry links to the full ADR with complete context, alternatives considered, and consequences.

---

## Decisions

### ADR-2: Verify Sign in with Apple identity tokens via raw JWT-over-JWKS, no vendor SDK
- **Status**: accepted
- **Date**: 2026-09-15
- **Bolt**: 001-auth-service (001-auth-service)
- **Path**: `bolts/001-auth-service/adr-2-apple-jwt-jwks-verification.md`
- **Summary**: Story 003 requires verifying Apple's identity token server-side before creating/loading a `User`, and no Python SDK exists for this. Verify Apple identity tokens as standard JWTs against Apple's published JWKS using PyJWT + cryptography.
- **Read when**: Implementing or modifying Apple/Sign-in-with-Apple token verification, JWKS caching/rotation logic, or any other provider integration lacking an official SDK (this establishes the "raw JWT-over-JWKS" pattern as the fallback approach).

### ADR-1: Session tokens stored as SHA-256 hashes, not plaintext or a slow password hash
- **Status**: accepted
- **Date**: 2026-09-15
- **Bolt**: 001-auth-service (001-auth-service)
- **Path**: `bolts/001-auth-service/adr-1-session-token-hashing.md`
- **Summary**: The `AuthSession` aggregate needed a storage representation for its session token at rest, validated on a hot path. Store SHA-256(token_value), not plaintext or a slow password-hashing algorithm.
- **Read when**: Implementing or modifying session/token storage, working on any other high-entropy machine-generated secret (API keys, refresh tokens) where the "is this a password?" question comes up again, or reviewing security/logging conventions for tokens.
