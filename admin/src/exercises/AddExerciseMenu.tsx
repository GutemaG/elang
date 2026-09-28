import { useCallback, useEffect, useLayoutEffect, useRef, useState, type KeyboardEvent } from 'react'
import { createPortal } from 'react-dom'
import { Link } from 'react-router-dom'

import { EXERCISE_TYPES } from '../types'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { placePopover, type Placement } from '../ui/popover'
import { TYPE_INFO } from './model'

/** 18rem. */
const MENU_WIDTH = 288

/** "Add exercise" on a lesson: pick the type once, then fill it in on the
 * editor page. The type cannot be changed after that.
 *
 * The menu is drawn on `document.body`, fixed to the button (bolt 040):
 * inside the lesson row it was clipped by the section and skill cards,
 * which hide their overflow for their rounded corners. */
export function AddExerciseMenu({
  courseId,
  lessonId,
  disabled,
}: {
  courseId: string
  lessonId: string
  disabled?: boolean
}) {
  const [open, setOpen] = useState(false)
  const [placement, setPlacement] = useState<Placement | null>(null)
  const button = useRef<HTMLButtonElement>(null)
  const menu = useRef<HTMLElement>(null)

  const close = useCallback((refocus: boolean) => {
    setOpen(false)
    setPlacement(null)
    if (refocus) button.current?.focus()
  }, [])

  const place = useCallback(() => {
    if (!button.current || !menu.current) return
    setPlacement(
      placePopover(button.current.getBoundingClientRect(), menu.current.scrollHeight, MENU_WIDTH, {
        width: window.innerWidth,
        height: window.innerHeight,
      }),
    )
  }, [])

  // Placed before the first paint, then kept with the button as the page
  // scrolls (any scroller, hence capture) or the window resizes.
  useLayoutEffect(() => {
    if (!open) return
    place()
    window.addEventListener('scroll', place, true)
    window.addEventListener('resize', place)
    return () => {
      window.removeEventListener('scroll', place, true)
      window.removeEventListener('resize', place)
    }
  }, [open, place])

  // Opening moves focus to the first type, once the menu is placed (a
  // hidden element cannot take focus).
  const placed = placement !== null
  useEffect(() => {
    if (placed) menu.current?.querySelector<HTMLElement>('a')?.focus()
  }, [placed])

  // Clicking anywhere but the button or the menu closes it.
  useEffect(() => {
    if (!open) return
    const away = (e: MouseEvent) => {
      const target = e.target as Node
      if (!button.current?.contains(target) && !menu.current?.contains(target)) close(false)
    }
    document.addEventListener('mousedown', away)
    return () => document.removeEventListener('mousedown', away)
  }, [open, close])

  const onMenuKey = (e: KeyboardEvent) => {
    if (e.key === 'Escape' || e.key === 'Tab') {
      // Tab goes back to the button, and on from there as it would have.
      if (e.key === 'Escape') e.preventDefault()
      close(true)
      return
    }
    const links = [...(menu.current?.querySelectorAll<HTMLElement>('a') ?? [])]
    const at = links.indexOf(document.activeElement as HTMLElement)
    // Indexes from the end count back from it; both ends wrap round.
    const moves: Record<string, number> = { ArrowDown: at + 1, ArrowUp: at <= 0 ? -1 : at - 1, Home: 0, End: -1 }
    const next = moves[e.key]
    if (next === undefined) return
    e.preventDefault()
    links.at(next % links.length)?.focus()
  }

  return (
    <div className="mr-1">
      <Button
        ref={button}
        size="sm"
        variant="outline"
        disabled={disabled}
        aria-expanded={open}
        title="Add exercise"
        onClick={() => (open ? close(false) : setOpen(true))}
        onKeyDown={(e) => e.key === 'Escape' && open && close(true)}
      >
        <Icon name="add" className="text-lg sm:text-base" />
        <span className="sr-only sm:not-sr-only">Add exercise</span>
      </Button>
      {open &&
        createPortal(
          <nav
            ref={menu}
            aria-label="Exercise type"
            onKeyDown={onMenuKey}
            style={
              placement
                ? {
                    top: placement.top,
                    bottom: placement.bottom,
                    left: placement.left,
                    width: placement.width,
                    maxHeight: placement.maxHeight,
                  }
                : // Measured unseen first, so it never shows in the wrong place.
                  { top: 0, left: 0, width: MENU_WIDTH, visibility: 'hidden' }
            }
            className="fixed z-40 overflow-y-auto overscroll-contain rounded-md border border-line bg-surface p-1.5 shadow-e2"
          >
            <p className="px-2.5 pt-1.5 pb-1 text-[0.6875rem] font-bold tracking-[0.06em] text-stone uppercase">
              Choose a type
            </p>
            {EXERCISE_TYPES.map((type) => (
              <Link
                key={type}
                to={`/courses/${courseId}/lessons/${lessonId}/exercises/new/${type}`}
                onClick={() => close(false)}
                className="flex items-start gap-3 rounded px-2.5 py-2 hover:bg-inset focus-visible:bg-inset focus-visible:outline-none"
              >
                <Icon name={TYPE_INFO[type].icon} className="mt-0.5 text-lg text-forest" />
                <span>
                  <span className="block text-sm font-semibold text-coffee">{TYPE_INFO[type].name}</span>
                  <span className="block text-xs text-stone">{TYPE_INFO[type].description}</span>
                </span>
              </Link>
            ))}
          </nav>,
          document.body,
        )}
    </div>
  )
}
