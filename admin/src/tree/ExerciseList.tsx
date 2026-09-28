import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { ExercisePreview } from '../exercises/ExercisePreview'
import { TYPE_INFO, bodyOf } from '../exercises/model'
import type { AdminExerciseList, AdminTreeExercise, ExerciseBody, ExerciseType } from '../types'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { Modal } from '../ui/Modal'
import { routes } from './levels'
import { DragHandle, SortableItem, SortableList } from './Sortable'
import { SAVE_ORDER_FIRST, useTreeActions } from './TreeActions'

interface Props {
  courseId: string
  lessonId: string
  /** In the order to show: the saved one, or a new one not saved yet. */
  exercises: AdminTreeExercise[]
}

const typeInfo = (type: string) =>
  TYPE_INFO[type as ExerciseType] ?? { name: type, icon: 'help', description: '' }

/** A lesson's exercises, each dragged by its handle, with Edit, Preview
 * and Delete. */
export function ExerciseList({ courseId, lessonId, exercises }: Props) {
  const { api } = useSession()
  const { busy, run, reorder } = useTreeActions()
  const [previewing, setPreviewing] = useState<string | null>(null)
  const [deleting, setDeleting] = useState<{ exercise: AdminTreeExercise; number: number } | null>(null)

  if (exercises.length === 0) {
    return (
      <p className="flex items-center gap-2 rounded border border-dashed border-line-strong px-3 py-3 text-sm text-stone">
        <Icon name="inbox" className="text-lg" />
        No exercises yet.
      </p>
    )
  }

  const ids = exercises.map((e) => e.id)
  const numberOf = (id: string) => ids.indexOf(id) + 1

  return (
    <>
      <SortableList
        ids={ids}
        nameOf={(id) => `exercise ${numberOf(id)}`}
        onReorder={(next) => reorder('exercise', lessonId, next)}
        disabled={busy}
      >
        <ol className="divide-y divide-line rounded border border-line bg-surface">
          {exercises.map((ex, i) => (
            <ExerciseRow
              key={ex.id}
              exercise={ex}
              number={i + 1}
              editTo={`/courses/${courseId}/lessons/${lessonId}/exercises/${ex.id}`}
              onPreview={() => setPreviewing(ex.id)}
              onDelete={() => setDeleting({ exercise: ex, number: i + 1 })}
            />
          ))}
        </ol>
      </SortableList>

      {previewing && (
        <PreviewDialog lessonId={lessonId} exerciseId={previewing} onClose={() => setPreviewing(null)} />
      )}

      {deleting && (
        <Modal title={`Delete exercise ${deleting.number}?`} onClose={() => setDeleting(null)}>
          <p className="mt-2 text-sm leading-6 text-coffee-soft">
            <span className="font-semibold">{typeInfo(deleting.exercise.type).name}:</span> {deleting.exercise.prompt}
          </p>
          <p className="mt-1 text-sm leading-6 text-stone">
            Learners will stop seeing it straight away. This cannot be undone.
          </p>
          <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button className="justify-center" disabled={busy} onClick={() => setDeleting(null)}>
              Cancel
            </Button>
            <Button
              variant="danger"
              className="justify-center"
              disabled={busy}
              onClick={() =>
                void run(() => api.delete(routes.exercise(deleting.exercise.id))).then(() => setDeleting(null))
              }
            >
              Delete
            </Button>
          </div>
        </Modal>
      )}
    </>
  )
}

interface RowProps {
  exercise: AdminTreeExercise
  number: number
  editTo: string
  onPreview: () => void
  onDelete: () => void
}

function ExerciseRow({ exercise: ex, number, editTo, onPreview, onDelete }: RowProps) {
  const { busy, ordering } = useTreeActions()
  const info = typeInfo(ex.type)
  // Opening the editor would leave the page and lose a new order that is
  // not saved, so the links wait too.
  const prompt = 'order-last w-full pl-22 text-coffee sm:order-none sm:w-auto sm:min-w-0 sm:flex-1 sm:pl-0'

  return (
    <SortableItem
      id={ex.id}
      className="flex flex-wrap items-center gap-x-3 gap-y-1.5 bg-surface px-3 py-2 text-sm first:rounded-t last:rounded-b"
    >
      <DragHandle name={`exercise ${number}`} />
      <span className="tnum w-5 shrink-0 text-xs font-semibold text-stone">{number}</span>
      <span className="inline-flex shrink-0 items-center gap-1.5 rounded-sm bg-inset px-2 py-0.5 text-xs font-semibold text-coffee-soft">
        <Icon name={info.icon} className="text-sm" />
        <span>{info.name}</span>
      </span>
      {/* Its own line on a phone, beside the type from sm up. */}
      {ordering ? (
        <span className={prompt}>{ex.prompt}</span>
      ) : (
        <Link to={editTo} className={cx(prompt, 'hover:text-forest hover:underline')}>
          {ex.prompt}
        </Link>
      )}
      <AudioBadge audio={ex.audio} />
      <div role="group" aria-label={`Actions for exercise ${number}`} className="ml-auto flex shrink-0 items-center">
        {ordering ? (
          <Button size="icon" variant="ghost" aria-label="Edit" title={SAVE_ORDER_FIRST} disabled>
            <Icon name="edit" className="text-lg" />
          </Button>
        ) : (
          <Link
            to={editTo}
            aria-label="Edit"
            title="Edit"
            className="grid size-11 place-items-center rounded text-coffee-soft hover:bg-inset hover:text-coffee sm:size-8"
          >
            <Icon name="edit" className="text-lg" />
          </Link>
        )}
        <Button size="icon" variant="ghost" aria-label="Preview" title="Preview" onClick={onPreview}>
          <Icon name="visibility" className="text-lg" />
        </Button>
        <Button
          size="icon"
          variant="danger-ghost"
          aria-label="Delete"
          title={ordering ? SAVE_ORDER_FIRST : 'Delete'}
          disabled={busy || ordering}
          onClick={onDelete}
        >
          <Icon name="delete" className="text-lg" />
        </Button>
      </div>
    </SortableItem>
  )
}

function AudioBadge({ audio }: { audio: AdminTreeExercise['audio'] }) {
  if (audio === 'placeholder')
    return (
      <span
        title="Still plays the piano placeholder clip"
        className="inline-flex items-center gap-1 rounded-full border border-terracotta-line bg-terracotta-tint px-2 py-0.5 text-[0.6875rem] font-bold text-terracotta"
      >
        <Icon name="music_note" className="text-sm" />
        <span>placeholder audio</span>
      </span>
    )
  if (audio === 'local')
    return (
      <span
        title="Plays from the local backend only, not on a real phone"
        className="inline-flex items-center gap-1 rounded-full border border-line bg-slate-100 px-2 py-0.5 text-[0.6875rem] font-bold text-slate-500"
      >
        <Icon name="computer" className="text-sm" />
        <span>local audio</span>
      </span>
    )
  if (audio === 'hosted')
    return (
      <span
        title="Plays from the audio store"
        className="inline-flex items-center gap-1 rounded-full border border-forest-line bg-forest-tint px-2 py-0.5 text-[0.6875rem] font-bold text-forest"
      >
        <Icon name="graphic_eq" className="text-sm" />
        <span>audio ready</span>
      </span>
    )
  return null
}

/** The saved exercise as a learner sees it. The tree only carries a
 * summary, so the lesson's exercises are read in full when it opens. */
function PreviewDialog({ lessonId, exerciseId, onClose }: { lessonId: string; exerciseId: string; onClose: () => void }) {
  const { api } = useSession()
  const [body, setBody] = useState<ExerciseBody | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let live = true
    api.get<AdminExerciseList>(routes.exercises(lessonId)).then(
      (list) => {
        if (!live) return
        const found = list.exercises.find((e) => e.id === exerciseId)
        if (found) setBody(bodyOf(found))
        else setError('This exercise no longer exists.')
      },
      (e: unknown) => {
        if (live) setError(messageOf(e))
      },
    )
    return () => {
      live = false
    }
  }, [api, lessonId, exerciseId])

  return (
    <Modal title="Preview" onClose={onClose} className="sm:max-w-lg">
      <div className="mt-4">
        {error && (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        )}
        {!body && !error && <p className="text-sm text-stone">Loading…</p>}
        {body && <ExercisePreview body={body} />}
      </div>
      <div className="mt-6 flex justify-end">
        <Button variant="primary" autoFocus onClick={onClose}>
          Close
        </Button>
      </div>
    </Modal>
  )
}
