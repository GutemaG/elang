import { useCallback, useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { plural } from '../format'
import { Avatar, ErrorBanner, Panel } from '../learners/charts'
import { formatDate } from '../learners/report'
import { PageHeader, StatCard, StatRow } from '../shell/Page'
import { routes } from '../tree/levels'
import type { AdminFeedbackItem, AdminFeedbackPage, FeedbackCategory, FeedbackStatus } from '../types'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS, Input } from '../ui/Input'

const PAGE = 25

export const CATEGORIES: Record<FeedbackCategory, { label: string; icon: string; className: string }> = {
  bug: { label: 'Problem', icon: 'bug_report', className: 'bg-danger-tint text-danger' },
  idea: { label: 'Idea', icon: 'lightbulb', className: 'bg-forest-tint text-forest' },
  content: { label: 'Content mistake', icon: 'spellcheck', className: 'bg-terracotta-tint text-terracotta' },
  other: { label: 'Other', icon: 'chat', className: 'bg-inset text-coffee-soft' },
}

const STATUSES: { key: FeedbackStatus | 'all'; label: string }[] = [
  { key: 'open', label: 'Open' },
  { key: 'resolved', label: 'Resolved' },
  { key: 'all', label: 'All' },
]

/** What learners send from the app's Settings, newest first. Open
 * messages show by default; marking one resolved moves it out of the way.
 * The filters live in the address, so a learner's page can link here. */
export function FeedbackPage() {
  const { api } = useSession()
  const [params, setParams] = useSearchParams()
  const status = STATUSES.some((s) => s.key === params.get('status')) ? (params.get('status') as FeedbackStatus | 'all') : 'open'
  const category = params.get('category') ?? ''
  const learnerId = params.get('learner') ?? ''
  const search = params.get('q') ?? ''
  const offset = Math.max(0, Number(params.get('from')) || 0)

  const [typed, setTyped] = useState(search)
  const [page, setPage] = useState<AdminFeedbackPage | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)
  const [busy, setBusy] = useState<string | null>(null)

  const update = useCallback(
    (changes: Record<string, string>) =>
      setParams(
        (current) => {
          const next = new URLSearchParams(current)
          for (const [key, value] of Object.entries(changes)) {
            if (value) next.set(key, value)
            else next.delete(key)
          }
          if (!('from' in changes)) next.delete('from')
          return next
        },
        { replace: true },
      ),
    [setParams],
  )

  useEffect(() => {
    if (typed.trim() === search) return
    const timer = setTimeout(() => update({ q: typed.trim() }), 300)
    return () => clearTimeout(timer)
  }, [typed, search, update])

  useEffect(() => {
    let live = true
    const query = new URLSearchParams({ offset: String(offset), limit: String(PAGE) })
    if (status !== 'all') query.set('status', status)
    if (category) query.set('category', category)
    if (learnerId) query.set('user_id', learnerId)
    if (search) query.set('search', search)
    api.get<AdminFeedbackPage>(`${routes.feedback}?${query}`).then(
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
  }, [api, status, category, learnerId, search, offset, attempt])

  async function setStatus(item: AdminFeedbackItem, next: FeedbackStatus) {
    setBusy(item.id)
    try {
      await api.patch(routes.feedbackItem(item.id), { status: next })
      setAttempt((n) => n + 1)
    } catch (e) {
      setError(messageOf(e))
    } finally {
      setBusy(null)
    }
  }

  const learnerName = page?.items.find((i) => i.learner_id === learnerId)?.learner_name ?? 'this learner'
  const filtered = Boolean(category || learnerId || search)

  return (
    <main className="mx-auto max-w-5xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Learners"
        title="Feedback"
        description="What learners send from Settings → Send feedback in the app: problems, ideas and mistakes in lessons. Mark a message resolved once it is dealt with."
      />

      {error && <ErrorBanner message={error} onRetry={() => setAttempt((n) => n + 1)} />}

      {page && (
        <StatRow>
          <StatCard icon="mark_email_unread" label="Open" value={page.open} tone="terracotta" />
          <StatCard icon="task_alt" label="Resolved" value={page.resolved} tone="forest" />
          <StatCard
            icon="star"
            label={page.rated ? `Average rating (${plural(page.rated, 'rating')})` : 'Average rating'}
            value={page.average_rating === null ? '—' : `${page.average_rating.toFixed(1)} / 5`}
          />
          <StatCard icon="bug_report" label="Open problems" value={page.open_by_category.bug} />
        </StatRow>
      )}

      <div className="mt-6 flex flex-wrap items-center gap-3">
        <div className="flex rounded bg-inset p-1" role="group" aria-label="Show">
          {STATUSES.map((s) => (
            <button
              key={s.key}
              type="button"
              aria-pressed={status === s.key}
              onClick={() => update({ status: s.key === 'open' ? '' : s.key })}
              className={cx(
                'rounded-sm px-3 py-1.5 text-sm font-semibold transition-colors',
                status === s.key ? 'bg-surface text-forest shadow-e1' : 'text-stone hover:text-coffee',
              )}
            >
              {s.label}
            </button>
          ))}
        </div>
        <label className="min-w-0">
          <span className="sr-only">Kind</span>
          <select className={cx(FIELD_CLASS, 'w-auto')} value={category} onChange={(e) => update({ category: e.target.value })}>
            <option value="">All kinds</option>
            {(Object.keys(CATEGORIES) as FeedbackCategory[]).map((key) => (
              <option key={key} value={key}>
                {CATEGORIES[key].label}
                {page ? ` (${page.open_by_category[key]} open)` : ''}
              </option>
            ))}
          </select>
        </label>
        <label className="relative min-w-0 flex-1 sm:max-w-xs">
          <span className="sr-only">Search messages</span>
          <Icon name="search" className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-lg text-stone" />
          <Input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder="Words, name or email" className="pl-9" />
        </label>
        {learnerId && (
          <span className="inline-flex items-center gap-1 rounded-full border border-line bg-surface py-1 pr-1 pl-3 text-sm text-coffee">
            From {learnerName}
            <button
              type="button"
              aria-label="Show feedback from everyone"
              onClick={() => update({ learner: '' })}
              className="grid size-6 place-items-center rounded-full text-stone hover:bg-inset hover:text-coffee"
            >
              <Icon name="close" className="text-base" />
            </button>
          </span>
        )}
      </div>

      <Panel
        className="mt-4"
        flush
        title={status === 'all' ? 'All feedback' : status === 'open' ? 'Open feedback' : 'Resolved feedback'}
        icon="feedback"
        description={page ? `${plural(page.total, 'message')}${filtered ? ' match' : ''}.` : 'Loading…'}
      >
        {page?.items.length === 0 && (
          <p className="px-6 py-12 text-center text-sm text-stone">
            {filtered ? 'No feedback matches.' : status === 'open' ? 'Nothing open. All caught up.' : 'No feedback yet.'}
          </p>
        )}
        {page && page.items.length > 0 && (
          <ol className="divide-y divide-line" aria-label="Feedback">
            {page.items.map((item) => (
              <FeedbackRow
                key={item.id}
                item={item}
                busy={busy === item.id}
                onStatus={(next) => void setStatus(item, next)}
              />
            ))}
          </ol>
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
        {!page && !error && <p className="px-6 py-12 text-center text-sm text-stone">Loading feedback…</p>}
      </Panel>
    </main>
  )
}

function FeedbackRow({
  item,
  busy,
  onStatus,
}: {
  item: AdminFeedbackItem
  busy: boolean
  onStatus: (status: FeedbackStatus) => void
}) {
  const kind = CATEGORIES[item.category]
  const resolved = item.status === 'resolved'
  return (
    <li className={cx('flex gap-3 px-4 py-4 sm:px-6', resolved && 'opacity-75')} aria-label={`${kind.label} from ${item.learner_name}`}>
      <span className={cx('mt-0.5 grid size-9 shrink-0 place-items-center rounded', kind.className)}>
        <Icon name={kind.icon} className="text-lg" />
      </span>
      <div className="min-w-0 flex-1">
        <p className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
          <span className="font-semibold text-coffee">{kind.label}</span>
          {item.rating !== null && <Stars rating={item.rating} />}
          {resolved ? (
            <Badge tone="published" dot title={item.resolved_at ? `Resolved ${formatDate(item.resolved_at)}` : undefined}>
              Resolved
            </Badge>
          ) : (
            <Badge tone="draft" dot>
              Open
            </Badge>
          )}
          <span className="ml-auto text-xs text-stone">{formatDate(item.created_at)}</span>
        </p>
        <p className="mt-1.5 text-sm leading-6 break-words whitespace-pre-wrap text-coffee">{item.message}</p>
        <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 text-xs text-stone">
          <Link to={`/learners/${item.learner_id}`} className="inline-flex items-center gap-2 font-semibold text-coffee hover:text-forest">
            <Avatar name={item.learner_name} className="size-6 text-[0.625rem]" />
            {item.learner_name}
          </Link>
          {item.learner_email && <span>{item.learner_email}</span>}
          {item.course_title && (
            <span className="inline-flex items-center gap-1">
              <Icon name="school" className="text-sm" />
              {item.course_title}
            </span>
          )}
          {item.platform && (
            <span className="inline-flex items-center gap-1">
              <Icon name="smartphone" className="text-sm" />
              {platformName(item.platform)}
            </span>
          )}
          <span className="ml-auto">
            {resolved ? (
              <Button size="sm" variant="ghost" disabled={busy} onClick={() => onStatus('open')}>
                <Icon name="undo" className="text-base" />
                Reopen
              </Button>
            ) : (
              <Button size="sm" disabled={busy} onClick={() => onStatus('resolved')}>
                <Icon name="check" className="text-base" />
                Mark resolved
              </Button>
            )}
          </span>
        </div>
      </div>
    </li>
  )
}

function Stars({ rating }: { rating: number }) {
  return (
    <span className="inline-flex items-center text-terracotta" role="img" aria-label={`Rated ${rating} out of 5`}>
      {[1, 2, 3, 4, 5].map((n) => (
        <Icon key={n} name="star" filled={n <= rating} className={cx('text-sm', n > rating && 'text-line-strong')} />
      ))}
    </span>
  )
}

const PLATFORMS: Record<string, string> = { android: 'Android', ios: 'iPhone', web: 'Web', macos: 'Mac', windows: 'Windows', linux: 'Linux' }

export function platformName(platform: string): string {
  return PLATFORMS[platform] ?? platform
}
