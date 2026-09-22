import { useState, type ReactNode } from 'react'

import { useSession } from '../auth/SessionContext'
import { InlineForm, type FormValues } from './InlineForm'
import { LEVELS, moved, routes, type LevelKey } from './levels'
import { useTreeActions } from './TreeActions'

interface Props {
  level: LevelKey
  id: string
  title: string
  subtitle?: string
  /** e.g. "3 skills" */
  countLabel: string
  /** Every sibling's id in order, this row included -- sent whole on a move. */
  siblingIds: readonly string[]
  parentId: string
  /** The expanded content: child rows or the exercise list. */
  children: ReactNode
}

type Editing = 'rename' | 'add' | null

/** One section, skill or lesson: its title and counts, its actions, and
 * its children when expanded. */
export function NodeRow({ level, id, title, subtitle, countLabel, siblingIds, parentId, children }: Props) {
  const { api } = useSession()
  const { busy, run, requestDelete } = useTreeActions()
  const [expanded, setExpanded] = useState(false)
  const [editing, setEditing] = useState<Editing>(null)
  const def = LEVELS[level]
  const index = siblingIds.indexOf(id)
  const childLevel = def.child

  const move = (by: -1 | 1) => {
    const ids = moved(siblingIds, index, by)
    if (ids) void run(() => api.put(routes.order(level, parentId), { ids }))
  }

  const rename = (v: FormValues) =>
    run(() => api.patch(routes.node(level, id), def.hasSubtitle ? { title: v.title, subtitle: v.subtitle } : { title: v.title }))

  const addChild = async (v: FormValues) => {
    if (!childLevel) return false
    const ok = await run(() => api.post(routes.create(childLevel, id), { title: v.title }))
    if (ok) setExpanded(true)
    return ok
  }

  return (
    <li className={`node node-${level}`}>
      <div className="node-row">
        <button
          type="button"
          className="toggle"
          aria-expanded={expanded}
          aria-label={`${expanded ? 'Collapse' : 'Expand'} ${def.name} ${title}`}
          onClick={() => setExpanded((x) => !x)}
        >
          {expanded ? '▾' : '▸'}
        </button>
        {editing === 'rename' ? (
          <InlineForm
            label={`Rename ${def.name}`}
            initial={{ title, subtitle }}
            withSubtitle={def.hasSubtitle}
            submitLabel="Save"
            disabled={busy}
            onSubmit={rename}
            onCancel={() => setEditing(null)}
          />
        ) : (
          <div className="node-title">
            <span className="title">{title}</span>
            {subtitle && <span className="muted"> — {subtitle}</span>}
            <span className="count">{countLabel}</span>
          </div>
        )}
        <div className="actions" role="group" aria-label={`Actions for ${def.name} ${title}`}>
          <button type="button" disabled={busy} onClick={() => setEditing('rename')}>
            Rename
          </button>
          <button type="button" disabled={busy || index <= 0} aria-label="Move up" title="Move up" onClick={() => move(-1)}>
            ↑
          </button>
          <button
            type="button"
            disabled={busy || index >= siblingIds.length - 1}
            aria-label="Move down"
            title="Move down"
            onClick={() => move(1)}
          >
            ↓
          </button>
          {childLevel && (
            <button type="button" disabled={busy} onClick={() => setEditing('add')}>
              Add {LEVELS[childLevel].name}
            </button>
          )}
          <button type="button" className="danger" disabled={busy} onClick={() => requestDelete({ level, id, title })}>
            Delete
          </button>
        </div>
      </div>
      {editing === 'add' && childLevel && (
        <div className="node-add">
          <InlineForm
            label={`Add ${LEVELS[childLevel].name}`}
            submitLabel={`Add ${LEVELS[childLevel].name}`}
            disabled={busy}
            onSubmit={addChild}
            onCancel={() => setEditing(null)}
          />
        </div>
      )}
      {expanded && <div className="node-children">{children}</div>}
    </li>
  )
}
