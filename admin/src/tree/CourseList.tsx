import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { courseStatus, languageGlyph, languageName, plural } from '../format'
import { PageHeader, StatCard, StatRow } from '../shell/Page'
import type { AdminCourse, AdminCourseList } from '../types'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { routes } from './levels'

type Filter = 'all' | 'available' | 'coming_soon'

const FILTERS: { key: Filter; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'available', label: 'Available' },
  { key: 'coming_soon', label: 'Coming soon' },
]

export function CourseList() {
  const { api } = useSession()
  const [courses, setCourses] = useState<AdminCourse[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [filter, setFilter] = useState<Filter>('all')

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

  const all = courses ?? []
  const count = (key: Filter) => (key === 'all' ? all.length : all.filter((c) => c.status === key).length)
  const shown = filter === 'all' ? all : all.filter((c) => c.status === filter)

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Curriculum"
        title="Courses"
        description="Every course learners can pick. Open one to shape its sections, skills and lessons — changes reach the app straight away."
      />

      {error && (
        <div
          role="alert"
          className="mt-6 flex flex-wrap items-center gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
        >
          <Icon name="error" className="text-lg" />
          <span className="flex-1">{error}</span>
          <Button size="sm" onClick={() => void load()}>
            Try again
          </Button>
        </div>
      )}

      {courses && (
        <StatRow>
          <StatCard icon="school" label="Courses" value={all.length} />
          <StatCard icon="check_circle" label="Available" value={count('available')} tone="forest" />
          <StatCard icon="schedule" label="Coming soon" value={count('coming_soon')} tone="terracotta" />
          <StatCard icon="view_agenda" label="Sections" value={all.reduce((n, c) => n + c.section_count, 0)} />
        </StatRow>
      )}

      <section className="mt-6 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-4 py-4 sm:px-6">
          <div>
            <h2 className="text-lg leading-6 font-semibold text-coffee">All courses</h2>
            <p className="text-xs text-stone">Language pairs, their status and how much is in them.</p>
          </div>
          {courses && courses.length > 0 && (
            <div className="flex rounded bg-inset p-1" role="group" aria-label="Filter by status">
              {FILTERS.map((f) => (
                <button
                  key={f.key}
                  type="button"
                  aria-pressed={filter === f.key}
                  onClick={() => setFilter(f.key)}
                  className={cx(
                    'rounded-sm px-3 py-1.5 text-xs font-semibold transition-colors',
                    filter === f.key ? 'bg-surface text-forest shadow-e1' : 'text-stone hover:text-coffee',
                  )}
                >
                  {f.label} <span className="tnum opacity-70">({count(f.key)})</span>
                </button>
              ))}
            </div>
          )}
        </div>

        {!courses && !error && <ListSkeleton />}
        {courses?.length === 0 && (
          <p className="px-6 py-12 text-center text-sm text-stone">There are no courses.</p>
        )}
        {courses && courses.length > 0 && shown.length === 0 && (
          <p className="px-6 py-12 text-center text-sm text-stone">No course has this status.</p>
        )}

        <ul className="divide-y divide-line">
          {shown.map((c) => {
            const status = courseStatus(c.status)
            return (
              <li key={c.id}>
                <Link
                  to={`/courses/${c.id}`}
                  className="group flex items-center gap-4 px-4 py-4 transition-colors hover:bg-canvas sm:px-6"
                >
                  <span className="grid size-12 shrink-0 place-items-center rounded-md border border-line bg-inset text-center">
                    <span>
                      <span className="block text-lg leading-5 font-bold text-coffee">
                        {languageGlyph(c.learning_language)}
                      </span>
                      <span className="block text-[0.625rem] font-semibold tracking-wider text-stone uppercase">
                        {c.learning_language}
                      </span>
                    </span>
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex flex-wrap items-center gap-2">
                      <span className="text-base font-semibold text-coffee group-hover:text-forest">{c.title}</span>
                      <Badge tone={status.tone} dot>
                        {status.label}
                      </Badge>
                    </span>
                    <span className="mt-1 flex flex-wrap items-center gap-x-2 text-sm text-stone">
                      <span>
                        {languageName(c.learning_language)} for {languageName(c.from_language)} speakers
                      </span>
                      <span aria-hidden="true">•</span>
                      <span className="tnum">{plural(c.section_count, 'section')}</span>
                    </span>
                  </span>
                  <span className="hidden items-center gap-1 text-sm font-semibold text-forest sm:flex">
                    Open curriculum
                  </span>
                  <Icon
                    name="chevron_right"
                    className="text-2xl text-stone transition-transform group-hover:translate-x-0.5 group-hover:text-forest"
                  />
                </Link>
              </li>
            )
          })}
        </ul>
      </section>
    </main>
  )
}

function ListSkeleton() {
  return (
    <div className="divide-y divide-line" aria-busy="true">
      <p className="sr-only">Loading…</p>
      {[0, 1, 2].map((i) => (
        <div key={i} className="flex animate-pulse items-center gap-4 px-6 py-4">
          <span className="size-12 rounded-md bg-inset" />
          <span className="flex-1 space-y-2">
            <span className="block h-4 w-1/3 rounded bg-inset" />
            <span className="block h-3 w-1/2 rounded bg-inset" />
          </span>
        </div>
      ))}
    </div>
  )
}
