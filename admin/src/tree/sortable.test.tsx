import { act, fireEvent, render, screen } from '@testing-library/react'
import { useState } from 'react'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'

import { DragHandle, SortableItem, SortableList } from './Sortable'

// jsdom has no layout and no PointerEvent. Rows are laid out here instead,
// 50px apart by their place in the list, and a PointerEvent is a MouseEvent
// that is always the primary pointer.
const ROW = 50

beforeEach(() => {
  class PointerEvent extends MouseEvent {
    readonly isPrimary = true
  }
  Object.defineProperty(window, 'PointerEvent', { configurable: true, value: PointerEvent })
  Object.defineProperty(HTMLElement.prototype, 'getBoundingClientRect', {
    configurable: true,
    value(this: HTMLElement) {
      const row = this.closest('li')
      const index = row ? Array.from(row.parentElement!.children).indexOf(row) : 0
      const top = index * ROW
      return { top, bottom: top + 40, left: 0, right: 300, width: 300, height: 40, x: 0, y: top, toJSON: () => ({}) }
    },
  })
})

afterEach(() => {
  delete (window as unknown as Record<string, unknown>).PointerEvent
  delete (HTMLElement.prototype as unknown as Record<string, unknown>).getBoundingClientRect
})

function Letters({ disabled = false }: { disabled?: boolean }) {
  const [ids, setIds] = useState(['a', 'b', 'c'])
  return (
    <SortableList ids={ids} nameOf={(id) => `letter ${id}`} onReorder={setIds} disabled={disabled}>
      <ul aria-label="Letters">
        {ids.map((id) => (
          <SortableItem key={id} id={id}>
            <DragHandle name={`letter ${id}`} />
            <span data-testid="letter">{id}</span>
          </SortableItem>
        ))}
      </ul>
    </SortableList>
  )
}

const order = () => screen.getAllByTestId('letter').map((el) => el.textContent)
const handle = (id: string) => screen.getByRole('button', { name: `Move letter ${id}` })

/** Presses on a handle, moves by `dy` in steps, and lets go. */
async function drag(id: string, dy: number): Promise<void> {
  const start = { clientX: 10, clientY: 20 }
  fireEvent.pointerDown(handle(id), { ...start, button: 0 })
  for (const step of [5, dy / 2, dy]) {
    await act(async () => {
      fireEvent.pointerMove(document, { clientX: 10, clientY: start.clientY + step })
    })
  }
  await act(async () => {
    fireEvent.pointerUp(document, { clientX: 10, clientY: start.clientY + dy })
  })
}

describe('a sortable list', () => {
  it('a row dragged down by its handle lands where it is dropped', async () => {
    render(<Letters />)

    await drag('a', 2 * ROW)

    expect(order()).toEqual(['b', 'c', 'a'])
  })

  it('a row dragged up lands above', async () => {
    render(<Letters />)

    await drag('c', -2 * ROW)

    expect(order()).toEqual(['c', 'a', 'b'])
  })

  it('a click on the handle, with no travel, moves nothing', async () => {
    render(<Letters />)

    fireEvent.pointerDown(handle('a'), { clientX: 10, clientY: 20, button: 0 })
    fireEvent.pointerUp(document, { clientX: 10, clientY: 21 })

    expect(order()).toEqual(['a', 'b', 'c'])
  })

  it('the arrow keys move a row one place, and the others do nothing', async () => {
    render(<Letters />)

    fireEvent.keyDown(handle('b'), { key: 'ArrowUp' })
    expect(order()).toEqual(['b', 'a', 'c'])
    fireEvent.keyDown(handle('b'), { key: 'ArrowDown' })
    fireEvent.keyDown(handle('b'), { key: 'ArrowDown' })
    expect(order()).toEqual(['a', 'c', 'b'])
    fireEvent.keyDown(handle('b'), { key: 'Enter' })
    expect(order()).toEqual(['a', 'c', 'b'])
  })

  it('tells a screen reader how to move a row', () => {
    render(<Letters />)

    const described = document.getElementById(handle('a').getAttribute('aria-describedby') ?? '')
    expect(described).toHaveTextContent('Press the up or down arrow to move it, or drag it.')
  })

  it('does nothing while disabled', async () => {
    render(<Letters disabled />)

    expect(handle('a')).toBeDisabled()
    await drag('a', 2 * ROW)

    expect(order()).toEqual(['a', 'b', 'c'])
  })
})
