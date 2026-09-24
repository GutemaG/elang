import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router-dom'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import { courseStatus, languageName, plural } from '../format'
import { StatCard, StatRow } from '../shell/Page'
import type { AdminCourseTree, DeleteDetails } from '../types'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { Icon } from '../ui/Icon'
import { DeleteDialog, type DeletePrompt } from './DeleteDialog'
import { ExerciseList } from './ExerciseList'
import { InlineForm } from './InlineForm'
import { routes } from './levels'
import { NodeRow } from './NodeRow'
import { TreeActionsContext, type NodeRef, type TreeActions } from './TreeActions'

const byOrder = <T extends { order_index: number }>(items: T[]): T[] =>
  [...items].sort((a, b) => a.order_index - b.order_index)

const asError = (e: unknown): Error => (e instanceof Error ? e : new Error(messageOf(e)))

/** Totals across the whole course, for the stat tiles. */
function totalsOf(tree: AdminCourseTree) {
  let skills = 0
  let lessons = 0
  let exercises = 0
  let placeholders = 0
  for (const section of tree.sections) {
    skills += section.skill_count
    for (const skill of section.skills) {
      lessons += skill.lesson_count
      for (const lesson of skill.lessons) {
        exercises += lesson.exercise_count
        placeholders += lesson.exercises.filter((ex) => ex.audio === 'placeholder').length
      }
    }
  }
  return { sections: tree.sections.length, skills, lessons, exercises, placeholders }
}

/** One course: sections → skills → lessons → exercises. Nothing is kept
 * locally; every write is followed by a fresh load from the server. */
export function CourseTree() {
  const { courseId = '' } = useParams()
  const { api } = useSession()
  const [tree, setTree] = useState<AdminCourseTree | null>(null)
  const [loadError, setLoadError] = useState<ApiError | Error | null>(null)
  const [writeError, setWriteError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [deletePrompt, setDeletePrompt] = useState<DeletePrompt | null>(null)
  const [editing, setEditing] = useState<'course' | 'section' | null>(null)

  const fetchTree = useCallback(() => api.get<AdminCourseTree>(routes.tree(courseId)), [api, courseId])

  const load = useCallback(async () => {
    try {
      setTree(await fetchTree())
      setLoadError(null)
    } catch (e) {
      setLoadError(asError(e))
    }
  }, [fetchTree])

  useEffect(() => {
    let live = true
    fetchTree().then(
      (t) => {
        if (!live) return
        setTree(t)
        setLoadError(null)
      },
      (e: unknown) => {
        if (live) setLoadError(asError(e))
      },
    )
    return () => {
      live = false
    }
  }, [fetchTree])

  const run = useCallback(
    async (write: () => Promise<unknown>) => {
      setBusy(true)
      setWriteError(null)
      try {
        await write()
        await load()
        return true
      } catch (e) {
        setWriteError(messageOf(e))
        // Reload anyway (unless signed out): the write may have failed
        // because the server's state moved on, and that is what to show.
        if (!(e instanceof ApiError && e.status === 401)) await load()
        return false
      } finally {
        setBusy(false)
      }
    },
    [load],
  )

  const requestDelete = useCallback(
    async (node: NodeRef) => {
      setBusy(true)
      setWriteError(null)
      try {
        // Asked first without confirm: the server says what would go.
        await api.delete(routes.node(node.level, node.id))
        await load()
      } catch (e) {
        if (e instanceof ApiError && e.status === 409) {
          const details = e.details as unknown as DeleteDetails
          setDeletePrompt({ kind: e.errorCode === 'content_in_use' ? 'in_use' : 'confirm', node, details })
        } else {
          setWriteError(messageOf(e))
        }
      } finally {
        setBusy(false)
      }
    },
    [api, load],
  )

  const confirmDelete = async () => {
    if (deletePrompt?.kind !== 'confirm') return
    const { node } = deletePrompt
    // Closed either way: a failure (say, a learner started it meanwhile)
    // shows in the banner, over the reloaded tree.
    await run(() => api.delete(`${routes.node(node.level, node.id)}?confirm=true`))
    setDeletePrompt(null)
  }

  const actions = useMemo<TreeActions>(
    () => ({ busy, run, requestDelete: (node) => void requestDelete(node) }),
    [busy, run, requestDelete],
  )

  if (!tree) {
    if (loadError) {
      const notFound = loadError instanceof ApiError && loadError.status === 404
      return (
        <Page>
          <div className="rounded-lg border border-line bg-surface p-8 text-center shadow-e1">
            <span className="mx-auto grid size-12 place-items-center rounded-full bg-terracotta-tint text-terracotta">
              <Icon name={notFound ? 'search_off' : 'cloud_off'} className="text-2xl" />
            </span>
            <p role="alert" className="mt-4 text-base font-semibold text-coffee">
              {notFound ? 'This course does not exist.' : loadError.message}
            </p>
            <div className="mt-5 flex justify-center gap-2">
              {!notFound && (
                <Button variant="primary" onClick={() => void load()}>
                  Try again
                </Button>
              )}
              <Link
                to="/"
                className="inline-flex h-11 items-center gap-2 rounded border border-line bg-surface px-4 text-sm font-semibold text-coffee hover:bg-inset sm:h-10"
              >
                All courses
              </Link>
            </div>
          </div>
        </Page>
      )
    }
    return (
      <Page>
        <div className="animate-pulse space-y-4" aria-busy="true">
          <p className="sr-only">Loading…</p>
          <div className="h-44 rounded-lg bg-inset" />
          <div className="h-20 rounded-lg bg-inset" />
          <div className="h-20 rounded-lg bg-inset" />
        </div>
      </Page>
    )
  }

  const sections = byOrder(tree.sections)
  const sectionIds = sections.map((s) => s.id)
  const totals = totalsOf(tree)
  const status = courseStatus(tree.course.status)

  return (
    <TreeActionsContext.Provider value={actions}>
      <Page>
        <nav aria-label="Breadcrumb" className="flex items-center gap-1.5 text-sm text-stone">
          <Link to="/" className="font-medium hover:text-forest">
            Courses
          </Link>
          <Icon name="chevron_right" className="text-base" />
          <span className="min-w-0 truncate font-medium text-coffee">{tree.course.title}</span>
        </nav>

        <section className="mt-4 rounded-lg border border-line bg-surface p-5 shadow-e1 sm:p-7">
          <div className="flex flex-wrap items-start justify-between gap-4">
            {/* A 20rem basis sends the buttons to their own line on a phone
                rather than squeezing the title to a word per line. */}
            <div className="min-w-0 flex-[1_1_20rem]">
              {editing === 'course' ? (
                <InlineForm
                  label="Rename course"
                  initial={{ title: tree.course.title }}
                  submitLabel="Save"
                  disabled={busy}
                  onSubmit={(v) => run(() => api.patch(routes.course(tree.course.id), { title: v.title }))}
                  onCancel={() => setEditing(null)}
                />
              ) : (
                <h1 className="text-[1.75rem] leading-9 font-bold tracking-[-0.02em] break-words text-coffee lg:text-4xl lg:leading-11">
                  {tree.course.title}
                </h1>
              )}
              <p className="mt-3 flex flex-wrap items-center gap-x-2.5 gap-y-1 text-sm text-stone">
                <Badge tone={status.tone} dot>
                  {status.label}
                </Badge>
                {languageName(tree.course.learning_language)} for {languageName(tree.course.from_language)} speakers
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              {editing !== 'course' && (
                <Button disabled={busy} onClick={() => setEditing('course')}>
                  <Icon name="edit" className="text-lg" />
                  Rename course
                </Button>
              )}
              <Button variant="primary" disabled={busy} onClick={() => setEditing('section')}>
                <Icon name="add" className="text-lg" />
                Add section
              </Button>
            </div>
          </div>

          <StatRow className="border-t border-line pt-5 lg:grid-cols-5">
            <StatCard icon="view_agenda" label="Sections" value={totals.sections} />
            <StatCard icon="account_tree" label="Skills" value={totals.skills} />
            <StatCard icon="menu_book" label="Lessons" value={totals.lessons} />
            <StatCard icon="quiz" label="Exercises" value={totals.exercises} tone="forest" />
            <StatCard
              icon="music_off"
              label="Placeholder audio"
              value={totals.placeholders}
              tone={totals.placeholders > 0 ? 'terracotta' : 'coffee'}
            />
          </StatRow>
        </section>

        {writeError && (
          <div
            role="alert"
            className="mt-5 flex items-start gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
          >
            <Icon name="error" className="mt-px text-lg" />
            <span className="flex-1">{writeError}</span>
            <Button size="icon" variant="danger-ghost" aria-label="Dismiss" onClick={() => setWriteError(null)}>
              <Icon name="close" className="text-lg" />
            </Button>
          </div>
        )}
        {loadError && (
          <p className="mt-5 flex items-center gap-2 text-sm text-danger">
            <Icon name="sync_problem" className="text-lg" />
            Could not refresh: {loadError.message}
          </p>
        )}

        <div className="mt-8 flex flex-wrap items-end justify-between gap-2">
          <div>
            <h2 className="text-xl leading-7 font-semibold tracking-[-0.015em] text-coffee">Curriculum</h2>
            <p className="text-xs text-stone">
              {plural(totals.sections, 'section')} in learning order. Open one to reach its skills, lessons and
              exercises.
            </p>
          </div>
        </div>

        {editing === 'section' && (
          <div className="mt-4 rounded-lg border border-dashed border-forest/40 bg-forest-tint/40 p-4">
            <p className="mb-3 text-xs font-bold tracking-[0.06em] text-forest uppercase">New section</p>
            <InlineForm
              label="Add section"
              withSubtitle
              submitLabel="Add section"
              disabled={busy}
              onSubmit={(v) => run(() => api.post(routes.create('section', tree.course.id), v))}
              onCancel={() => setEditing(null)}
            />
          </div>
        )}

        {sections.length === 0 && (
          <p className="mt-4 rounded-lg border border-dashed border-line-strong px-6 py-10 text-center text-sm text-stone">
            No sections yet.
          </p>
        )}
        <ul className="mt-4 space-y-4">
          {sections.map((section, s) => {
            const skills = byOrder(section.skills)
            const skillIds = skills.map((sk) => sk.id)
            return (
              <NodeRow
                key={section.id}
                level="section"
                id={section.id}
                title={section.title}
                subtitle={section.subtitle}
                number={String(s + 1).padStart(2, '0')}
                countLabel={plural(section.skill_count, 'skill')}
                siblingIds={sectionIds}
                parentId={tree.course.id}
              >
                {skills.length === 0 && <Empty>No skills yet.</Empty>}
                <ul className="space-y-3">
                  {skills.map((skill, k) => {
                    const lessons = byOrder(skill.lessons)
                    const lessonIds = lessons.map((l) => l.id)
                    return (
                      <NodeRow
                        key={skill.id}
                        level="skill"
                        id={skill.id}
                        title={skill.title}
                        number={`${s + 1}.${k + 1}`}
                        countLabel={plural(skill.lesson_count, 'lesson')}
                        siblingIds={skillIds}
                        parentId={section.id}
                      >
                        {lessons.length === 0 && <Empty>No lessons yet.</Empty>}
                        <ul className="space-y-2">
                          {lessons.map((lesson, l) => (
                            <NodeRow
                              key={lesson.id}
                              level="lesson"
                              id={lesson.id}
                              title={lesson.title}
                              number={`${s + 1}.${k + 1}.${l + 1}`}
                              countLabel={plural(lesson.exercise_count, 'exercise')}
                              siblingIds={lessonIds}
                              parentId={skill.id}
                            >
                              <ExerciseList exercises={lesson.exercises} />
                            </NodeRow>
                          ))}
                        </ul>
                      </NodeRow>
                    )
                  })}
                </ul>
              </NodeRow>
            )
          })}
        </ul>

        {deletePrompt && (
          <DeleteDialog
            prompt={deletePrompt}
            busy={busy}
            onConfirm={() => void confirmDelete()}
            onClose={() => setDeletePrompt(null)}
          />
        )}
      </Page>
    </TreeActionsContext.Provider>
  )
}

function Page({ children }: { children: ReactNode }) {
  return <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</main>
}

function Empty({ children }: { children: ReactNode }) {
  return (
    <p className="rounded border border-dashed border-line-strong px-3 py-3 text-sm text-stone">{children}</p>
  )
}
