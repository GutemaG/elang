import { useCallback, useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { CSV_TYPE, saveFile } from '../import/download'
import { PageHeader, StatCard, StatRow } from '../shell/Page'
import { routes } from '../tree/levels'
import type { AdminCourse, AdminCourseList, AdminReport, AdminTotals, ReportPeriod } from '../types'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS } from '../ui/Input'
import { Avatar, BarChart, ErrorBanner, Panel, TrendCard } from './charts'
import {
  bucketLabel,
  bucketName,
  count,
  METRICS,
  metricValue,
  percent,
  PERIOD_COUNT,
  PERIODS,
  rangeLabel,
  reportCsv,
  shiftedEnd,
  trend,
} from './report'

const CHARTS: { key: keyof AdminTotals; title: string; tone: 'forest' | 'coffee' | 'terracotta' }[] = [
  { key: 'active_learners', title: 'Active learners', tone: 'forest' },
  { key: 'lessons', title: 'Lessons completed', tone: 'coffee' },
  { key: 'new_learners', title: 'New learners', tone: 'terracotta' },
  { key: 'xp', title: 'XP earned', tone: 'forest' },
]

const isPeriod = (value: string | null): value is ReportPeriod => value === 'day' || value === 'week' || value === 'month'

/** How learners are doing over time: by day, week or month, for every
 * course or one, with each figure against the range before. */
export function DashboardPage() {
  const { api } = useSession()
  const [params, setParams] = useSearchParams()
  const period: ReportPeriod = isPeriod(params.get('period')) ? (params.get('period') as ReportPeriod) : 'week'
  const courseId = params.get('course') ?? ''
  const end = params.get('end') ?? ''
  const [report, setReport] = useState<AdminReport | null>(null)
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
          return next
        },
        { replace: true },
      ),
    [setParams],
  )

  useEffect(() => {
    let live = true
    api.get<AdminCourseList>(routes.courses).then(
      (list) => live && setCourses(list.courses),
      () => undefined, // The filter just stays at All courses.
    )
    return () => {
      live = false
    }
  }, [api])

  useEffect(() => {
    let live = true
    const query = new URLSearchParams({ period, count: String(PERIOD_COUNT[period]) })
    if (courseId) query.set('course_id', courseId)
    if (end) query.set('end', end)
    api.get<AdminReport>(`${routes.reports}?${query}`).then(
      (r) => {
        if (!live) return
        setReport(r)
        setError(null)
      },
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api, period, courseId, end, attempt])

  const noun = PERIODS.find((p) => p.key === period)!.noun
  const shown = report && report.period === period ? report : null
  // The newest range ends with the day, week or month holding today.
  const atLatest = !end || !shown || shown.buckets.at(-1)!.partial

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Learners"
        title="Dashboard"
        description="How learners are doing, counted by day, week or month. Days are UTC days and weeks start on Monday, as streaks and leagues count them."
        actions={
          <Button
            disabled={!shown}
            onClick={() => shown && saveFile(`buna-report-${shown.period}-${shown.start}-to-${shown.end}.csv`, reportCsv(shown), CSV_TYPE)}
          >
            <Icon name="download" className="text-lg" />
            Download CSV
          </Button>
        }
      />

      <div className="mt-6 flex flex-wrap items-center gap-3">
        <div className="flex rounded bg-inset p-1" role="group" aria-label="Count by">
          {PERIODS.map((p) => (
            <button
              key={p.key}
              type="button"
              aria-pressed={period === p.key}
              onClick={() => update({ period: p.key === 'week' ? '' : p.key, end: '' })}
              className={cx(
                'rounded-sm px-3 py-1.5 text-sm font-semibold transition-colors',
                period === p.key ? 'bg-surface text-forest shadow-e1' : 'text-stone hover:text-coffee',
              )}
            >
              {p.label}
            </button>
          ))}
        </div>
        <label className="flex min-w-0 items-center gap-2 text-sm text-stone">
          <span className="shrink-0">Course</span>
          <select
            className={cx(FIELD_CLASS, 'w-auto max-w-[16rem]')}
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
        <div className="flex items-center gap-1 sm:ml-auto">
          <Button
            size="icon"
            variant="ghost"
            aria-label={`Earlier ${noun}s`}
            disabled={!shown}
            onClick={() => shown && update({ end: shiftedEnd(shown, -1) })}
          >
            <Icon name="chevron_left" className="text-xl" />
          </Button>
          <span className="tnum min-w-[11rem] text-center text-sm font-semibold text-coffee">
            {shown ? rangeLabel(shown.start, shown.end) : 'Loading…'}
          </span>
          <Button
            size="icon"
            variant="ghost"
            aria-label={`Later ${noun}s`}
            disabled={atLatest}
            onClick={() => shown && update({ end: shiftedEnd(shown, 1) })}
          >
            <Icon name="chevron_right" className="text-xl" />
          </Button>
          {end && (
            <Button size="sm" variant="ghost" onClick={() => update({ end: '' })}>
              Latest
            </Button>
          )}
        </div>
      </div>

      {error && <ErrorBanner message={error} onRetry={() => setAttempt((n) => n + 1)} />}

      {shown && (
        <>
          <h2 className="mt-8 text-xs font-bold tracking-[0.12em] text-stone uppercase">Right now</h2>
          <StatRow className="mt-3">
            <StatCard icon="group" label={courseId ? 'Learners on this course' : 'Learners'} value={shown.now.total_learners} />
            <StatCard icon="today" label="Active today" value={shown.now.active_today} tone="forest" />
            <StatCard icon="date_range" label="Active in the last 7 days" value={shown.now.active_7_days} tone="forest" />
            <StatCard icon="calendar_month" label="Active in the last 30 days" value={shown.now.active_30_days} />
          </StatRow>

          <h2 className="mt-8 text-xs font-bold tracking-[0.12em] text-stone uppercase">
            {rangeLabel(shown.start, shown.end)} · against the {shown.buckets.length} {noun}s before
          </h2>
          <dl className="mt-3 grid grid-cols-2 gap-3 lg:grid-cols-4">
            {METRICS.map((m) => (
              <TrendCard
                key={m.key}
                icon={m.icon}
                label={m.label}
                hint={m.hint}
                value={metricValue(shown.totals, m.key)}
                trend={trend(shown.totals[m.key], shown.previous[m.key], m.kind)}
              />
            ))}
          </dl>

          <div className="mt-6 grid gap-6 lg:grid-cols-2">
            {CHARTS.map((chart) => {
              const total = shown.totals[chart.key] ?? 0
              return (
                <Panel
                  key={chart.key}
                  title={chart.title}
                  description={`Per ${noun}. ${chart.key === 'active_learners' ? `${count(total)} different learners in all` : `${count(total)} in all`}.`}
                >
                  <BarChart
                    tone={chart.tone}
                    summary={`${chart.title} per ${noun}, ${rangeLabel(shown.start, shown.end)}`}
                    bars={shown.buckets.map((b) => ({
                      key: b.start,
                      label: bucketLabel(b, shown.period),
                      name: bucketName(b, shown.period),
                      value: b.totals[chart.key] ?? 0,
                      display: count(b.totals[chart.key] ?? 0),
                      partial: b.partial,
                    }))}
                  />
                </Panel>
              )
            })}
          </div>

          <Panel
            className="mt-6"
            flush
            title={`${PERIODS.find((p) => p.key === period)!.label} figures`}
            description={`Newest first. A ${noun} still going on is marked “so far”.`}
            icon="table_chart"
          >
            <div className="overflow-x-auto">
              <table className="w-full min-w-[44rem] text-sm" aria-label={`${PERIODS.find((p) => p.key === period)!.label} figures`}>
                <thead className="bg-canvas text-left text-xs text-stone">
                  <tr>
                    <th scope="col" className="px-4 py-2.5 font-semibold sm:px-6">
                      {noun[0]!.toUpperCase() + noun.slice(1)}
                    </th>
                    {METRICS.map((m) => (
                      <th key={m.key} scope="col" className="px-3 py-2.5 text-right font-semibold">
                        {m.label}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {[...shown.buckets].reverse().map((b) => (
                    <tr key={b.start}>
                      <th scope="row" className="px-4 py-2.5 text-left font-semibold whitespace-nowrap text-coffee sm:px-6">
                        {bucketName(b, shown.period)}
                        {b.partial && <span className="ml-2 text-xs font-normal text-stone">so far</span>}
                      </th>
                      {METRICS.map((m) => (
                        <td key={m.key} className="tnum px-3 py-2.5 text-right text-coffee-soft">
                          {metricValue(b.totals, m.key)}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Panel>

          <div className="mt-6 grid gap-6 lg:grid-cols-2">
            <Panel flush title="Courses" icon="school" description="In this range. Learners: on the course now.">
              <div className="overflow-x-auto">
                <table className="w-full text-sm" aria-label="Courses">
                  <thead className="bg-canvas text-left text-xs text-stone">
                    <tr>
                      <th scope="col" className="px-4 py-2.5 font-semibold sm:px-6">Course</th>
                      <th scope="col" className="px-3 py-2.5 text-right font-semibold">Learners</th>
                      <th scope="col" className="px-3 py-2.5 text-right font-semibold">Active</th>
                      <th scope="col" className="px-3 py-2.5 text-right font-semibold">Lessons</th>
                      <th scope="col" className="px-3 py-2.5 pr-4 text-right font-semibold sm:pr-6">XP</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-line">
                    {shown.courses.map((c) => (
                      <tr key={c.course_id}>
                        <th scope="row" className="px-4 py-2.5 text-left font-semibold text-coffee sm:px-6">
                          {c.title}
                        </th>
                        <td className="tnum px-3 py-2.5 text-right">{count(c.learners)}</td>
                        <td className="tnum px-3 py-2.5 text-right">{count(c.active_learners)}</td>
                        <td className="tnum px-3 py-2.5 text-right">{count(c.lessons)}</td>
                        <td className="tnum px-3 py-2.5 pr-4 text-right sm:pr-6">{count(c.xp)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Panel>

            <Panel flush title="Top learners" icon="emoji_events" description="Most XP in this range.">
              {shown.top_learners.length === 0 ? (
                <p className="px-6 py-10 text-center text-sm text-stone">No one studied in this range.</p>
              ) : (
                <ol className="divide-y divide-line">
                  {shown.top_learners.map((l, i) => (
                    <li key={l.id}>
                      <Link to={`/learners/${l.id}`} className="group flex items-center gap-3 px-4 py-2.5 hover:bg-canvas sm:px-6">
                        <span className="tnum w-5 text-right text-sm font-bold text-stone">{i + 1}</span>
                        <Avatar name={l.name} className="size-8 text-[0.6875rem]" />
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-sm font-semibold text-coffee group-hover:text-forest">{l.name}</span>
                          <span className="block truncate text-xs text-stone">
                            {count(l.lessons)} lessons · {percent(l.accuracy)} right
                          </span>
                        </span>
                        <span className="tnum text-sm font-bold text-forest">{count(l.xp)} XP</span>
                      </Link>
                    </li>
                  ))}
                </ol>
              )}
            </Panel>
          </div>
        </>
      )}

      {!shown && !error && <p className="mt-10 text-center text-sm text-stone">Loading the report…</p>}
    </main>
  )
}
