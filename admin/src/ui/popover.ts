// Where a pop-up menu goes relative to the button that opened it. Pure, so
// the rules are tested without a layout engine (jsdom has none).

/** Space between the button and the menu. */
export const POPOVER_GAP = 4
/** The menu never comes closer than this to the window's edges. */
export const POPOVER_MARGIN = 8

export interface Rect {
  top: number
  bottom: number
  right: number
}

export interface Viewport {
  width: number
  height: number
}

/** `position: fixed` coordinates. Exactly one of `top` and `bottom` is set:
 * `top` when the menu opens below the button, `bottom` when above. */
export interface Placement {
  top?: number
  bottom?: number
  left: number
  width: number
  /** The room it has; a taller menu scrolls inside it. */
  maxHeight: number
}

/** Right-aligned with the button and kept inside the window. It opens
 * below unless it would not fit there and there is more room above. */
export function placePopover(anchor: Rect, menuHeight: number, preferredWidth: number, viewport: Viewport): Placement {
  const width = Math.max(0, Math.min(preferredWidth, viewport.width - 2 * POPOVER_MARGIN))
  const left = Math.max(POPOVER_MARGIN, Math.min(anchor.right - width, viewport.width - POPOVER_MARGIN - width))
  const below = Math.max(0, viewport.height - anchor.bottom - POPOVER_GAP - POPOVER_MARGIN)
  const above = Math.max(0, anchor.top - POPOVER_GAP - POPOVER_MARGIN)
  if (menuHeight <= below || below >= above) {
    return { top: anchor.bottom + POPOVER_GAP, left, width, maxHeight: below }
  }
  return { bottom: viewport.height - anchor.top + POPOVER_GAP, left, width, maxHeight: above }
}
