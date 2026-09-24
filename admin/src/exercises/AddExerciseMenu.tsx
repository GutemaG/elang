import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'

import { EXERCISE_TYPES } from '../types'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { TYPE_INFO } from './model'

/** "Add exercise" on a lesson: pick the type once, then fill it in on the
 * editor page. The type cannot be changed after that. */
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
  const box = useRef<HTMLDivElement>(null)

  // Clicking anywhere else closes it.
  useEffect(() => {
    if (!open) return
    const away = (e: MouseEvent) => {
      if (!box.current?.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', away)
    return () => document.removeEventListener('mousedown', away)
  }, [open])

  return (
    <div ref={box} className="relative mr-1" onKeyDown={(e) => e.key === 'Escape' && setOpen(false)}>
      <Button
        size="sm"
        variant="outline"
        disabled={disabled}
        aria-expanded={open}
        title="Add exercise"
        onClick={() => setOpen((o) => !o)}
      >
        <Icon name="add" className="text-lg sm:text-base" />
        <span className="sr-only sm:not-sr-only">Add exercise</span>
      </Button>
      {open && (
        <nav
          aria-label="Exercise type"
          className="absolute right-0 z-20 mt-1 w-72 rounded-md border border-line bg-surface p-1.5 shadow-e2"
        >
          <p className="px-2.5 pt-1.5 pb-1 text-[0.6875rem] font-bold tracking-[0.06em] text-stone uppercase">
            Choose a type
          </p>
          {EXERCISE_TYPES.map((type) => (
            <Link
              key={type}
              to={`/courses/${courseId}/lessons/${lessonId}/exercises/new/${type}`}
              className="flex items-start gap-3 rounded px-2.5 py-2 hover:bg-inset"
            >
              <Icon name={TYPE_INFO[type].icon} className="mt-0.5 text-lg text-forest" />
              <span>
                <span className="block text-sm font-semibold text-coffee">{TYPE_INFO[type].name}</span>
                <span className="block text-xs text-stone">{TYPE_INFO[type].description}</span>
              </span>
            </Link>
          ))}
        </nav>
      )}
    </div>
  )
}
