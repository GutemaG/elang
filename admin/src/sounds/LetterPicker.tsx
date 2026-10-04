import { useCallback, useId, useLayoutEffect, useRef, useState, type KeyboardEvent } from 'react'
import { createPortal } from 'react-dom'

import type { AdminSoundLetter } from '../types'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS } from '../ui/Input'
import { placePopover, type Placement } from '../ui/popover'
import { searchLetters } from './model'

const labelOf = (x: AdminSoundLetter) => `${x.glyph} · ${x.romanization}`

/** A letter chosen by typing: its romanization (`hu`), the glyph (`ሁ`) or
 * an English hint narrows the list, best match first. Arrow keys move,
 * Enter picks and Escape puts the choice back.
 *
 * The list is drawn on `document.body`, fixed to the field, so the table's
 * scrolling box does not clip it. */
export function LetterPicker({
  letters,
  value,
  label,
  disabled,
  onPick,
}: {
  letters: AdminSoundLetter[]
  value: string
  label: string
  disabled?: boolean
  onPick: (letterId: string) => void
}) {
  const chosen = letters.find((x) => x.id === value)
  const [query, setQuery] = useState<string | null>(null)
  const [active, setActive] = useState(0)
  const [placement, setPlacement] = useState<Placement | null>(null)
  const field = useRef<HTMLInputElement>(null)
  const list = useRef<HTMLUListElement>(null)
  const listId = useId()

  const open = query !== null
  const found = open ? searchLetters(letters, query) : []

  const close = () => {
    setQuery(null)
    setPlacement(null)
  }

  const pick = (letter: AdminSoundLetter | undefined) => {
    if (letter) onPick(letter.id)
    close()
  }

  const place = useCallback(() => {
    if (!field.current || !list.current) return
    const rect = field.current.getBoundingClientRect()
    setPlacement(
      placePopover(rect, list.current.scrollHeight, Math.max(rect.right - rect.left, 224), {
        width: window.innerWidth,
        height: window.innerHeight,
      }),
    )
  }, [])

  useLayoutEffect(() => {
    if (!open) return
    place()
    window.addEventListener('scroll', place, true)
    window.addEventListener('resize', place)
    return () => {
      window.removeEventListener('scroll', place, true)
      window.removeEventListener('resize', place)
    }
  }, [open, place, found.length])

  // The highlighted letter stays in view as the arrows move it.
  useLayoutEffect(() => {
    list.current?.querySelector('[aria-selected="true"]')?.scrollIntoView?.({ block: 'nearest' })
  }, [active, open])

  const onKey = (e: KeyboardEvent) => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      if (!open) {
        setQuery('')
        setActive(Math.max(0, letters.findIndex((x) => x.id === value)))
        return
      }
      const step = e.key === 'ArrowDown' ? 1 : -1
      setActive((a) => (found.length ? (a + step + found.length) % found.length : 0))
    } else if (e.key === 'Enter' && open) {
      e.preventDefault()
      pick(found[active])
    } else if (e.key === 'Escape' && open) {
      e.preventDefault()
      close()
    }
  }

  return (
    <div className="relative min-w-[11rem]">
      <input
        ref={field}
        role="combobox"
        aria-label={label}
        aria-expanded={open}
        aria-controls={listId}
        aria-autocomplete="list"
        aria-activedescendant={open && found[active] ? `${listId}-${found[active].id}` : undefined}
        autoComplete="off"
        spellCheck={false}
        disabled={disabled}
        placeholder={chosen ? labelOf(chosen) : 'Type hu, ሁ or a hint'}
        value={query ?? (chosen ? labelOf(chosen) : '')}
        className={cx(FIELD_CLASS, 'h-9 pr-8 sm:h-9', !chosen && !open && 'border-terracotta/60')}
        onFocus={(e) => {
          e.target.select()
        }}
        onClick={() => {
          if (!open) {
            setQuery('')
            setActive(0)
          }
        }}
        onChange={(e) => {
          setQuery(e.target.value)
          setActive(0)
        }}
        onKeyDown={onKey}
        onBlur={close}
      />
      <Icon
        name={open ? 'search' : 'expand_more'}
        className="pointer-events-none absolute top-1/2 right-2 -translate-y-1/2 text-lg text-stone"
      />
      {open &&
        createPortal(
          <ul
            ref={list}
            id={listId}
            role="listbox"
            aria-label={label}
            // Keeps focus in the field, so a click picks before the blur closes the list.
            onMouseDown={(e) => e.preventDefault()}
            style={
              placement
                ? {
                    top: placement.top,
                    bottom: placement.bottom,
                    left: placement.left,
                    width: placement.width,
                    maxHeight: Math.min(placement.maxHeight, 320),
                  }
                : { top: 0, left: 0, width: 224, visibility: 'hidden' }
            }
            className="fixed z-40 overflow-y-auto overscroll-contain rounded-md border border-line bg-surface p-1 shadow-e2"
          >
            {found.length === 0 && <li className="px-3 py-2 text-sm text-stone">No letter matches “{query}”.</li>}
            {found.map((x, i) => (
              <li
                key={x.id}
                id={`${listId}-${x.id}`}
                role="option"
                aria-selected={i === active}
                onMouseEnter={() => setActive(i)}
                onClick={() => pick(x)}
                className={cx(
                  'flex cursor-pointer items-center gap-3 rounded px-2.5 py-1.5 text-sm',
                  i === active && 'bg-inset',
                  x.id === value && 'font-semibold',
                )}
              >
                <span className="w-8 text-center text-lg leading-6 text-coffee">{x.glyph}</span>
                <span className="flex-1 font-mono text-xs text-coffee-soft">{x.romanization}</span>
                {x.id === value && <Icon name="check" className="text-base text-forest" />}
                {x.audio_url && x.id !== value && <span className="text-[0.6875rem] text-stone">Recorded</span>}
              </li>
            ))}
          </ul>,
          document.body,
        )}
    </div>
  )
}
