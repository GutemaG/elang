---
bolt: 024-courses-service
created: '2026-09-20T15:10:00Z'
status: accepted
supersedes: null
superseded_by: null
---

# ADR-13: `User.selected_language` becomes a mirror of the active course, written only by `ActivateCourse` (amends ADR-7)

## Context

ADR-7 amended the write-once rule on `User.selected_language`: it is written once at creation by the authentication flow, and after that the only sanctioned mutation path is `UpdateUserPreferences` (`PATCH /api/v1/users/me`). It also says that any further legitimate way to change the field must extend the ADR's exception list explicitly, not work around it.

Intent 010 adds a real course concept. The user's learning language is now determined by their active course (`users.active_course_id`, ADR-12), and a second dimension, the from-language, exists. A dedicated course-switching operation is needed. The shipped Flutter client reads `selected_language` as a required string in the session and preferences responses and sends `language` on the settings PATCH, so neither can be removed before the UI bolts land.

## Decision

1. `users.selected_language` stays, but it is a **mirror**: it always equals the active course's `learning_language`.
2. A single `ActivateCourse` operation is the **only writer** of both `active_course_id` and `selected_language`, in one transaction. Signup calls it (resolving the onboarding pair), the new `PUT /users/me/active-course` calls it, and `UpdateUserPreferences` delegates to it.
3. ADR-7's sanctioned-path list is therefore extended: created by signup through `ActivateCourse`; changed only through `ActivateCourse`. No authentication or re-authentication path may write either field, exactly as before.
4. The from-language is **not stored** on the user; it is derived from the active course. Responses gain `active_course_id` and `from_language` additively.
5. `PATCH /users/me` with `language` keeps working for older clients: it means "activate the available course for (language, current from-language)" and fails with the existing invalid-preference error if none exists.

## Rationale

The original invariant protects against an authentication path overwriting user settings; that protection is unchanged. What changes is that the "explicit user action" path is now one operation instead of a field-specific one, so the two related fields cannot diverge. Keeping the column avoids breaking the shipped client, and deriving the from-language avoids a second stored value that could disagree with the course.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Drop `selected_language` | Single source of truth | Breaks the shipped client's required-string parse until bolt 026; needs a column drop | Too disruptive; can be removed in a later cleanup |
| Keep it as an independent field, plus `active_course_id` | No delegation needed | The two can disagree; Settings changes language with no effect (today's bug) | Divergence is the defect this intent fixes |
| Repurpose it as the from-language | One less concept to add | Silent semantic change of a shipped field; confusing for older clients | Rejected as misleading |
| Store `from_language` on the user as well | Explicit | A second value that must agree with the course | Derive it instead |

## Consequences

### Positive

- One writer keeps `active_course_id` and `selected_language` consistent by construction.
- The shipped client keeps working; ADR-7's protection against auth-flow overwrite still holds.
- Older clients using `PATCH language` still get correct behaviour.

### Negative

- `UpdateUserPreferences` now depends on the course operation, which couples two previously separate use cases.
- A redundant column remains until a later cleanup.

### Risks

- Risk: a future path writes `selected_language` directly. Mitigation: tests assert the mirror invariant after signup, switch and PATCH, and this ADR names `ActivateCourse` as the sole writer.
- Risk: `PATCH language` is ambiguous for a user whose current from-language has no course for that language. Mitigation: it fails with the existing invalid-preference error rather than guessing.

## Related

- **Stories**: 002-active-course-per-user
- **Standards**: none
- **Previous ADRs**: amends ADR-7 (extends its sanctioned-path list); depends on ADR-12
