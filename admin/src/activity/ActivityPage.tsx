import { Fragment, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { Link, useSearchParams } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { plural } from '../format'
import { ErrorBanner } from '../learners/charts'
import { PageHeader } from '../shell/Page'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS, Input } from '../ui/Input'
import { ACTIVITY, AREAS, areaOf, detailRows, exactTime, relativeTime, type ActivityEntry, type ActivityPage as Page } from './api'

const TH = 'px-3 py-2.5 text-left text-xs font-semibold whitespace-nowrap text-stone'
const TD = 'px-3 py-3 align-top'
const FILTERS = ['admin', 'area', 'course', 'since', 'until', 'q'] as const

/** Every change made in the admin site, newest first: who, what, where.
 * Recorded by the server for each successful change; reads, failed saves
 * and upload links are not. The filters live in the address. */
export function ActivityPage() {
  const { api } = useSession()
  const [params, setParams] = useSearchParams()
  const filters = Object.fromEntries(FILTERS.map((f) => [f, params.get(f) ?? ''])) as Record<(typeof FILTERS)[number], string>

  const [typed, setTyped] = useState(filters.q)
  const [page, setPage] = useState<Page | null>(null)
  const [items, setItems] = useState<ActivityEntry[]>([])
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)
  const [loadingMore, setLoadingMore] = useState(false)
  const [open, setOpen] = useState<string | null>(null)

  const update = useCallback(
    (changes: Partial<Record<(typeof FILTERS)[number], string>>) =>
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
    if (typed.trim() === filters.q) return
    const timer = setTimeout(() => update({ q: typed.trim() }), 300)
    return () => clearTimeout(timer)
  }, [typed, filters.q, update])

  const query = useMemo(() => {
    const q = new URLSearchParams()
    if (filters.admin) q.set('admin', filters.admin)
    if (filters.area) q.set('area', filters.area)
    if (filters.course) q.set('course_id', filters.course)
    if (filters.since) q.set('since', filters.since)
    if (filters.until) q.set('until', filters.until)
    if (filters.q) q.set('search', filters.q)
    return q
  }, [filters.admin, filters.area, filters.course, filters.since, filters.until, filters.q])

  useEffect(() => {
    let live = true
    const text = query.toString()
    api.get<Page>(text ? `${ACTIVITY}?${text}` : ACTIVITY).then(
      (p) => {
        if (!live) return
        setPage(p)
        setItems(p.items)
        setError(null)
      },
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api, query, attempt])

  async function loadMore() {
    if (!page?.next_cursor) return
    setLoadingMore(true)
    try {
      const q = new URLSearchParams(query)
      q.set('cursor', page.next_cursor)
      const next = await api.get<Page>(`${ACTIVITY}?${q}`)
      setPage(next)
      setItems((current) => [...current, ...next.items])
    } catch (e) {
      setError(messageOf(e))
    } finally {
      setLoadingMore(false)
    }
  }

  const courseTitle = useMemo(() => new Map((page?.courses ?? []).map((c) => [c.id, c.title])), [page])
  const filtered = FILTERS.some((f) => filters[f])

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Configuration"
        title="Activity log"
        description="Every change made in this site: who made it, when, and to what. Reads, failed saves and upload links aren’t recorded. Entries are kept for two years."
      />

      {error && <ErrorBanner message={error} onRetry={() => setAttempt((n) => n + 1)} />}

      <section className="mt-6 overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
        <div className="flex flex-col gap-3 border-b border-line px-4 py-4 sm:px-5">
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-[minmax(12rem,2fr)_repeat(3,minmax(0,1fr))]">
            <label className="relative min-w-0 sm:col-span-2 lg:col-span-1">
              <span className="sr-only">Search</span>
              <Icon name="search" className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-lg text-stone" />
              <Input
                type="search"
                value={typed}
                onChange={(e) => setTyped(e.target.value)}
                placeholder="Action, name or id"
                className="pl-9"
              />
            </label>
            <Select label="Admin" value={filters.admin} onChange={(v) => update({ admin: v })}>
              <option value="">Every admin</option>
              {page?.admins.map((a) => (
                <option key={a} value={a}>
                  {a}
                </option>
              ))}
            </Select>
            <Select label="Area" value={filters.area} onChange={(v) => update({ area: v })}>
              <option value="">Every area</option>
              {(page?.areas ?? Object.keys(AREAS)).map((a) => (
                <option key={a} value={a}>
                  {areaOf(a).label}
                </option>
              ))}
            </Select>
            <Select label="Course" value={filters.course} onChange={(v) => update({ course: v })}>
              <option value="">Every course</option>
              {page?.courses.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.title}
                </option>
              ))}
            </Select>
          </div>
          <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
            <label className="flex items-center gap-2 text-sm text-coffee-soft">
              From
              <input
                type="date"
                aria-label="From"
                className={cx(FIELD_CLASS, 'w-auto', filters.since && 'border-forest text-forest')}
                value={filters.since}
                max={filters.until || undefined}
                onChange={(e) => update({ since: e.target.value })}
              />
            </label>
            <label className="flex items-center gap-2 text-sm text-coffee-soft">
              To
              <input
                type="date"
                aria-label="To"
                className={cx(FIELD_CLASS, 'w-auto', filters.until && 'border-forest text-forest')}
                value={filters.until}
                min={filters.since || undefined}
                onChange={(e) => update({ until: e.target.value })}
              />
            </label>
            <span className="flex-1" />
            <span className="text-sm text-coffee-soft">
              {page ? `${plural(page.total, 'change')}${filtered ? ' match' : ''}` : 'Loading…'}
            </span>
            {filtered && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setTyped('')
                  update(Object.fromEntries(FILTERS.map((f) => [f, ''])))
                }}
              >
                <Icon name="filter_alt_off" className="text-lg" />
                Clear filters
              </Button>
            )}
          </div>
        </div>

        {page && items.length === 0 && (
          <p className="px-4 py-12 text-center text-sm text-stone">
            {filtered ? 'No changes match these filters.' : 'No changes yet. They appear here as admins edit.'}
          </p>
        )}
        {items.length > 0 && (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[56rem] text-sm">
              <thead className="bg-canvas">
                <tr>
                  <th scope="col" className={cx(TH, 'pl-4 sm:pl-5')}>
                    When
                  </th>
                  <th scope="col" className={TH}>
                    Admin
                  </th>
                  <th scope="col" className={TH}>
                    Area
                  </th>
                  <th scope="col" className={TH}>
                    Action
                  </th>
                  <th scope="col" className={TH}>
                    Target
                  </th>
                  <th scope="col" className={TH}>
                    Course
                  </th>
                  <th scope="col" className={cx(TH, 'pr-4 sm:pr-5')}>
                    <span className="sr-only">Open</span>
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {items.map((entry) => (
                  <EntryRow
                    key={entry.id}
                    entry={entry}
                    course={entry.course_id ? (courseTitle.get(entry.course_id) ?? 'Deleted course') : null}
                    expanded={open === entry.id}
                    onToggle={() => setOpen((current) => (current === entry.id ? null : entry.id))}
                  />
                ))}
              </tbody>
            </table>
          </div>
        )}
        {page?.next_cursor && (
          <div className="flex justify-center border-t border-line px-4 py-3">
            <Button size="sm" disabled={loadingMore} onClick={() => void loadMore()}>
              {loadingMore ? 'Loading…' : 'Load older changes'}
            </Button>
          </div>
        )}
        {!page && !error && <p className="px-4 py-12 text-center text-sm text-stone">Loading activity…</p>}
      </section>
    </main>
  )
}

function Select({
  label,
  value,
  onChange,
  children,
}: {
  label: string
  value: string
  onChange: (value: string) => void
  children: ReactNode
}) {
  return (
    <label className="min-w-0">
      <span className="sr-only">{label}</span>
      <select className={cx(FIELD_CLASS, value && 'border-forest text-forest')} value={value} onChange={(e) => onChange(e.target.value)}>
        {children}
      </select>
    </label>
  )
}

function EntryRow({
  entry,
  course,
  expanded,
  onToggle,
}: {
  entry: ActivityEntry
  course: string | null
  expanded: boolean
  onToggle: () => void
}) {
  const area = areaOf(entry.area)
  const details = detailRows(entry.details)
  return (
    <Fragment>
      <tr className={cx('hover:bg-canvas', expanded && 'bg-canvas')}>
        <td className={cx(TD, 'pl-4 whitespace-nowrap text-coffee-soft sm:pl-5')}>
          <time dateTime={entry.created_at} title={exactTime(entry.created_at)}>
            {relativeTime(entry.created_at)}
          </time>
        </td>
        <td className={cx(TD, 'max-w-[14rem]')}>
          <span className="block break-all text-coffee">{entry.admin_email}</span>
          {entry.admin_role === 'course_admin' && <span className="text-xs text-stone">Course admin</span>}
        </td>
        <td className={cx(TD, 'whitespace-nowrap')}>
          <span className="inline-flex items-center gap-1 text-coffee-soft">
            <Icon name={area.icon} className="text-base text-stone" />
            {area.label}
          </span>
        </td>
        <td className={TD}>
          <button
            type="button"
            onClick={onToggle}
            aria-expanded={expanded}
            className="inline-flex items-start gap-1 text-left font-semibold text-coffee hover:text-forest"
          >
            <Icon name={expanded ? 'expand_less' : 'expand_more'} className="text-base text-stone" />
            {entry.action}
          </button>
          {entry.method === 'DELETE' && (
            <Badge tone="draft" className="ml-2">
              Deleted
            </Badge>
          )}
        </td>
        <td className={cx(TD, 'max-w-[18rem] break-words text-coffee')}>
          {entry.target_name ?? <span className="text-stone">{entry.target_id ?? '—'}</span>}
        </td>
        <td className={cx(TD, 'max-w-[12rem] text-coffee-soft')}>{course ?? <span className="text-stone">—</span>}</td>
        <td className={cx(TD, 'pr-4 text-right sm:pr-5')}>
          {entry.link && (
            <Link
              to={entry.link}
              aria-label={`Open ${entry.target_name ?? entry.action}`}
              className="inline-flex shrink-0 items-center gap-0.5 rounded px-1.5 py-0.5 text-sm font-semibold text-forest hover:bg-forest-tint"
            >
              Open
              <Icon name="arrow_forward" className="text-base" />
            </Link>
          )}
        </td>
      </tr>
      {expanded && (
        <tr className="bg-canvas">
          <td colSpan={7} className="px-4 pb-4 sm:px-5">
            <dl className="grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1 text-xs">
              {details.map((d) => (
                <Fragment key={d.label}>
                  <dt className="font-semibold text-stone">{d.label}</dt>
                  <dd className="break-words text-coffee">{d.value}</dd>
                </Fragment>
              ))}
              <dt className="font-semibold text-stone">When</dt>
              <dd className="text-coffee">{exactTime(entry.created_at)}</dd>
              {entry.target_id && (
                <>
                  <dt className="font-semibold text-stone">Id</dt>
                  <dd className="font-mono break-all text-coffee">{entry.target_id}</dd>
                </>
              )}
              <dt className="font-semibold text-stone">Request</dt>
              <dd className="font-mono break-all text-coffee">
                {entry.method} {entry.route}
              </dd>
            </dl>
          </td>
        </tr>
      )}
    </Fragment>
  )
}
