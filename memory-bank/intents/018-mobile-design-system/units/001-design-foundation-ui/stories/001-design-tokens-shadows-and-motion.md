---
id: 001-design-tokens-shadows-and-motion
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 042-design-foundation
implemented: true
---

# Story: 001-design-tokens-shadows-and-motion

## User Story

**As a** Buna developer
**I want** every colour, shadow, radius and animation timing as a named token
**So that** no screen ever needs a hex value, a hand-built shadow or a magic number

## Acceptance Criteria

- [x] **Given** FR-1's list, **When** the tokens land, **Then** each colour (the answer-state tints, tile border and shelf, secondary shelf, node colours, streak/gem/XP accents, muted text, track) exists once in `AppColors`, with the DESIGN.md or mockup source named in a comment
- [x] **Given** `AppShadows`, **When** a component asks for a shelf of a colour and depth, **Then** it gets a solid shelf plus the mockups' faint soft shadow, and ready-made `card`, `tile`, `button`, `overlay` and `glow` shadows exist
- [x] **Given** `AppRadii`, **When** the tokens land, **Then** `tile` (20) and `card` (24) exist beside the current values
- [x] **Given** `AppMotion`, **When** the tokens land, **Then** press (100 ms), state change (150 ms) and shake (400 ms) durations and their curves exist
- [x] **Given** the existing copies of these values (`choice_tile.dart`, `match_pairs_builder.dart`, `skill_path_node.dart`, `selectable_option_card.dart`), **When** this story is done, **Then** they read the tokens, and nothing looks different yet

## Reference Design (FR-11)

- DESIGN.md: Colors, Elevation & Depth, Shapes, Components 1-4
- `stich-screens/extracted/stitch_ethiopian_language_learning_app/4._home_skill_tree_dashboard/code.html` and `lesson_complete_summary_1/code.html` for the double shadows (e.g. `0 4px 0 #EDE5D8, 0 4px 16px rgba(35,26,17,.08)`)

## Technical Notes

- Shadow tokens are functions or `List<BoxShadow>` constants; a shelf is `BoxShadow(offset: Offset(0, depth), color: bevel)` with no blur, the soft shadow a second, blurred, low-alpha one.
- Keep the DESIGN.md token names in lowerCamelCase, as `app_colors.dart` already does.

## Dependencies

### Requires
- Nothing

### Enables
- Every other story in this intent

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A token needed later that is not in FR-1 | Added to the token file in that story, never inlined in a widget |

## Out of Scope

- Changing how any screen looks (unit 003)
- Dark-mode tokens
