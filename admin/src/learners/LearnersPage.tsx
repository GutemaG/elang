import { useCallback, useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { plural } from '../format'
import { PageHeader, StatCard, StatRow } from '../shell/Page'
import { routes } from '../tree/levels'
import type { AdminCourse, AdminCourseList, AdminLearnerPage } from '../types'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS, Input } from '../ui/Input'
import { Avatar, ErrorBanner, Panel } from './charts'
import { activity, count, lastSeen, percent } from './report'

const PAGE = 25

const SORTS = [
  { key: 'last_active', label: 'Last active' },
  { key: 'xp', label: 'XP' },
  { key: 'lessons', label: 'Lessons' },
  { key: 'streak', label: 'Streak' },
  { key: 'joined', label: 'Joined' },
  { key: 'name', label: 'Name' },
] as const

/** Everyone who has signed in to the app, with how far each has got. The
 * search, course, sort and page live in the address, so coming back from a
 * learner returns to the same list. */
export function LearnersPage() {
  const { api } = useSession()
  const [params, setParams] = useSearchParams()
  const search = params.get('q') ?? ''
  const courseId = params.get('course') ?? ''
  const sort = SORTS.some((s) => s.key === params.get('sort')) ? params.get('sort')! : 'last_active'
  const order = params.get('order') === 'asc' ? 'asc' : 'desc'
  const offset = Math.max(0, Number(params.get('from')) || 0)

  const [typed, setTyped] = useState(search)
  const [page, setPage] = useState<AdminLearnerPage | null>(null)
  const [courses, setCourses] = useState<AdminCourse[]>([])
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)

  const update = useCallback(
    (changes: Record<string, string>) =>
      setParams(
        (current) => {
          const next = new URLSearchParams(current)
          for (const [key, value] of Object.entries(changes)) {
            if (value) next.set(key, value)
            else next.delete(key)
          }
          // Any change but turning the page starts again from the top.
          if (!('from' in changes)) next.delete('from')
          return next
        },
        { replace: true },
      ),
    [setParams],
  )

  // Searches once typing pauses, not on every key.
  useEffect(() => {
    if (typed.trim() === search) return
    const timer = setTimeout(() => update({ q: typed.trim() }), 300)
    return () => clearTimeout(timer)
  }, [typed, search, update])

  useEffect(() => {
    let live = true
    api.get<AdminCourseList>(routes.courses).then(
      (list) => live && setCourses(list.courses),
      () => undefined,
    )
    return () => {
      live = false
    }
  }, [api])

  useEffect(() => {
    let live = true
    const query = new URLSearchParams({ sort, order, offset: String(offset), limit: String(PAGE) })
    if (search) query.set('search', search)
    if (courseId) query.set('course_id', courseId)
    api.get<AdminLearnerPage>(`${routes.learners}?${query}`).then(
      (p) => {
        if (!live) return
        setPage(p)
        setError(null)
      },
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api, search, courseId, sort, order, offset, attempt])

  const filtered = Boolean(search || courseId)
  const now = new Date()

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Learners"
        title="Learners"
        description="Everyone who has signed in to the app, with their progress. Open a learner to see each skill they have finished and their recent lessons."
        actions={
          <Link
            to="/dashboard"
            className="inline-flex h-11 items-center gap-2 rounded border border-line bg-surface px-4 text-sm font-semibold text-coffee hover:bg-inset sm:h-10"
          >
            <Icon name="monitoring" className="text-lg" />
            Dashboard
          </Link>
        }
      />

      {error && <ErrorBanner message={error} onRetry={() => setAttempt((n) => n + 1)} />}

      {page && (
        <StatRow>
          <StatCard icon="group" label={filtered ? 'Matching learners' : 'Learners'} value={page.total} />
          <StatCard icon="today" label="Active today" value={page.active_today} tone="forest" />
          <StatCard icon="date_range" label="Active in the last 7 days" value={page.active_7_days} tone="forest" />
          <StatCard icon="hourglass_empty" label="Not started yet" value={page.not_started} tone="terracotta" />
        </StatRow>
      )}

      <Panel
        className="mt-6"
        flush
        title="All learners"
        description={page ? `${plural(page.total, 'learner')}${filtered ? ' match' : ''}.` : 'Loading…'}
        actions={
          <div className="flex w-full flex-wrap items-center gap-2 sm:w-auto">
            <label className="relative min-w-0 flex-1 sm:w-56 sm:flex-none">
              <span className="sr-only">Search by name or email</span>
              <Icon name="search" className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-lg text-stone" />
              <Input
                type="search"
                value={typed}
                onChange={(e) => setTyped(e.target.value)}
                placeholder="Name or email"
                className="pl-9"
              />
            </label>
            <label className="min-w-0">
              <span className="sr-only">Course</span>
              <select
                className={cx(FIELD_CLASS, 'w-auto max-w-[12rem]')}
                value={courseId}
                onChange={(e) => update({ course: e.target.value })}
              >
                <option value="">All courses</option>
                {courses.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.title}
                  </option>
                ))}
              </select>
            </label>
            <label className="min-w-0">
              <span className="sr-only">Sort by</span>
              <select
                className={cx(FIELD_CLASS, 'w-auto')}
                value={sort}
                onChange={(e) => update({ sort: e.target.value === 'last_active' ? '' : e.target.value })}
              >
                {SORTS.map((s) => (
                  <option key={s.key} value={s.key}>
                    Sort: {s.label}
                  </option>
                ))}
              </select>
            </label>
            <Button
              size="icon"
              aria-label={order === 'desc' ? 'Highest first; show lowest first' : 'Lowest first; show highest first'}
              title={order === 'desc' ? 'Highest first' : 'Lowest first'}
              onClick={() => update({ order: order === 'desc' ? 'asc' : '' })}
            >
              <Icon name={order === 'desc' ? 'arrow_downward' : 'arrow_upward'} className="text-lg" />
            </Button>
          </div>
        }
      >
        {page?.learners.length === 0 && (
          <p className="px-6 py-12 text-center text-sm text-stone">
            {filtered ? 'No learner matches.' : 'No one has signed in to the app yet.'}
          </p>
        )}
        {page && page.learners.length > 0 && (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[52rem] text-sm">
              <thead className="bg-canvas text-left text-xs text-stone">
                <tr>
                  <th scope="col" className="px-4 py-2.5 font-semibold sm:px-6">Learner</th>
                  <th scope="col" className="px-3 py-2.5 font-semibold">Course</th>
                  <th scope="col" className="px-3 py-2.5 font-semibold">Last active</th>
                  <th scope="col" className="px-3 py-2.5 text-right font-semibold">Streak</th>
                  <th scope="col" className="px-3 py-2.5 text-right font-semibold">Lessons</th>
                  <th scope="col" className="px-3 py-2.5 text-right font-semibold">Skills</th>
                  <th scope="col" className="px-3 py-2.5 text-right font-semibold">XP</th>
                  <th scope="col" className="px-3 py-2.5 pr-4 text-right font-semibold sm:pr-6">Accuracy</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {page.learners.map((l) => {
                  const status = activity(l.last_active_at, now)
                  return (
                    <tr key={l.id} className="group hover:bg-canvas">
                      <th scope="row" className="px-4 py-2.5 text-left font-normal sm:px-6">
                        <Link to={`/learners/${l.id}`} className="flex items-center gap-3">
                          <Avatar name={l.name} />
                          <span className="min-w-0">
                            <span className="block truncate font-semibold text-coffee group-hover:text-forest">{l.name}</span>
                            <span className="block truncate text-xs text-stone">{l.email ?? 'No email'}</span>
                          </span>
                        </Link>
                      </th>
                      <td className="max-w-[12rem] truncate px-3 py-2.5 text-coffee-soft">{l.course_title}</td>
                      <td className="px-3 py-2.5 whitespace-nowrap">
                        <span className="block text-coffee-soft">{lastSeen(l.last_active_at, now)}</span>
                        <Badge tone={status.tone} className="mt-0.5">
                          {status.label}
                        </Badge>
                      </td>
                      <td className="tnum px-3 py-2.5 text-right">
                        {l.current_streak > 0 ? (
                          <span className="inline-flex items-center gap-0.5 font-semibold text-terracotta">
                            <Icon name="local_fire_department" className="text-base" filled />
                            {l.current_streak}
                          </span>
                        ) : (
                          <span className="text-stone">0</span>
                        )}
                      </td>
                      <td className="tnum px-3 py-2.5 text-right">{count(l.lessons)}</td>
                      <td className="tnum px-3 py-2.5 text-right">{count(l.skills_completed)}</td>
                      <td className="tnum px-3 py-2.5 text-right font-semibold text-coffee">{count(l.xp)}</td>
                      <td className="tnum px-3 py-2.5 pr-4 text-right sm:pr-6">{percent(l.accuracy)}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
        {page && page.total > PAGE && (
          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-line px-4 py-3 text-sm text-stone sm:px-6">
            <span className="tnum">
              {offset + 1}–{Math.min(offset + PAGE, page.total)} of {page.total}
            </span>
            <span className="flex gap-2">
              <Button size="sm" disabled={offset === 0} onClick={() => update({ from: String(Math.max(0, offset - PAGE)) })}>
                Previous
              </Button>
              <Button size="sm" disabled={offset + PAGE >= page.total} onClick={() => update({ from: String(offset + PAGE) })}>
                Next
              </Button>
            </span>
          </div>
        )}
        {!page && !error && <p className="px-6 py-12 text-center text-sm text-stone">Loading learners…</p>}
      </Panel>
    </main>
  )
}
