import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { ApiError } from '../api'
import { messageOf, useSession } from '../auth/SessionContext'
import type { AdminCourseTree, DeleteDetails } from '../types'
import { DeleteDialog, type DeletePrompt } from './DeleteDialog'
import { ExerciseList } from './ExerciseList'
import { InlineForm } from './InlineForm'
import { routes } from './levels'
import { NodeRow } from './NodeRow'
import { TreeActionsContext, type NodeRef, type TreeActions } from './TreeActions'

const byOrder = <T extends { order_index: number }>(items: T[]): T[] =>
  [...items].sort((a, b) => a.order_index - b.order_index)

const asError = (e: unknown): Error => (e instanceof Error ? e : new Error(messageOf(e)))

function plural(n: number, word: string): string {
  return `${n} ${word}${n === 1 ? '' : 's'}`
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
        <main className="page">
          <p className="error" role="alert">
            {notFound ? 'This course does not exist.' : loadError.message}
          </p>
          {!notFound && (
            <button type="button" onClick={() => void load()}>
              Try again
            </button>
          )}
          <p>
            <Link to="/">← All courses</Link>
          </p>
        </main>
      )
    }
    return (
      <main className="page">
        <p className="muted">Loading…</p>
      </main>
    )
  }

  const sections = byOrder(tree.sections)
  const sectionIds = sections.map((s) => s.id)

  return (
    <TreeActionsContext.Provider value={actions}>
      <main className="page">
        <p>
          <Link to="/">← All courses</Link>
        </p>
        <header className="tree-header">
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
            <>
              <h1>{tree.course.title}</h1>
              <button type="button" disabled={busy} onClick={() => setEditing('course')}>
                Rename course
              </button>
            </>
          )}
          <button type="button" className="primary" disabled={busy} onClick={() => setEditing('section')}>
            Add section
          </button>
        </header>
        <p className="muted">
          {tree.course.learning_language} for {tree.course.from_language} speakers · {tree.course.status} ·{' '}
          {plural(sections.length, 'section')}
        </p>

        {writeError && (
          <div className="banner error" role="alert">
            <span>{writeError}</span>
            <button type="button" aria-label="Dismiss" onClick={() => setWriteError(null)}>
              ×
            </button>
          </div>
        )}
        {loadError && <p className="error">Could not refresh: {loadError.message}</p>}

        {editing === 'section' && (
          <InlineForm
            label="Add section"
            withSubtitle
            submitLabel="Add section"
            disabled={busy}
            onSubmit={(v) => run(() => api.post(routes.create('section', tree.course.id), v))}
            onCancel={() => setEditing(null)}
          />
        )}

        {sections.length === 0 && <p className="muted empty">No sections yet.</p>}
        <ul className="tree">
          {sections.map((section) => {
            const skills = byOrder(section.skills)
            const skillIds = skills.map((s) => s.id)
            return (
              <NodeRow
                key={section.id}
                level="section"
                id={section.id}
                title={section.title}
                subtitle={section.subtitle}
                countLabel={plural(section.skill_count, 'skill')}
                siblingIds={sectionIds}
                parentId={tree.course.id}
              >
                {skills.length === 0 && <p className="muted empty">No skills yet.</p>}
                <ul>
                  {skills.map((skill) => {
                    const lessons = byOrder(skill.lessons)
                    const lessonIds = lessons.map((l) => l.id)
                    return (
                      <NodeRow
                        key={skill.id}
                        level="skill"
                        id={skill.id}
                        title={skill.title}
                        countLabel={plural(skill.lesson_count, 'lesson')}
                        siblingIds={skillIds}
                        parentId={section.id}
                      >
                        {lessons.length === 0 && <p className="muted empty">No lessons yet.</p>}
                        <ul>
                          {lessons.map((lesson) => (
                            <NodeRow
                              key={lesson.id}
                              level="lesson"
                              id={lesson.id}
                              title={lesson.title}
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
      </main>
    </TreeActionsContext.Provider>
  )
}
