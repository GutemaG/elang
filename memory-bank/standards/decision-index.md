---
last_updated: 2026-09-16T22:00:00Z
total_decisions: 6
---

# Decision Index

This index tracks all Architecture Decision Records (ADRs) created during Construction bolts.
Use this to find relevant prior decisions when working on related features.

## How to Use

**For Agents**: Scan the "Read when" fields below to identify decisions relevant to your current task. Before implementing new features, check if existing ADRs constrain or guide your approach. Load the full ADR for matching entries.

**For Humans**: Browse decisions chronologically or search for keywords. Each entry links to the full ADR with complete context, alternatives considered, and consequences.

---

## Decisions

### ADR-6: Offline sync replays the existing per-completion endpoint; no batch-sync endpoint
- **Status**: accepted
- **Date**: 2026-09-16
- **Bolt**: 008-offline-sync-service (001-offline-sync-service)
- **Path**: `bolts/008-offline-sync-service/adr-6-no-batch-sync-endpoint.md`
- **Summary**: Whether offline lesson-completion sync should get a new batch endpoint or just replay the existing per-completion endpoint N times was left open at Inception. Decided: no batch endpoint — the existing endpoint is already idempotent and now timestamp-aware, so calling it once per queued entry is correct; a batch endpoint would only be a performance optimization for a queue-size problem not yet shown to exist.
- **Read when**: Designing any client-side offline queue/retry mechanism against this backend, adding a new bulk/batch variant of an existing endpoint, or revisiting sync performance if real-world offline queues turn out larger than expected.

### ADR-5: Exercise grading moves client-side; the account ledger stays server-bounded, not server-computed
- **Status**: accepted
- **Date**: 2026-09-16
- **Bolt**: 005-lesson-engagement-service (001-lesson-service)
- **Path**: `bolts/005-lesson-engagement-service/adr-5-client-side-grading-with-bounded-server-ledger.md`
- **Supersedes**: ADR-4's "never expose `answer_key`" clause
- **Summary**: ADR-4's server-side-only grading (via a per-exercise call) turned out to conflict with `requirements.md`'s "no network call per exercise" NFR. The lesson-content response now includes correct-answer data so the client grades instantly and locally; the account ledger (beans/XP) is still bounded server-side (can't exceed what the account's real beans balance would allow) and completion is idempotent on a client-generated `attempt_id`, so the integrity that matters (the persisted ledger) is preserved without a per-exercise round trip.
- **Read when**: Implementing or modifying lesson-content/exercise API responses, the `/lessons/{id}/complete` endpoint, Beans/XP ledger logic, or reviewing any endpoint where a client-asserted lesson result is trusted (know the bound before assuming it's unchecked).

### ADR-4: Lesson-content API responses never include correct answers — grading is server-side-only
- **Status**: superseded by ADR-5
- **Date**: 2026-09-16
- **Bolt**: 004-lesson-content-service (001-lesson-service)
- **Path**: `bolts/004-lesson-content-service/adr-4-server-side-only-answer-keys.md`
- **Summary**: Whether the lesson-content payload includes correct answers or withholds them is a real API contract decision the next bolt depends on. `answer_key` is never serialized into any API response; grading is entirely server-side via a future `SubmitExerciseAnswer` use case reading the stored answer key directly.
- **Read when**: Understanding why the lesson-content schema originally excluded answer data, and why that no longer holds (see ADR-5) — the per-exercise-call approach this ADR planned around was never actually built.

### ADR-3: Single polymorphic `exercises` table with JSON `content`/`answer_key` columns
- **Status**: accepted
- **Date**: 2026-09-16
- **Bolt**: 004-lesson-content-service (001-lesson-service)
- **Path**: `bolts/004-lesson-content-service/adr-3-polymorphic-exercises-table.md`
- **Summary**: The lesson engine's 3 fixed exercise types need different rendering/answer data but share the same surrounding shape. Model exercises as one `exercises` table with a `type` discriminator plus JSON `content`/`answer_key` columns, not per-type tables.
- **Read when**: Implementing or modifying the `exercises` table/schema, adding a new exercise type, or working on any other closed, small-type-count polymorphic data model where per-type tables vs. a single JSON-backed table is a live question.

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
