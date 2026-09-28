import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes, useParams } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { POPOVER_GAP, POPOVER_MARGIN } from '../ui/popover'
import { AddExerciseMenu } from './AddExerciseMenu'

// jsdom has no layout: the button's box, the menu's natural height and the
// window's height are set per test.
let rect = { top: 100, bottom: 132, left: 800, right: 900, width: 100, height: 32 }
const MENU_HEIGHT = 420
let innerHeight = 800

const windowSize = {
  innerHeight: Object.getOwnPropertyDescriptor(window, 'innerHeight'),
  innerWidth: Object.getOwnPropertyDescriptor(window, 'innerWidth'),
}

beforeEach(() => {
  rect = { top: 100, bottom: 132, left: 800, right: 900, width: 100, height: 32 }
  innerHeight = 800
  // Own properties on HTMLElement.prototype shadow Element's until deleted.
  Object.defineProperty(HTMLElement.prototype, 'getBoundingClientRect', {
    configurable: true,
    value: () => ({ ...rect, x: rect.left, y: rect.top, toJSON: () => rect }),
  })
  Object.defineProperty(HTMLElement.prototype, 'scrollHeight', {
    configurable: true,
    get(this: HTMLElement) {
      return this.tagName === 'NAV' ? MENU_HEIGHT : 0
    },
  })
  Object.defineProperty(window, 'innerHeight', { configurable: true, get: () => innerHeight })
  Object.defineProperty(window, 'innerWidth', { configurable: true, get: () => 1280 })
})

afterEach(() => {
  vi.restoreAllMocks()
  const proto = HTMLElement.prototype as unknown as Record<string, unknown>
  delete proto.getBoundingClientRect
  delete proto.scrollHeight
  for (const [key, descriptor] of Object.entries(windowSize)) {
    if (descriptor) Object.defineProperty(window, key, descriptor)
    else delete (window as unknown as Record<string, unknown>)[key]
  }
})

function Editor() {
  const { type } = useParams()
  return <h1>New {type}</h1>
}

/** The menu inside a card that hides its overflow, as the tree's cards do. */
function renderMenu() {
  return render(
    <MemoryRouter initialEntries={['/courses/c-1']}>
      <Routes>
        <Route
          path="/courses/c-1"
          element={
            <div data-testid="card" style={{ overflow: 'hidden' }}>
              <AddExerciseMenu courseId="c-1" lessonId="l-1" />
            </div>
          }
        />
        <Route path="/courses/:courseId/lessons/:lessonId/exercises/new/:type" element={<Editor />} />
      </Routes>
    </MemoryRouter>,
  )
}

const addButton = () => screen.getByRole('button', { name: /Add exercise/ })
const menu = () => screen.getByRole('navigation', { name: 'Exercise type' })
const links = () => within(menu()).getAllByRole('link')

async function open(): Promise<HTMLElement> {
  await userEvent.click(addButton())
  return menu()
}

describe('the add exercise menu', () => {
  it('is drawn on the page, not inside the card that would clip it', async () => {
    renderMenu()
    const nav = await open()

    expect(screen.getByTestId('card')).not.toContainElement(nav)
    expect(nav.parentElement).toBe(document.body)
    expect(nav).toHaveClass('fixed')
    expect(nav.style.visibility).toBe('')
    expect(addButton()).toHaveAttribute('aria-expanded', 'true')
  })

  it('opens below the button, right-aligned, when there is room', async () => {
    renderMenu()
    const nav = await open()

    expect(nav.style.top).toBe(`${rect.bottom + POPOVER_GAP}px`)
    expect(nav.style.bottom).toBe('')
    expect(nav.style.left).toBe(`${rect.right - 288}px`)
    expect(nav.style.maxHeight).toBe(`${innerHeight - rect.bottom - POPOVER_GAP - POPOVER_MARGIN}px`)
  })

  it('opens above the button near the bottom of the window', async () => {
    rect = { ...rect, top: 600, bottom: 632 }
    renderMenu()
    const nav = await open()

    expect(nav.style.top).toBe('')
    expect(nav.style.bottom).toBe(`${innerHeight - 600 + POPOVER_GAP}px`)
    expect(nav.style.maxHeight).toBe(`${600 - POPOVER_GAP - POPOVER_MARGIN}px`)
  })

  it('is capped to the room there is, and scrolls inside', async () => {
    innerHeight = 360
    rect = { ...rect, top: 150, bottom: 182 }
    renderMenu()
    const nav = await open()

    const cap = parseFloat(nav.style.maxHeight)
    expect(cap).toBeLessThan(MENU_HEIGHT)
    expect(cap).toBe(innerHeight - 182 - POPOVER_GAP - POPOVER_MARGIN)
    expect(nav).toHaveClass('overflow-y-auto')
  })

  it('follows the button when the page scrolls', async () => {
    renderMenu()
    const nav = await open()

    rect = { ...rect, top: 40, bottom: 72 }
    fireEvent.scroll(window)
    expect(nav.style.top).toBe(`${72 + POPOVER_GAP}px`)

    // A scroll inside any other scroller counts too.
    rect = { ...rect, top: 20, bottom: 52 }
    fireEvent.scroll(screen.getByTestId('card'))
    expect(nav.style.top).toBe(`${52 + POPOVER_GAP}px`)
  })

  it('moves focus to the first type, and the arrow keys, Home and End move between types', async () => {
    renderMenu()
    await open()
    const all = links()

    expect(all[0]).toHaveFocus()
    await userEvent.keyboard('{ArrowDown}')
    expect(all[1]).toHaveFocus()
    await userEvent.keyboard('{ArrowUp}{ArrowUp}')
    expect(all.at(-1)).toHaveFocus()
    await userEvent.keyboard('{ArrowDown}')
    expect(all[0]).toHaveFocus()
    await userEvent.keyboard('{End}')
    expect(all.at(-1)).toHaveFocus()
    await userEvent.keyboard('{Home}')
    expect(all[0]).toHaveFocus()
  })

  it('Escape closes it and gives focus back to the button', async () => {
    renderMenu()
    await open()

    await userEvent.keyboard('{Escape}')

    expect(screen.queryByRole('navigation')).toBeNull()
    expect(addButton()).toHaveFocus()
    expect(addButton()).toHaveAttribute('aria-expanded', 'false')
  })

  it('Tab closes it and goes back to the button', async () => {
    renderMenu()
    await open()

    fireEvent.keyDown(links()[0]!, { key: 'Tab' })

    expect(screen.queryByRole('navigation')).toBeNull()
    expect(addButton()).toHaveFocus()
  })

  it('a click outside closes it; a click inside does not', async () => {
    renderMenu()
    const nav = await open()

    fireEvent.mouseDown(nav)
    expect(screen.getByRole('navigation')).toBeInTheDocument()

    await userEvent.click(document.body)
    expect(screen.queryByRole('navigation')).toBeNull()
  })

  it('the button toggles it', async () => {
    renderMenu()
    await open()

    await userEvent.click(addButton())

    expect(screen.queryByRole('navigation')).toBeNull()
  })

  it('choosing a type opens its editor and closes the menu', async () => {
    renderMenu()
    await open()

    await userEvent.click(within(menu()).getByRole('link', { name: /Match pairs/ }))

    expect(await screen.findByRole('heading', { name: 'New match_pairs' })).toBeInTheDocument()
    expect(screen.queryByRole('navigation')).toBeNull()
  })

  it('stops listening once closed', async () => {
    const removed = vi.spyOn(window, 'removeEventListener')
    renderMenu()
    await open()

    await userEvent.keyboard('{Escape}')

    const events = removed.mock.calls.map(([type]) => type)
    expect(events).toEqual(expect.arrayContaining(['scroll', 'resize']))
  })
})
