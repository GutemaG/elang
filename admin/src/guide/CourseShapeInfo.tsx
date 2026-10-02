import { useEffect, useId, useRef, useState } from 'react'
import { Link } from 'react-router-dom'

import type { AdminCourseTree } from '../types'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { LEVELS, TONES, type LevelKey } from './courseLevels'

const byOrder = <T extends { order_index: number }>(items: T[]): T[] =>
  [...items].sort((a, b) => a.order_index - b.order_index)

// Shown for a level this course has nothing in yet.
const FALLBACK: Record<LevelKey, string> = {
  course: 'English to Amharic',
  section: 'Basics',
  skill: 'Greetings',
  lesson: 'Hello',
  exercise: 'Which one means “hello”?',
}

/** Each level's example, taken from this course's own first section, skill,
 * lesson and exercise where it has them. */
function examplesOf(tree: AdminCourseTree): Record<LevelKey, { text: string; own: boolean }> {
  const section = byOrder(tree.sections)[0]
  const skill = section && byOrder(section.skills)[0]
  const lesson = skill && byOrder(skill.lessons)[0]
  const exercise = lesson && byOrder(lesson.exercises)[0]
  const pick = (key: LevelKey, own: string | undefined) =>
    own ? { text: own, own: true } : { text: FALLBACK[key], own: false }
  return {
    course: pick('course', tree.course.title),
    section: pick('section', section?.title),
    skill: pick('skill', skill?.title),
    lesson: pick('lesson', lesson?.title),
    exercise: pick('exercise', exercise?.prompt),
  }
}

/** An ⓘ beside the course title: how a course is built, as a small
 * diagram filled with this course's own content, without leaving the
 * page. Opens on click; Escape or a click elsewhere closes it. */
export function CourseShapeInfo({ tree }: { tree: AdminCourseTree }) {
  const [open, setOpen] = useState(false)
  const panelId = useId()
  const root = useRef<HTMLDivElement>(null)
  const button = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    if (!open) return
    const away = (e: MouseEvent) => {
      if (!root.current?.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', away)
    return () => document.removeEventListener('mousedown', away)
  }, [open])

  const examples = examplesOf(tree)

  return (
    <div
      ref={root}
      className="inline-flex align-middle"
      onKeyDown={(e) => {
        if (e.key === 'Escape' && open) {
          setOpen(false)
          button.current?.focus()
        }
      }}
    >
      <button
        ref={button}
        type="button"
        aria-label="How a course is built"
        aria-expanded={open}
        aria-controls={panelId}
        title="How a course is built"
        onClick={() => setOpen((o) => !o)}
        className={cx(
          'grid size-9 place-items-center rounded-full text-stone transition-colors hover:bg-inset hover:text-forest',
          open && 'bg-inset text-forest',
        )}
      >
        <Icon name="info" className="text-2xl" />
      </button>
      {open && (
        <div
          id={panelId}
          role="dialog"
          aria-label="How a course is built"
          className="absolute top-full left-0 z-40 mt-2 w-[min(28rem,calc(100vw-2rem))] rounded-lg border border-line bg-surface p-4 shadow-e3"
        >
          <p className="text-sm font-semibold text-coffee">How a course is built</p>
          <p className="mt-1 text-xs leading-5 text-stone">
            Each level holds the one below it. Examples come from this course where it has them.
          </p>
          <ol className="mt-3 space-y-1.5">
            {LEVELS.map((l, i) => (
              <li key={l.key} style={{ marginLeft: `${i * 0.875}rem` }} className="flex items-start gap-2">
                {i > 0 && <Icon name="subdirectory_arrow_right" className="mt-0.5 text-base text-stone-soft" />}
                <span className="min-w-0 flex-1 rounded-md border border-line px-2.5 py-1.5">
                  <span className="flex flex-wrap items-center gap-x-2 gap-y-0.5">
                    <span
                      className={cx(
                        'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[0.625rem] font-bold tracking-[0.08em] uppercase',
                        TONES[l.key].chip,
                      )}
                    >
                      <Icon name={l.icon} className="text-xs" />
                      {l.name}
                    </span>
                    <span className={cx('min-w-0 truncate text-sm', examples[l.key].own ? 'font-semibold text-coffee' : 'text-stone italic')}>
                      {examples[l.key].text}
                    </span>
                  </span>
                  <span className="mt-0.5 block text-xs leading-4 text-stone">{l.app}</span>
                </span>
              </li>
            ))}
          </ol>
          <p className="mt-3 text-xs leading-5 text-stone">
            Skills unlock in order inside a section. A skill is done when all its lessons are.
          </p>
          <Link
            to="/guide"
            className="mt-2 inline-flex items-center gap-1 text-sm font-semibold text-forest hover:underline"
          >
            Open the full guide
            <Icon name="arrow_forward" className="text-base" />
          </Link>
        </div>
      )}
    </div>
  )
}
