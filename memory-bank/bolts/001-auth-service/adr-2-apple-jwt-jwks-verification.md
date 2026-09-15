---
bolt: 001-auth-service
created: 2026-09-15T13:00:03Z
status: accepted
superseded_by: null
---

# ADR-2: Verify Sign in with Apple identity tokens via raw JWT-over-JWKS, no vendor SDK

## Context

Story 003 requires verifying Apple's identity token server-side before creating/loading a `User`. Google's equivalent flow (story 002) uses Google's official `google-auth` Python package, which handles fetching Google's public keys, signature verification, and standard claim checks (issuer, audience, expiry) behind a simple function call. `tech-stack.md` doesn't name an equivalent for Apple, and no first-party or widely-adopted Python SDK from Apple exists for server-side Sign in with Apple token verification (unlike, say, Node.js's ecosystem, which has more options).

## Decision

Verify Apple identity tokens as standard JWTs: fetch and cache Apple's published JSON Web Key Set (JWKS) from `https://appleid.apple.com/auth/keys`, then use `PyJWT` + `cryptography` to verify the token's RS256 signature against the matching key (selected by the JWT's `kid` header), and manually check issuer (`https://appleid.apple.com`), audience (our app's bundle ID / Services ID), and expiry — the same claims Google's helper checks automatically.

## Rationale

This is the standard, widely-documented approach used across ecosystems that lack a dedicated Apple auth SDK (it's exactly what Apple's own web documentation describes at the protocol level: Sign in with Apple identity tokens are just JWTs signed by Apple's rotating key set, verifiable by any standard JWT library). `PyJWT` is a mature, widely-used library; `cryptography` is its standard backend for RS256. No Apple-specific behavior is being reinvented — only the generic "verify a JWT against a JWKS endpoint" pattern, applied to Apple's specific issuer/audience values.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Raw JWT + JWKS via PyJWT (chosen) | Standard, well-documented pattern; mature libraries; full control over caching/rotation behavior | We own the JWKS-fetch-and-cache logic ourselves (no SDK does it for us) | N/A — this is the decision |
| Third-party "Sign in with Apple" Python wrapper packages | Slightly less boilerplate | Smaller community, less scrutiny, additional third-party trust surface for a security-critical path, uncertain maintenance | Security-critical token verification is exactly the code path where a small, less-maintained dependency is a worse bet than well-known primitives (PyJWT + cryptography) |
| Delegate verification to a managed auth provider (e.g. Auth0, Firebase Auth) | Handles multi-provider verification uniformly | Introduces a new external system and cost not in `tech-stack.md`; overkill for 2 providers at this scale; contradicts the already-decided direct-integration approach for Google | Out of scope — not evaluated as a real alternative for an MVP already committed to direct Google/Apple integration |

## Consequences

### Positive
- No new architectural dependency beyond two well-established libraries (`PyJWT`, `cryptography`) already common in the Python ecosystem.
- Full visibility into and control over the verification logic (issuer/audience/expiry checks are explicit code, not hidden inside a third-party package) — easier to audit.

### Negative
- We own the JWKS caching and key-rotation-on-`kid`-miss behavior ourselves (flagged separately in Stage 2 as an implementation-level detail for Stage 4), rather than getting it for free from an SDK.
- Slight asymmetry with the Google path (which uses a single high-level library call) — acceptable given no equivalent exists for Apple in Python.

### Risks
- **Apple key rotation**: if a `kid` isn't found in the cached JWKS, the fetch-and-cache logic must refetch before failing (not silently reject a legitimately-signed token during a key-rotation window). Mitigation: explicit refetch-once-on-cache-miss behavior, to be implemented at Stage 4 (already flagged as an open item in `ddd-02-technical-design.md`).

## Related

- **Stories**: 003-apple-sign-in-authentication
- **Standards**: None yet — `tech-stack.md` could be updated to name `PyJWT`/`cryptography` explicitly once Stage 4 confirms this holds; not done retroactively here since that's a standards-facilitation step, not this ADR's job.
- **Previous ADRs**: ADR-1 (session token hashing) — both concern this bolt's security design, no direct dependency between them.
