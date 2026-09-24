import { useEffect, useState, type ReactNode } from 'react'
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import { routes } from '../tree/levels'
import {
  EXERCISE_TYPES,
  type AdminCourseTree,
  type AdminExercise,
  type AdminExerciseList,
  type ExerciseBody,
  type ExerciseType,
} from '../types'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { ExerciseForm } from './ExerciseForm'
import { ExercisePreview } from './ExercisePreview'
import { SlotErrors } from './fields'
import { TYPE_INFO, blank, bodyOf, missingAnswer, placeError, plainMessage, sameBody, type Slot } from './model'

interface Where {
  courseTitle: string
  lessonTitle: string
}

/** Where a lesson sits in its course, for the breadcrumb. */
function whereIs(tree: AdminCourseTree, lessonId: string): Where | null {
  for (const section of tree.sections)
    for (const skill of section.skills)
      for (const lesson of skill.lessons)
        if (lesson.id === lessonId) return { courseTitle: tree.course.title, lessonTitle: lesson.title }
  return null
}

const isType = (value: string | undefined): value is ExerciseType =>
  EXERCISE_TYPES.includes(value as ExerciseType)

/** The route's element. Keyed by what is being edited, so moving from
 * "new" to the exercise just created (or to another exercise) starts the
 * page afresh instead of carrying the old draft over. */
export function ExerciseEditorRoute() {
  const { exerciseId, type } = useParams()
  return <ExerciseEditorPage key={exerciseId ?? `new:${type}`} />
}

/** Adding or editing one exercise: the form, a live learner preview, and
 * Save. `…/exercises/new/:type` creates; `…/exercises/:exerciseId` edits.
 * Every save is followed by the server's own copy, never the local one. */
function ExerciseEditorPage() {
  const { courseId = '', lessonId = '', exerciseId, type } = useParams()
  const isNew = exerciseId === undefined
  const { api } = useSession()
  const navigate = useNavigate()
  const location = useLocation()

  const [where, setWhere] = useState<Where | null>(null)
  const [saved, setSaved] = useState<ExerciseBody | null>(null)
  const [draft, setDraft] = useState<ExerciseBody | null>(isNew && isType(type) ? blank(type) : null)
  const [loadError, setLoadError] = useState<string | null>(
    isNew && !isType(type) ? 'There is no such exercise type.' : null,
  )
  const [errors, setErrors] = useState<Partial<Record<Slot, string>>>({})
  const [saving, setSaving] = useState(false)
  // Arriving from a create, the exercise was saved one page ago.
  const [justSaved, setJustSaved] = useState(Boolean((location.state as { saved?: boolean } | null)?.saved))

  useEffect(() => {
    let live = true
    const tree = api.get<AdminCourseTree>(routes.tree(courseId))
    const exercises = isNew ? Promise.resolve(null) : api.get<AdminExerciseList>(routes.exercises(lessonId))
    Promise.all([tree, exercises]).then(
      ([t, list]) => {
        if (!live) return
        setWhere(whereIs(t, lessonId))
        if (!list) return
        const found = list.exercises.find((e) => e.id === exerciseId)
        if (!found) {
          setLoadError('This exercise does not exist, or belongs to another lesson.')
          return
        }
        const body = bodyOf(found)
        setSaved(body)
        setDraft(bodyOf(found))
      },
      (e: unknown) => {
        if (live) setLoadError(messageOf(e))
      },
    )
    return () => {
      live = false
    }
  }, [api, courseId, lessonId, exerciseId, isNew])

  const dirty = draft !== null && !sameBody(draft, saved)

  // Closing the tab or reloading with unsaved changes asks first. (Links
  // inside the site cannot be held back by this router; the page says
  // "Unsaved changes" instead.)
  useEffect(() => {
    if (!dirty) return
    const warn = (e: BeforeUnloadEvent) => e.preventDefault()
    window.addEventListener('beforeunload', warn)
    return () => window.removeEventListener('beforeunload', warn)
  }, [dirty])

  const backTo = `/courses/${courseId}?open=${encodeURIComponent(lessonId)}`

  const change = (next: ExerciseBody) => {
    setDraft(next)
    setErrors({})
    setJustSaved(false)
  }

  async function save() {
    if (!draft) return
    setSaving(true)
    setErrors({})
    try {
      if (isNew) {
        const created = await api.post<AdminExercise>(routes.exercises(lessonId), draft)
        navigate(`/courses/${courseId}/lessons/${lessonId}/exercises/${created.id}`, {
          replace: true,
          state: { saved: true },
        })
        return
      }
      const updated = await api.put<AdminExercise>(routes.exercise(exerciseId ?? ''), draft)
      setSaved(bodyOf(updated))
      setDraft(bodyOf(updated))
      setJustSaved(true)
    } catch (e) {
      const field = e instanceof ApiError ? e.details.field : undefined
      setErrors(
        typeof field === 'string'
          ? { [placeError(field, messageOf(e), draft)]: plainMessage(messageOf(e)) }
          : { top: messageOf(e) },
      )
    } finally {
      setSaving(false)
    }
  }

  if (loadError) {
    return (
      <Page>
        <div className="rounded-lg border border-line bg-surface p-8 text-center shadow-e1">
          <p role="alert" className="text-base font-semibold text-coffee">
            {loadError}
          </p>
          <Link to={backTo} className="mt-4 inline-flex items-center gap-1 text-sm font-semibold text-forest">
            <Icon name="arrow_back" className="text-base" />
            Back to the lesson
          </Link>
        </div>
      </Page>
    )
  }
  if (!draft) {
    return (
      <Page>
        <div className="animate-pulse space-y-4" aria-busy="true">
          <p className="sr-only">Loading…</p>
          <div className="h-24 rounded-lg bg-inset" />
          <div className="h-64 rounded-lg bg-inset" />
        </div>
      </Page>
    )
  }

  const info = TYPE_INFO[draft.type]
  const missing = missingAnswer(draft)

  return (
    <Page>
      <nav aria-label="Breadcrumb" className="flex flex-wrap items-center gap-1.5 text-sm text-stone">
        <Link to="/" className="font-medium hover:text-forest">
          Courses
        </Link>
        <Icon name="chevron_right" className="text-base" />
        <Link to={`/courses/${courseId}`} className="font-medium hover:text-forest">
          {where?.courseTitle ?? 'Course'}
        </Link>
        <Icon name="chevron_right" className="text-base" />
        <Link to={backTo} className="font-medium text-coffee hover:text-forest">
          {where?.lessonTitle ?? 'Lesson'}
        </Link>
      </nav>

      <header className="mt-4 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p
            className="inline-flex items-center gap-1.5 rounded-full bg-forest-tint px-2.5 py-1 text-xs font-bold text-forest"
            title="An exercise's type is chosen once, when it is created."
          >
            <Icon name={info.icon} className="text-sm" />
            {info.name}
          </p>
          <h1 className="mt-2 text-[1.75rem] leading-9 font-bold tracking-[-0.02em] text-coffee">
            {isNew ? 'New exercise' : 'Edit exercise'}
          </h1>
          <p className="mt-1 text-sm text-stone">{info.description}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Status dirty={dirty} isNew={isNew} justSaved={justSaved} />
          <Link
            to={backTo}
            className="inline-flex h-11 items-center gap-2 rounded border border-line bg-surface px-4 text-sm font-semibold text-coffee hover:bg-inset sm:h-10"
          >
            <Icon name="arrow_back" className="text-lg" />
            Back to lesson
          </Link>
          <Button
            variant="primary"
            disabled={saving || missing !== null}
            title={missing ?? undefined}
            onClick={() => void save()}
          >
            <Icon name={saving ? 'progress_activity' : 'check'} className={saving ? 'animate-spin text-lg' : 'text-lg'} />
            {isNew ? 'Create exercise' : 'Save'}
          </Button>
        </div>
      </header>

      {errors.top && (
        <p
          role="alert"
          className="mt-5 flex items-start gap-2 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
        >
          <Icon name="error" className="mt-px text-lg" />
          {errors.top}
        </p>
      )}

      <div className="mt-6 grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <SlotErrors.Provider value={errors}>
          <ExerciseForm body={draft} saved={saved} lessonId={lessonId} onChange={change} />
        </SlotErrors.Provider>
        <div className="lg:sticky lg:top-6">
          <ExercisePreview body={draft} />
        </div>
      </div>
    </Page>
  )
}

function Status({ dirty, isNew, justSaved }: { dirty: boolean; isNew: boolean; justSaved: boolean }) {
  if (isNew)
    return <span className="text-sm font-semibold text-terracotta">Not created yet</span>
  if (dirty)
    return (
      <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-terracotta">
        <span className="size-2 rounded-full bg-terracotta" aria-hidden="true" />
        Unsaved changes
      </span>
    )
  return (
    <span role="status" className="inline-flex items-center gap-1.5 text-sm font-semibold text-forest">
      <Icon name="cloud_done" className="text-lg" />
      {justSaved ? 'Saved' : 'All changes saved'}
    </span>
  )
}

function Page({ children }: { children: ReactNode }) {
  return <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</main>
}
