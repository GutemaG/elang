---
name: Highland Pulse
colors:
  surface: '#fff8f5'
  surface-dim: '#e2d8d2'
  surface-bright: '#fff8f5'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fcf2eb'
  surface-container: '#f6ece6'
  surface-container-high: '#f0e6e0'
  surface-container-highest: '#eae1da'
  on-surface: '#1f1b17'
  on-surface-variant: '#41493e'
  inverse-surface: '#342f2b'
  inverse-on-surface: '#f9efe8'
  outline: '#717a6d'
  outline-variant: '#c0c9bb'
  surface-tint: '#2a6b2c'
  primary: '#00450d'
  on-primary: '#ffffff'
  primary-container: '#1b5e20'
  on-primary-container: '#90d689'
  inverse-primary: '#91d78a'
  secondary: '#745853'
  on-secondary: '#ffffff'
  secondary-container: '#fed7d0'
  on-secondary-container: '#795c57'
  tertiary: '#6c2200'
  on-tertiary: '#ffffff'
  tertiary-container: '#933100'
  on-tertiary-container: '#ffb498'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#acf4a4'
  primary-fixed-dim: '#91d78a'
  on-primary-fixed: '#002203'
  on-primary-fixed-variant: '#0c5216'
  secondary-fixed: '#ffdad4'
  secondary-fixed-dim: '#e3beb8'
  on-secondary-fixed: '#2b1613'
  on-secondary-fixed-variant: '#5b403c'
  tertiary-fixed: '#ffdbcf'
  tertiary-fixed-dim: '#ffb59a'
  on-tertiary-fixed: '#380d00'
  on-tertiary-fixed-variant: '#802a00'
  background: '#fff8f5'
  on-background: '#1f1b17'
  surface-variant: '#eae1da'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 2.25rem
    fontWeight: '700'
    lineHeight: 2.75rem
    letterSpacing: -0.025em
  display-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.75rem
    fontWeight: '700'
    lineHeight: 2.25rem
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.75rem
    fontWeight: '700'
    lineHeight: 2.25rem
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.375rem
    fontWeight: '700'
    lineHeight: 1.75rem
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.25rem
    fontWeight: '600'
    lineHeight: 1.75rem
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.125rem
    fontWeight: '600'
    lineHeight: 1.5rem
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 1rem
    fontWeight: '400'
    lineHeight: 1.5rem
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.875rem
    fontWeight: '400'
    lineHeight: 1.25rem
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.75rem
    fontWeight: '400'
    lineHeight: 1rem
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.875rem
    fontWeight: '600'
    lineHeight: 1.25rem
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.75rem
    fontWeight: '600'
    lineHeight: 1rem
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.6875rem
    fontWeight: '700'
    lineHeight: 0.875rem
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-tablet: 1.5rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

> **Source:** exported from Google Stitch ("Highland Pulse") on 2026-09-22 and
> copied here unchanged below this note; the mockup images stay out of git.
> The admin site implements it in `admin/src/styles.css` as Tailwind v4 theme
> tokens under shorter names: `canvas`, `surface`, `inset`, `line`, `forest`,
> `coffee`, `terracotta`, `stone`, `danger`, and shadows `e1`–`e3`. Where the
> Material-style palette in the frontmatter and the prose below disagree
> (primary `#00450d` vs `#1B5E20`), the site follows the prose.

## Brand & Style
The design system pairs high-density pedagogical admin utilities with the organic warmth of Ethiopian cultural heritage—drawing inspiration from shaded highland acacia forests, sun-baked clay vessels, and the communal warmth of the coffee ceremony (*buna*). 

The visual style is **Contemporary Warm SaaS**: a precise, highly legible administrative platform grounded in systematic utility, soft tactile warmth, and functional elegance. Rather than relying on generic sterile slate palettes, the interface uses earthy organic depths (deep forest acacia green and roasted coffee roast) counterbalanced by bright, porous parchment tones and vivid terracotta accents.

Target users include curriculum directors, native linguists, and audio content editors operating in fast-paced content-authoring environments. The interface conveys scholarly authority, streamlined precision, and inviting hospitality, remaining uncrowded and responsive even across dense data tables, script-heavy syllabaries (Ge'ez and Latin scripts), and nested audio lesson builders.

## Colors
The palette balances institutional trust with warm, tactile grounding. 

- **Primary (`#1B5E20`)**: Deep Forest Acacia Green. Anchor for primary buttons, active administrative routes, major key indicators, and navigational selections. Represents vitality and scholarly growth.
- **Secondary (`#3E2723`)**: Roasted Coffee Bean. Anchors text hierarchy, section headings, high-importance counters, and grounded structural containers like collapsed drawers and dark header states.
- **Tertiary (`#E65100`)**: Highland Terracotta / Ochre. Reserved for active recording states, hot edits, alert badges, contextual quick actions, and audio waveform timeline cursors.
- **Neutral (`#78716C`)**: Warm Stone Neutral. Bridges crisp UI outlines with organic background surfaces (`#FDFBF7`), preventing visual fatigue and giving hairline borders structural crispness without harsh digital grey.

### Supporting Semantic Tokens
- **Canvas Base**: `#FDFBF7` (Crisp Parchment White).
- **Surface Elevation 1**: `#FFFFFF` (Pure Crisp White for Cards and Drawers).
- **Surface Elevation 2**: `#F5EFEB` (Muted Warm Cream for Inset Panels & Audio Strips).
- **Border Subtle**: `#E2E8F0` (Modern Slate Hairline).
- **Border Distinct**: `#D6D3D1` (Stone Outline for Focus Rings and Inputs).

## Typography
Plus Jakarta Sans provides high x-height, clear apertures, and geometric clarity, serving administrative data density alongside multi-script contexts (including Ge'ez transliteration, phonetic notation, and dual-script glossaries).

### Script Handling & Metrics
- Headings maintain tight negative tracking (`-0.02em` to `-0.015em`) to retain punchiness in responsive dashboard headers.
- All numbers, statistics, lesson counts, and timestamps leverage tabular figures (`font-variant-numeric: tabular-nums`) to ensure strict alignment across data grids and audio timeline track scrubbers.
- In multi-script metadata views (e.g., Amharic Fidel, Afaan Oromoo, Tigrinya paired with English titles), increase body line heights dynamically by 10% to prevent tall accent and vowel mark clipping.

## Layout & Spacing
The layout follows a fluid-responsive responsive model engineered for multi-device editorial workflows:

- **Desktop (1280px+)**: 12-column grid system with 24px (`1.5rem`) gutters and 32px (`2rem`) margins. Permanent collapsible sidebar (72px collapsed / 260px expanded).
- **Tablet (768px - 1279px)**: 8-column layout with 16px (`1rem`) gutters and 24px (`1.5rem`) margins. Rail navigation dock with sliding modal sheet editors.
- **Mobile (< 768px)**: 4-column layout with 16px (`1rem`) gutters and 16px (`1rem`) outer canvas margins. Full-width cards, edge-pinned bottom navigation, and top bar with an off-canvas slideover drawer.

### High-Density Vertical Rhythm
Admin tools demand minimal wasted space. Standard form-group vertical stack gap is fixed to `space-md` (12px). Dense data lists (curriculum drag modules, vocab banks) utilize `space-sm` (8px) internal row padding to allow visibility of 10+ items above the mobile fold without scrolling fatigue.

## Elevation & Depth
Depth in the system is created through **Tonal Surface Stratification combined with Warm Ambient Diffusion**, eliminating sterile grey drop shadows:

- **Level 0 (Canvas Base)**: `#FDFBF7`. Flat textured base canvas.
- **Level 1 (Card & Module Resting)**: `#FFFFFF` resting on `#FDFBF7`, framed with a single hairline border `1px solid #E2E8F0`. Shadow: `0 1px 3px 0 rgba(62, 39, 35, 0.04), 0 1px 2px -1px rgba(62, 39, 35, 0.02)`.
- **Level 2 (Dropdowns, KPI Highlights, Popovers)**: `#FFFFFF` container. Shadow: `0 4px 6px -1px rgba(62, 39, 35, 0.07), 0 2px 4px -2px rgba(62, 39, 35, 0.05)`.
- **Level 3 (Floating Quick Actions, Draggable Course Nodes Active Drag)**: Lifted elevated state. Border: `1px solid #1B5E20/20`. Shadow: `0 10px 15px -3px rgba(27, 94, 32, 0.12), 0 4px 6px -4px rgba(62, 39, 35, 0.08)`.
- **Level 4 (Modal Drawers & Full Screen Editors)**: Fixed pinned sheets over an ochre-tinted dark veil (`rgba(30, 20, 18, 0.45)` backdrop).

## Shapes
The design system adopts **Level 2 Roundedness** (0.5rem / 8px default radius):
- Standard interactive elements (buttons, inputs, status cards) utilize `0.5rem` (8px), conveying balanced, modern administrative utility.
- Nested sub-elements (audio scrubber thumbnails, nested chips, audio playback badges) step down to `0.25rem` (4px).
- Modals, large surface panels, and bottom sheets use `1rem` (16px) top radius for ergonomic handling.
- Status badges and floating quick actions implement full circular or pill encapsulation (`9999px`) to immediately distinguish active micro-states from form controls.

## Components

### Buttons
- **Primary**: Background `#1B5E20`, text `#FFFFFF`, border `transparent`. Hover: `#144818`. Focus ring: `2px solid #E65100` with 2px offset.
- **Secondary (Buna Roast)**: Background `#3E2723`, text `#FFFFFF`. Used for final publishing, irreversible content updates, or batch exports.
- **Outline / Ghost**: Background `transparent`, text `#3E2723`, border `1px solid #E2E8F0`. Hover: background `#F5EFEB`.
- **Mobile Tap Targets**: Strict minimum height of 44px on touch viewports (`h-11` or `h-12`).

### Status Badges & Pills
- **Published**: Pill-shaped (`rounded-full`), background `#E8F5E9`, text `#1B5E20`, border `1px solid #C8E6C9`, uppercase label-sm. Leading `6px` solid emerald dot.
- **Draft**: Background `#FFF3E0`, text `#E65100`, border `1px solid #FFE0B2`. Leading `6px` solid terracotta dot.
- **Archived**: Background `#F1F5F9`, text `#64748B`, border `1px solid #E2E8F0`.

### KPI Stat Cards
- Enclosed in Level 1 white surfaces (`#FFFFFF`) with hairline slate borders (`#E2E8F0`).
- Mobile-optimized: Compact padding (`p-4`), display metric stacked directly above comparison indicators.
- Metrics display secondary dark coffee value with micro-trend indicator (+14% active learners) in primary forest green.

### Hierarchy Handles & Drag-and-Drop Course Nodes
- Used for structural unit/lesson re-ordering.
- Features a left-hand 6-dot textured drag handle (`#78716C`) with active grab states.
- When an item is dragged: elevated to Level 3 depth, rotation of `1deg`, border switches to `1.5px solid #1B5E20`, and drop target lines display as a continuous `#E65100` terracotta rule.

### Audio Recording & Waveform Indicator
- Admin-specific utility for speech analysis and vocabulary pronunciation review.
- Container: Inset cream panel (`#F5EFEB`) with rounded corners (`rounded-lg`).
- **Waveform Canvas**: Audio bars rendered in `#1B5E20` for completed waveforms, `#E65100` for the real-time recording playhead cursor.
- **Record Action**: Circular pill button with pulsing concentric rings during active audio capture. Includes millisecond elapsed timer rendered in monospaced tabular figures.

### Form Inputs & Selectors
- Background `#FFFFFF`, border `1px solid #E2E8F0`, corner radius `rounded-md` (8px), height 40px (44px on mobile).
- Input labels use `label-md` in Roasted Coffee (`#3E2723`).
- Focus state: Border switches to `#1B5E20` with a soft `3px` ambient ring in `#1B5E20/15`.

### Navigation: Collapsible App Bar & Floating Quick Actions (FQA)
- **Top App Bar**: Sticky glass-morphic banner (`background: rgba(253, 251, 247, 0.92); backdrop-filter: blur(8px)`), housing active course selectors, language switcher (Amharic, Afaan Oromoo, Tigrinya, English), and hamburger trigger.
- **Mobile Bottom Bar / Drawer**: Slide-over navigation panel surfaced in `#FFFFFF`, with route selections featuring 3px left-accent bars in forest green when active.
- **Floating Quick Action (FQA)**: Mobile action button positioned at bottom right (`bottom-6 right-6`), sized 56x56px, background `#E65100`, foreground white icon, elevated at Level 3. Triggers quick voice recording, unit creation, or quick asset preview.