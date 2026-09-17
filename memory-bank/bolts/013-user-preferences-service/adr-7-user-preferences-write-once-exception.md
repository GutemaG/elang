---
bolt: 013-user-preferences-service
created: '2026-09-17T08:35:00Z'
status: accepted
supersedes: null
superseded_by: null
---

# ADR-7: `User.selected_language`/`daily_xp_target` amended from strict write-once to write-once-then-only-via-`UpdateUserPreferences`

## Context

`backend/app/domain/entities.py`'s `User` docstring states an explicit invariant: `selected_language` and `daily_xp_target` are written exactly once, at creation, and never overwritten by a later authentication. This was written during `001-auth-service` to prevent a specific bug class — a returning user re-authenticating with a different onboarding-style flow accidentally clobbering their real settings. It was never written with "the user deliberately wants to change their own settings later" in mind, because no such feature existed yet.

`005-profile-and-settings` (FR-2, FR-3) requires exactly that: a signed-in user changing their own language/daily-goal from a Settings screen. Silently loosening the invariant (e.g. just removing the docstring language and adding a setter) would leave no record of *why* the original constraint existed or *what specifically* is now allowed to violate it — a future bolt could reintroduce the original bug (e.g. a new auth-flow change accidentally overwriting these fields) with no documented tripwire to catch it.

## Decision

The invariant is amended, not removed: `selected_language` and `daily_xp_target` are still written exactly once at creation by the authentication flow, and after creation the **only** sanctioned mutation path for either field is the new `UpdateUserPreferences` operation (`PATCH /api/v1/users/me`, bolt `013-user-preferences-service`). No other code path — including any future authentication/re-authentication flow — may write these fields post-creation. `entities.py`'s docstring is updated to state this explicitly (per story 001's own acceptance criterion), not left describing the old, now-inaccurate rule.

## Rationale

The original invariant protected against exactly one failure mode: an *authentication* code path overwriting a user's real settings. That failure mode is unchanged and still guarded — this decision does not touch the authentication flow at all. What's added is a second, entirely separate code path (`UpdateUserPreferences`) whose only trigger is an explicit, authenticated user action from the Settings screen. Naming the exception precisely (rather than a blanket "these fields are now mutable") preserves the original protection while adding the one path that's actually needed.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Silently remove the write-once language from the docstring, add a plain setter | Least ceremony | Loses the record of why the constraint existed; a future re-authentication change could reintroduce the original bug with nothing to catch it | Rejected — this project's convention (ADR-5 superseding ADR-4) is to record invariant amendments, not silently edit them away |
| Model `UpdateUserPreferences` as a full re-authentication-equivalent path (reuse whatever code path onboarding uses to set these fields) | Reuses existing code | Re-introduces the exact ambiguity ("is this authentication or a user edit?") that the original invariant was written to eliminate | Rejected — conflates two conceptually different triggers (auth vs. explicit user edit) into one path |
| Leave the fields immutable forever; solve FR-2/FR-3 by having the user log out and re-onboard to "change" them | No invariant amendment needed at all | Terrible UX; not a real solution to the actual requirement; re-onboarding isn't designed to be repeatable | Rejected — doesn't satisfy FR-2/FR-3 |

## Consequences

### Positive
- The original bug the invariant guarded against (auth-flow overwrite) is still fully prevented — this decision doesn't touch that path.
- Future readers of `entities.py` see exactly one documented, deliberate exception, not a vague "these are now mutable, good luck."
- Consistent with this project's established practice of recording invariant amendments as ADRs (ADR-5/ADR-4 precedent).

### Negative
- `User` now has two documented rules about the same two fields (write-once-at-creation, plus one sanctioned post-creation path) instead of one simple rule — marginally more to keep straight when reading the entity.

### Risks
- If a future feature needs a *third* legitimate way to change these fields (e.g. an admin support tool), this ADR must be revisited and the exception list explicitly extended — not silently worked around. Flagged here so it isn't missed.

## Related

- **Stories**: 001-update-daily-goal-and-language
- **Standards**: none currently reference this invariant outside `entities.py`'s own docstring
- **Previous ADRs**: precedent-only relationship to ADR-5 (both are invariant amendments recorded as ADRs); no direct dependency
