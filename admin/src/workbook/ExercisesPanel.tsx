import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import { ExerciseForm } from '../exercises/ExerciseForm'
import { TYPE_INFO } from '../exercises/model'
import { ExercisePreview } from '../exercises/ExercisePreview'
import { plural } from '../format'
import { routes } from '../tree/levels'
import type { Curriculum, CurriculumEntry, DraftExercise, DraftExerciseList, ExerciseBody, PublishLessonResult } from '../types'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { Modal } from '../ui/Modal'
import { edited, generateExercises, keyOf, regenerate, reset } from './generate'
import { isReady, NO_COUNTS } from './model'

export const STATE_LABELS = {
  not_published: 'Not published',
  published: 'Published',
  changed: 'Changed since publish',
} as const

/** What a failed save or publish says, with every exercise's problem. */
function problemOf(e: unknown): string {
  if (e instanceof ApiError && e.errorCode === 'invalid_import' && Array.isArray(e.details.rows)) {
    const rows = e.details.rows as { index: number; field: string; message: string }[]
    return `${e.message}: ${rows.map((r) => `exercise ${r.index + 1}, ${r.field}: ${r.message}`).join('; ')}`
  }
  return messageOf(e)
}

/** A lesson's exercises (intent 025, bolt 086): generated from its rows,
 * checked in the learner preview, edited, then published into the course. */
export function ExercisesPanel({
  courseId,
  curriculum,
  lesson,
  reload,
}: {
  courseId: string
  curriculum: Curriculum
  lesson: CurriculumEntry
  reload: () => Promise<Curriculum>
}) {
  const { api } = useSession()
  const [drafts, setDrafts] = useState<DraftExercise[] | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [published, setPublished] = useState<PublishLessonResult | null>(null)
  const [editing, setEditing] = useState<number | null>(null)
  const [shown, setShown] = useState<number | null>(null)
  const counts = lesson.counts ?? NO_COUNTS
  const ready = isReady(lesson.counts)
  const state = lesson.publish_state ?? 'not_published'

  useEffect(() => {
    let live = true
    api.get<DraftExerciseList>(routes.curriculumExercises(courseId, lesson.ref)).then(
      (list) => live && setDrafts(list.exercises),
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api, courseId, lesson.ref])

  async function save(next: DraftExercise[], message: string) {
    setBusy(true)
    setError(null)
    setNotice(null)
    try {
      const list = await api.put<DraftExerciseList>(routes.curriculumExercises(courseId, lesson.ref), { exercises: next })
      setDrafts(list.exercises)
      setNotice(message)
      await reload()
      return true
    } catch (e) {
      setError(problemOf(e))
      return false
    } finally {
      setBusy(false)
    }
  }

  async function generate() {
    const fresh = generateExercises(lesson.ref, curriculum.entries, curriculum.rows)
    if (fresh.length === 0) {
      setError('These rows give no exercises: a lesson needs at least two words, or a word and other words in its skill.')
      return
    }
    const { exercises, kept } = regenerate(fresh, drafts ?? [])
    const keptWords = kept.length > 0 ? ` Your ${plural(kept.length, 'edited exercise')} kept.` : ''
    await save(exercises, `Generated ${plural(exercises.length, 'exercise')}.${keptWords}`)
  }

  async function publish() {
    setBusy(true)
    setError(null)
    setNotice(null)
    try {
      setPublished(await api.post<PublishLessonResult>(routes.curriculumPublish(courseId, lesson.ref), {}))
      await reload()
    } catch (e) {
      setError(problemOf(e))
    } finally {
      setBusy(false)
    }
  }

  const list = drafts ?? []
  const why = !ready
    ? 'Review and record every row first.'
    : list.length === 0
      ? 'Generate the exercises first.'
      : state === 'published'
        ? 'Published; nothing has changed since.'
        : null

  return (
    <section aria-labelledby="exercises-heading" className="mt-8 rounded-lg border border-line bg-surface p-4 shadow-e1 sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 id="exercises-heading" className="text-base font-semibold text-coffee">
            Exercises
          </h2>
          <p className="mt-0.5 text-xs text-stone">Made from the words and sentence, with the CSV import’s rules.</p>
        </div>
        <Badge tone={state === 'published' ? 'published' : state === 'changed' ? 'draft' : 'neutral'} dot>
          {STATE_LABELS[state]}
        </Badge>
      </div>

      {!ready ? (
        <p className="mt-4 rounded bg-inset p-3 text-sm text-coffee-soft">
          Every word and sentence must be reviewed and recorded before its exercises are made:{' '}
          <span className="tnum">
            {counts.reviewed}/{counts.rows} reviewed, {counts.recorded}/{counts.rows} recorded
          </span>
          .
        </p>
      ) : (
        <div className="mt-4 flex flex-wrap gap-2">
          <Button variant={list.length ? 'outline' : 'primary'} disabled={busy || drafts === null} onClick={() => void generate()}>
            <Icon name="auto_awesome" className="text-lg" />
            {list.length ? 'Generate again' : 'Generate exercises'}
          </Button>
        </div>
      )}

      {list.length > 0 && (
        <ol className="mt-4 divide-y divide-line rounded-md border border-line">
          {list.map((d, i) => (
            <li key={keyOf(d) ?? i} className="px-3 py-2.5">
              <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                <span className="tnum w-6 text-xs text-stone">{i + 1}</span>
                <Icon name={TYPE_INFO[d.type].icon} className="text-lg text-coffee-soft" />
                <span className="min-w-0 flex-1">
                  <span className="block text-xs font-semibold text-stone">{TYPE_INFO[d.type].name}</span>
                  <span className="block truncate text-sm text-coffee">{d.prompt}</span>
                </span>
                {d.edited && <Badge tone="forest">Edited</Badge>}
                <Button size="sm" variant="ghost" aria-expanded={shown === i} onClick={() => setShown(shown === i ? null : i)}>
                  {shown === i ? 'Hide' : 'Preview'}
                </Button>
                <Button size="sm" disabled={busy} onClick={() => setEditing(i)}>
                  Edit
                </Button>
                {d.edited && d.generated && (
                  <Button
                    size="sm"
                    variant="ghost"
                    disabled={busy}
                    onClick={() => void save(list.map((x, j) => (j === i ? reset(x) : x)), `Exercise ${i + 1} reset to the generated one.`)}
                  >
                    Reset to generated
                  </Button>
                )}
              </div>
              {shown === i && (
                <div className="mt-3">
                  <ExercisePreview body={d} />
                </div>
              )}
            </li>
          ))}
        </ol>
      )}

      {error && (
        <p role="alert" className="mt-4 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger">
          {error}
        </p>
      )}
      {notice && (
        <p role="status" className="mt-4 rounded-md bg-forest-tint px-4 py-3 text-sm text-forest">
          {notice}
        </p>
      )}
      {published && (
        <p role="status" className="mt-4 rounded-md bg-forest-tint px-4 py-3 text-sm text-forest">
          Published {plural(published.exercise_ids.length, 'exercise')} to the app.{' '}
          {published.created.length > 0 && `New in the course: ${published.created.join(', ')}. `}
          <Link to={`/courses/${courseId}`} className="font-semibold underline">
            See it in the course
          </Link>
        </p>
      )}

      <div className="mt-5 flex flex-wrap items-center justify-end gap-3 border-t border-line pt-4">
        {why && <span className="text-xs text-stone">{why}</span>}
        <Button variant="coffee" disabled={busy || why !== null} onClick={() => void publish()}>
          <Icon name="publish" className="text-lg" />
          {state === 'not_published' ? 'Publish lesson' : 'Publish again'}
        </Button>
      </div>

      {editing !== null && list[editing] && (
        <EditDialog
          draft={list[editing]}
          number={editing + 1}
          lessonId={lesson.published_id ?? ''}
          onClose={() => setEditing(null)}
          onSave={async (body) => {
            const at = editing
            const ok = await save(
              list.map((x, j) => (j === at ? edited(x, body) : x)),
              `Exercise ${at + 1} saved.`,
            )
            if (ok) setEditing(null)
          }}
        />
      )}
    </section>
  )
}

function EditDialog({
  draft,
  number,
  lessonId,
  onClose,
  onSave,
}: {
  draft: DraftExercise
  number: number
  lessonId: string
  onClose: () => void
  onSave: (body: ExerciseBody) => Promise<void>
}) {
  const [body, setBody] = useState<ExerciseBody>(draft)
  const [busy, setBusy] = useState(false)
  return (
    <Modal title={`Edit exercise ${number}`} onClose={() => !busy && onClose()} className="sm:max-w-4xl">
      <div className="mt-4 grid gap-6 lg:grid-cols-[1fr_22rem]">
        <ExerciseForm body={body} saved={draft} lessonId={lessonId} onChange={setBody} onBusy={setBusy} />
        <ExercisePreview body={body} />
      </div>
      <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button className="justify-center" disabled={busy} onClick={onClose}>
          Cancel
        </Button>
        <Button
          variant="primary"
          className="justify-center"
          disabled={busy}
          onClick={() => {
            setBusy(true)
            void onSave(body).finally(() => setBusy(false))
          }}
        >
          Save exercise
        </Button>
      </div>
    </Modal>
  )
}
