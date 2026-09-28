import { describe, expect, it } from 'vitest'

import { placePopover, POPOVER_GAP, POPOVER_MARGIN } from './popover'

const WIDE = { width: 1280, height: 800 }
const button = (top: number, right = 900) => ({ top, bottom: top + 32, right })

describe('placePopover', () => {
  it('opens below, right-aligned with the button, when it fits', () => {
    expect(placePopover(button(100), 400, 288, WIDE)).toEqual({
      top: 132 + POPOVER_GAP,
      left: 900 - 288,
      width: 288,
      maxHeight: 800 - 132 - POPOVER_GAP - POPOVER_MARGIN,
    })
  })

  it('opens above when it does not fit below and there is more room above', () => {
    const at = placePopover(button(600), 400, 288, WIDE)
    expect(at.top).toBeUndefined()
    expect(at.bottom).toBe(800 - 600 + POPOVER_GAP)
    expect(at.maxHeight).toBe(600 - POPOVER_GAP - POPOVER_MARGIN)
  })

  it('stays below, capped, when neither side fits and below has as much room', () => {
    const at = placePopover(button(130), 400, 288, { width: 1280, height: 300 })
    expect(at.top).toBe(162 + POPOVER_GAP)
    expect(at.maxHeight).toBe(300 - 162 - POPOVER_GAP - POPOVER_MARGIN)
    expect(at.maxHeight).toBeLessThan(400)
  })

  it('opens above, capped, when neither side fits and above has more room', () => {
    const at = placePopover(button(200), 400, 288, { width: 1280, height: 300 })
    expect(at.bottom).toBe(300 - 200 + POPOVER_GAP)
    expect(at.maxHeight).toBe(200 - POPOVER_GAP - POPOVER_MARGIN)
  })

  it('on a phone, narrows to the window less its margins and keeps inside it', () => {
    const at = placePopover(button(100, 300), 400, 288, { width: 290, height: 700 })
    expect(at.width).toBe(290 - 2 * POPOVER_MARGIN)
    expect(at.left).toBe(POPOVER_MARGIN)
  })

  it('never starts left of the margin, or ends right of it', () => {
    expect(placePopover(button(100, 40), 100, 288, WIDE).left).toBe(POPOVER_MARGIN)
    const offRight = placePopover(button(100, 1400), 100, 288, WIDE)
    expect(offRight.left + offRight.width).toBe(1280 - POPOVER_MARGIN)
  })

  it('never gives a negative room', () => {
    const at = placePopover({ top: -50, bottom: -18, right: 500 }, 100, 288, WIDE)
    expect(at.maxHeight).toBeGreaterThanOrEqual(0)
  })
})
