---
intent: 012-settings-and-profile-polish
phase: inception
status: draft
created: '2026-09-21T05:10:00Z'
updated: '2026-09-21T05:10:00Z'
---

# Requirements: Settings and Profile Polish

## Intent Overview

Make the Settings screen read as a designed surface rather than a list of rows: grouped
cards, a real signed-in identity, and a Log out action that does not look like the
primary action of the app. Type: UI refactor plus (see FR-2) a possible auth-domain
change.

Opened from a UX review on 2026-09-21. Units, stories and bolts are **not yet
generated**; this intent holds requirements only until it is picked up.

**Verified against real source before writing** (not assumed):
- `SettingsScreen` renders a flat `ListView` of `ListTile`s with
  `contentPadding: EdgeInsets.zero` on the page background. There is no grouping,
  no card, and no divider.
- The header line is `_providerLabel(...)`, which returns exactly one of
  "Signed in with Google", "Signed in with Apple" or "Signed in". No name, no email,
  no image.
- `Log out` is a `TactileButton` — the same solid primary-green component used for
  "Retry" and for lesson actions. Nothing distinguishes it as destructive.
- **The backend has no name, email or picture for a user.** `User` carries
  `provider_identity`, `selected_language`, `daily_xp_target`, `notification_enabled`,
  `created_at` and `active_course_id`, and nothing else.
- `ProviderIdentity` is `(auth_provider, provider_user_id)` and carries a documented
  intent: the subject identifier "is never derived from or compared against email".
  Storing a display name or email is therefore a **deliberate exclusion being revisited**,
  not an oversight — FR-2 must be decided against that, not around it.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Settings reads as a designed surface | Related options grouped in labelled cards; no bare rows on the page background | Must |
| The learner can see which account they are in | The signed-in row identifies the account beyond the provider name | Should |
| Destructive actions look destructive | Log out is visually distinct from every primary action in the app | Must |

## Functional Requirements

### FR-1: Grouped Settings
- **Description**: Options are grouped into labelled, rounded card containers — a
  learning group (daily goal, course) and a preferences group (notifications, sound) —
  with subtle row dividers inside each card.
- **Acceptance Criteria**:
  - Every option currently on the screen is still present and still works
  - Groups are labelled and visually separated
  - Highland Pulse tokens only; no new literal colours
  - No overflow at 320dp and 360dp with 1.3x text
  - Existing settings tests updated, not deleted
- **Priority**: Must

### FR-2: Signed-In Identity
- **Description**: The signed-in row identifies the account, not just the provider.
  **This requires a decision that this intent must make explicitly**: capture a display
  name (and possibly email) from the Google/Apple token at sign-in and store it, or keep
  the auth domain's deliberate exclusion and identify the account some other way.
- **Acceptance Criteria**:
  - The chosen approach is recorded as an ADR that references `ProviderIdentity`'s
    existing "never derived from or compared against email" intent
  - If a name is stored: it is captured at sign-in, is never used as a dedup key, and
    existing accounts without one still render correctly
  - If not stored: the row still tells the learner something more useful than today
  - No change to how accounts are matched or deduplicated, in either case
- **Priority**: Should

### FR-3: Destructive Log Out
- **Description**: Log out is styled as a destructive or secondary action — outlined or
  neutral, not the solid primary green shared with lesson actions.
- **Acceptance Criteria**:
  - Log out is visually distinct from `TactileButton`'s primary style
  - The existing confirmation step is unchanged
  - The action still signs out and returns to the sign-in route
- **Priority**: Must

## Non-Functional Requirements

### NFR-1: Design Token Discipline
- `AppColors`, `AppSpacing`, `AppRadii`, `AppTypography` only. A destructive style that
  needs a token adds it to the token file.

### NFR-2: Layout Robustness
- No overflow at 320dp and 360dp with 1.3x text.

### NFR-3: Accessibility
- Group labels are exposed as headings; Log out announces itself as destructive.

### NFR-4: No Regression
- Settings behaviour, the course picker entry and the logout flow are unchanged.

## Scope

**In scope**: the Settings screen's layout and grouping, the signed-in row, Log out
styling, and whatever minimal auth change FR-2's decision requires.

**Out of scope**: a full profile screen; avatars or profile photos if FR-2 decides
against storing them; bottom navigation; changing what any setting does; account deletion.

## Open Questions (for Technical Design, not Inception)
- FR-2's core decision: store a display name, or not.
- Whether Apple's name (given only on first authorization) is reliable enough to depend on.
- Whether the groups should be a reusable widget, given no other screen needs one today.
