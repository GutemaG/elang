import { useState, type ReactNode } from 'react'

import { useSession } from '../auth/SessionContext'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { InlineForm, type FormValues } from './InlineForm'
import { LEVELS, routes, type LevelKey } from './levels'
import { DragHandle, SortableItem } from './Sortable'
import { SAVE_ORDER_FIRST, useTreeActions } from './TreeActions'

interface Props {
  level: LevelKey
  id: string
  title: string
  subtitle?: string
  /** Its place in the course, e.g. "01" for a section or "1.2" for a skill. */
  number: string
  /** e.g. "3 skills" */
  countLabel: string
  /** The expanded content: child rows or the exercise list. */
  children: ReactNode
  /** An extra action for a level with no child level of its own: a
   * lesson's "Add exercise". */
  extraAction?: ReactNode
}

type Editing = 'rename' | 'add' | null

// Each level sits one step further into the page: a section is a card, a
// skill a panel inside it, a lesson a row inside that.
const ITEM: Record<LevelKey, string> = {
  section: 'overflow-hidden rounded-lg border border-line bg-surface shadow-e1',
  skill: 'overflow-hidden rounded-md border border-line bg-surface',
  lesson: 'rounded border border-line bg-canvas',
}

const ROW: Record<LevelKey, string> = {
  section: 'gap-3 px-3 py-3 sm:px-5 sm:py-4',
  skill: 'gap-2.5 px-3 py-2.5 sm:px-4',
  lesson: 'gap-2 px-2.5 py-2 sm:px-3',
}

const BODY: Record<LevelKey, string> = {
  section: 'space-y-3 border-t border-line bg-canvas px-2 py-3 sm:pr-5 sm:pl-12',
  skill: 'space-y-2 border-t border-line border-l-[3px] border-l-forest/70 bg-inset/40 px-2 py-3 sm:pr-3 sm:pl-10',
  lesson: 'border-t border-line px-2 py-2.5 sm:pr-3 sm:pl-9',
}

const TITLE: Record<LevelKey, string> = {
  section: 'text-lg leading-6 font-semibold tracking-[-0.015em] text-coffee',
  skill: 'text-[0.9375rem] leading-6 font-semibold text-coffee',
  lesson: 'text-sm leading-5 font-medium text-coffee',
}

/** One section, skill or lesson: its drag handle, title and counts, its
 * actions, and its children when expanded. It sits in a SortableList of its
 * siblings; whether it is open is the tree's, so it outlives the page. */
export function NodeRow({ level, id, title, subtitle, number, countLabel, children, extraAction }: Props) {
  const { api } = useSession()
  const { busy, ordering, run, requestDelete, isOpen, setOpen } = useTreeActions()
  const [editing, setEditing] = useState<Editing>(null)
  const def = LEVELS[level]
  const childLevel = def.child
  const expanded = isOpen(id)
  // Edits wait while a new order is unsaved: their reload would lose it.
  const locked = busy || ordering
  const why = (label: string) => (ordering ? SAVE_ORDER_FIRST : label)

  const rename = (v: FormValues) =>
    run(() => api.patch(routes.node(level, id), def.hasSubtitle ? { title: v.title, subtitle: v.subtitle } : { title: v.title }))

  const addChild = async (v: FormValues) => {
    if (!childLevel) return false
    const ok = await run(() => api.post(routes.create(childLevel, id), { title: v.title }))
    if (ok) setOpen(id, true)
    return ok
  }

  const toggle = () => setOpen(id, !expanded)

  return (
    <SortableItem id={id} data-node={id} className={ITEM[level]}>
      <div className={cx('flex flex-wrap items-center', ROW[level])}>
        <DragHandle name={`${def.name} ${title}`} />
        <Button
          size="icon"
          variant="ghost"
          aria-expanded={expanded}
          aria-label={`${expanded ? 'Collapse' : 'Expand'} ${def.name} ${title}`}
          onClick={toggle}
        >
          <Icon
            name="chevron_right"
            className={cx('text-xl text-stone transition-transform duration-150', expanded && 'rotate-90 text-forest')}
          />
        </Button>

        {editing === 'rename' ? (
          <InlineForm
            label={`Rename ${def.name}`}
            initial={{ title, subtitle }}
            withSubtitle={def.hasSubtitle}
            submitLabel="Save"
            disabled={locked}
            onSubmit={rename}
            onCancel={() => setEditing(null)}
          />
        ) : (
          // A mouse shortcut for the chevron; the chevron is the control.
          <div className="min-w-0 flex-[1_1_14rem] cursor-pointer select-none" onClick={toggle}>
            {level === 'section' ? (
              <>
                <div className="flex flex-wrap items-center gap-2">
                  <span className="rounded-sm bg-forest-tint px-2 py-0.5 text-[0.6875rem] font-bold tracking-[0.06em] text-forest uppercase">
                    Section {number}
                  </span>
                  <span className="tnum rounded-full bg-inset px-2 py-0.5 text-xs font-semibold text-coffee-soft">
                    {countLabel}
                  </span>
                </div>
                <h2 className={cx('mt-1.5 break-words', TITLE.section)}>{title}</h2>
                {subtitle && <p className="mt-0.5 text-sm text-stone">{subtitle}</p>}
              </>
            ) : (
              <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1">
                <span className="tnum text-xs font-bold text-forest">{number}</span>
                <span className={cx('break-words', TITLE[level])}>{title}</span>
                <span className="tnum text-xs font-medium text-stone">{countLabel}</span>
              </div>
            )}
          </div>
        )}

        <div
          className="ml-auto flex flex-wrap items-center gap-0.5"
          role="group"
          aria-label={`Actions for ${def.name} ${title}`}
        >
          {!childLevel && extraAction}
          {childLevel && (
            <Button
              size="sm"
              variant="outline"
              className="mr-1"
              disabled={locked}
              title={why(`Add ${LEVELS[childLevel].name}`)}
              onClick={() => setEditing('add')}
            >
              <Icon name="add" className="text-lg sm:text-base" />
              {/* Icon-only on a phone, so the row's actions fit one line;
                  the text still names the button for screen readers. */}
              <span className="sr-only sm:not-sr-only">Add {LEVELS[childLevel].name}</span>
            </Button>
          )}
          <Button
            size="icon"
            variant="ghost"
            disabled={locked}
            aria-label="Rename"
            title={why('Rename')}
            onClick={() => setEditing('rename')}
          >
            <Icon name="edit" className="text-lg" />
          </Button>
          <Button
            size="icon"
            variant="danger-ghost"
            disabled={locked}
            aria-label="Delete"
            title={why('Delete')}
            onClick={() => requestDelete({ level, id, title })}
          >
            <Icon name="delete" className="text-lg" />
          </Button>
        </div>
      </div>

      {editing === 'add' && childLevel && (
        <div className="border-t border-dashed border-line-strong bg-forest-tint/40 px-3 py-3 sm:pl-12">
          <InlineForm
            label={`Add ${LEVELS[childLevel].name}`}
            submitLabel={`Add ${LEVELS[childLevel].name}`}
            disabled={locked}
            onSubmit={addChild}
            onCancel={() => setEditing(null)}
          />
        </div>
      )}
      {expanded && <div className={BODY[level]}>{children}</div>}
    </SortableItem>
  )
}
