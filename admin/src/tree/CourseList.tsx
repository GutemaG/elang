import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import type { AdminCourse, AdminCourseList } from '../types'
import { routes } from './levels'

export function CourseList() {
  const { api } = useSession()
  const [courses, setCourses] = useState<AdminCourse[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(() => {
    let live = true
    api.get<AdminCourseList>(routes.courses).then(
      (list) => {
        if (!live) return
        setCourses(list.courses)
        setError(null)
      },
      (e: unknown) => {
        if (live) setError(messageOf(e))
      },
    )
    return () => {
      live = false
    }
  }, [api])

  useEffect(() => load(), [load])

  return (
    <main className="page">
      <h1>Courses</h1>
      {error && (
        <p className="error" role="alert">
          {error}{' '}
          <button type="button" onClick={() => void load()}>
            Try again
          </button>
        </p>
      )}
      {!courses && !error && <p className="muted">Loading…</p>}
      {courses?.length === 0 && <p className="muted empty">There are no courses.</p>}
      <ul className="course-list">
        {courses?.map((c) => (
          <li key={c.id}>
            <Link to={`/courses/${c.id}`} className="card course-card">
              <strong>{c.title}</strong>
              <span className="muted">
                {c.learning_language} for {c.from_language} speakers · {c.status} · {c.section_count}{' '}
                {c.section_count === 1 ? 'section' : 'sections'}
              </span>
            </Link>
          </li>
        ))}
      </ul>
    </main>
  )
}
