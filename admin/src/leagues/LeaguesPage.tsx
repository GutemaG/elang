import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { messageOf, useSession } from '../auth/SessionContext'
import { plural } from '../format'
import { Avatar, ErrorBanner } from '../learners/charts'
import { count, lastSeen } from '../learners/report'
import { PageHeader, StatCard, StatRow } from '../shell/Page'
import { Badge } from '../ui/Badge'
import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { FIELD_CLASS, Input } from '../ui/Input'
import { Modal } from '../ui/Modal'
import {
  leagueMember,
  LEAGUES,
  signed,
  tierName,
  TIERS,
  timeLeft,
  weekLabel,
  zoneOf,
  type LeagueGroup,
  type LeagueMember,
  type LeagueWeek,
  type Tier,
} from './api'

const TH = 'px-3 py-2.5 text-left text-xs font-semibold whitespace-nowrap text-stone'
const TD = 'px-3 py-3 align-middle'

type Dialog = { kind: 'adjust' | 'remove'; group: LeagueGroup; member: LeagueMember }

/** Weekly leagues: every group of a week, ranked as the app ranks it. In
 * the current week a member can be taken out (cheating) or have their XP
 * corrected; both apply on the learner's next open of the app. The week,
 * tier and search live in the address, so the activity log can link here. */
export function LeaguesPage() {
  const { api } = useSession()
  const [params, setParams] = useSearchParams()
  const week = params.get('week') ?? ''
  const tier = (params.get('tier') ?? '') as Tier | ''
  const search = params.get('q') ?? ''

  const [typed, setTyped] = useState(search)
  const [data, setData] = useState<LeagueWeek | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)
  const [dialog, setDialog] = useState<Dialog | null>(null)
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
          return next
        },
        { replace: true },
      ),
    [setParams],
  )

  useEffect(() => {
    if (typed.trim() === search) return
    const timer = setTimeout(() => update({ q: typed.trim() }), 250)
    return () => clearTimeout(timer)
  }, [typed, search, update])

  useEffect(() => {
    let live = true
    api.get<LeagueWeek>(week ? `${LEAGUES}?week=${encodeURIComponent(week)}` : LEAGUES).then(
      (w) => {
        if (!live) return
        setData(w)
        setError(null)
      },
      (e: unknown) => live && setError(messageOf(e)),
    )
    return () => {
      live = false
    }
  }, [api, week, attempt])

  async function restore(member: LeagueMember) {
    setBusy(member.member_id)
    try {
      await api.post(`${leagueMember(member.member_id)}/restore`)
      setAttempt((n) => n + 1)
    } catch (e) {
      setError(messageOf(e))
    } finally {
      setBusy(null)
    }
  }

  const needle = search.toLowerCase()
  const groups = useMemo(() => {
    if (!data) return []
    return data.groups
      .filter((g) => !tier || g.tier === tier)
      .map((g) => ({
        group: g,
        shown: needle
          ? g.members.filter((m) =>
              [m.first_name, m.shown_name, m.email].some((v) => v?.toLowerCase().includes(needle)),
            )
          : g.members,
      }))
      .filter(({ shown }) => !needle || shown.length > 0)
  }, [data, tier, needle])

  const tierCounts = useMemo(() => {
    const counts = new Map<Tier, number>()
    for (const g of data?.groups ?? []) counts.set(g.tier, (counts.get(g.tier) ?? 0) + 1)
    return counts
  }, [data])

  const editable = Boolean(data?.is_current)
  const filtered = Boolean(tier || search)

  return (
    <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
      <PageHeader
        eyebrow="Learners"
        title="Leagues"
        description="Each week learners are grouped by tier, up to 30 a group, and ranked by the XP they earn. When the week ends the top move up, the bottom move down, and the top three earn Amole."
      />

      {error && <ErrorBanner message={error} onRetry={() => setAttempt((n) => n + 1)} />}

      {data && (
        <>
          <div className="mt-6 flex flex-wrap items-center gap-3">
            <label className="min-w-0">
              <span className="sr-only">Week</span>
              <select
                className={cx(FIELD_CLASS, 'w-auto')}
                value={data.week_start}
                onChange={(e) => update({ week: e.target.value === data.weeks[0] ? '' : e.target.value })}
              >
                {data.weeks.map((w, i) => (
                  <option key={w} value={w}>
                    {i === 0 ? 'This week' : weekLabel(w)}
                    {i === 0 ? ` · ${weekLabel(w)}` : ''}
                  </option>
                ))}
              </select>
            </label>
            {data.is_current ? (
              <span className="inline-flex items-center gap-1.5 text-sm text-coffee-soft">
                <Icon name="schedule" className="text-lg text-stone" />
                Ends in {timeLeft(data.week_end)}
              </span>
            ) : (
              <span className="inline-flex items-center gap-1.5 text-sm text-coffee-soft">
                <Icon name="history" className="text-lg text-stone" />
                Past week: results as stored when each group closed
              </span>
            )}
          </div>

          <StatRow>
            <StatCard icon="groups" label="Groups" value={data.totals.groups} />
            <StatCard icon="person" label="Members" value={count(data.totals.members)} tone="forest" />
            <StatCard icon="person_off" label="Removed" value={data.totals.removed} tone="terracotta" />
            <StatCard icon="bolt" label={data.is_current ? 'XP this week' : 'XP that week'} value={count(data.totals.xp)} />
          </StatRow>

          <div className="mt-6 flex flex-wrap items-center gap-3">
            <label className="min-w-0">
              <span className="sr-only">Tier</span>
              <select
                className={cx(FIELD_CLASS, 'w-auto', tier && 'border-forest text-forest')}
                value={tier}
                onChange={(e) => update({ tier: e.target.value })}
              >
                <option value="">All tiers</option>
                {TIERS.map((t) => (
                  <option key={t.key} value={t.key}>
                    {t.name} ({tierCounts.get(t.key) ?? 0})
                  </option>
                ))}
              </select>
            </label>
            <label className="relative min-w-0 flex-1 sm:max-w-xs">
              <span className="sr-only">Search learners</span>
              <Icon name="search" className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-lg text-stone" />
              <Input type="search" value={typed} onChange={(e) => setTyped(e.target.value)} placeholder="Name or email" className="pl-9" />
            </label>
            {filtered && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setTyped('')
                  update({ tier: '', q: '' })
                }}
              >
                <Icon name="filter_alt_off" className="text-lg" />
                Clear filters
              </Button>
            )}
            <Legend />
          </div>

          {data.groups.length === 0 && (
            <p className="mt-4 rounded-lg border border-line bg-surface px-6 py-12 text-center text-sm text-stone shadow-e1">
              {data.is_current ? 'Nobody has earned XP this week yet. A learner joins with their first XP.' : 'No leagues that week.'}
            </p>
          )}
          {data.groups.length > 0 && groups.length === 0 && (
            <p className="mt-4 rounded-lg border border-line bg-surface px-6 py-12 text-center text-sm text-stone shadow-e1">
              No learners match.
            </p>
          )}

          <div className="mt-4 flex flex-col gap-4">
            {groups.map(({ group, shown }, i) => (
              <GroupTable
                key={group.group_id}
                group={group}
                members={shown}
                number={groups.slice(0, i + 1).filter((g) => g.group.tier === group.tier).length}
                editable={editable && group.status === 'open'}
                busy={busy}
                onAdjust={(member) => setDialog({ kind: 'adjust', group, member })}
                onRemove={(member) => setDialog({ kind: 'remove', group, member })}
                onRestore={(member) => void restore(member)}
              />
            ))}
          </div>
        </>
      )}

      {!data && !error && <p className="mt-6 text-sm text-stone">Loading leagues…</p>}

      {dialog?.kind === 'adjust' && (
        <AdjustDialog
          group={dialog.group}
          member={dialog.member}
          onClose={() => setDialog(null)}
          onSaved={() => {
            setDialog(null)
            setAttempt((n) => n + 1)
          }}
        />
      )}
      {dialog?.kind === 'remove' && (
        <RemoveDialog
          member={dialog.member}
          onClose={() => setDialog(null)}
          onSaved={() => {
            setDialog(null)
            setAttempt((n) => n + 1)
          }}
        />
      )}
    </main>
  )
}

function Legend() {
  return (
    <span className="ml-auto flex flex-wrap items-center gap-3 text-xs text-stone">
      <span className="inline-flex items-center gap-1">
        <span aria-hidden="true" className="h-3 w-1 rounded-full bg-forest" />
        Moves up
      </span>
      <span className="inline-flex items-center gap-1">
        <span aria-hidden="true" className="h-3 w-1 rounded-full bg-terracotta" />
        Moves down
      </span>
    </span>
  )
}

const STATUS_BADGE: Record<LeagueGroup['status'], { label: string; tone: 'published' | 'draft' | 'neutral' }> = {
  open: { label: 'Live', tone: 'published' },
  ended: { label: 'Waiting to close', tone: 'draft' },
  closed: { label: 'Closed', tone: 'neutral' },
}

const MOVEMENT: Record<NonNullable<LeagueMember['movement']>, { label: string; icon: string; className: string }> = {
  up: { label: 'Moved up', icon: 'arrow_upward', className: 'text-forest' },
  down: { label: 'Moved down', icon: 'arrow_downward', className: 'text-terracotta' },
  stayed: { label: 'Stayed', icon: 'arrow_forward', className: 'text-stone' },
}

function GroupTable({
  group,
  members,
  number,
  editable,
  busy,
  onAdjust,
  onRemove,
  onRestore,
}: {
  group: LeagueGroup
  members: LeagueMember[]
  number: number
  editable: boolean
  busy: string | null
  onAdjust: (m: LeagueMember) => void
  onRemove: (m: LeagueMember) => void
  onRestore: (m: LeagueMember) => void
}) {
  const closed = group.status === 'closed'
  const badge = STATUS_BADGE[group.status]
  const title = `${tierName(group.tier)} · group ${number}`
  return (
    <section aria-label={title} className="overflow-hidden rounded-lg border border-line bg-surface shadow-e1">
      <div className="flex flex-wrap items-center gap-x-3 gap-y-1 border-b border-line px-4 py-3 sm:px-5">
        <h2 className="flex items-center gap-2 text-base font-semibold text-coffee">
          <Icon name="emoji_events" className="text-xl text-terracotta" />
          {title}
        </h2>
        <Badge tone={badge.tone} dot>
          {badge.label}
        </Badge>
        <span className="text-xs text-stone">
          {plural(group.members.length, 'member')}
          {!closed && ` · top ${group.promote_count} up, bottom ${group.demote_count} down`}
        </span>
        {group.status === 'ended' && (
          <span className="w-full text-xs text-stone">
            Closes when one of its members next opens the app. Until then this is the live ranking.
          </span>
        )}
      </div>
      <div className="overflow-x-auto">
        <table className="w-full min-w-[44rem] text-sm">
          <thead className="bg-canvas">
            <tr>
              <th scope="col" className={cx(TH, 'w-16 pl-4 sm:pl-5')}>
                Rank
              </th>
              <th scope="col" className={TH}>
                Learner
              </th>
              <th scope="col" className={cx(TH, 'text-right')}>
                XP
              </th>
              {closed ? (
                <>
                  <th scope="col" className={TH}>
                    Result
                  </th>
                  <th scope="col" className={cx(TH, 'pr-4 text-right sm:pr-5')}>
                    Amole
                  </th>
                </>
              ) : (
                <>
                  <th scope="col" className={TH}>
                    Last XP
                  </th>
                  <th scope="col" className={cx(TH, 'pr-4 text-right sm:pr-5')}>
                    {editable ? <span className="sr-only">Actions</span> : null}
                  </th>
                </>
              )}
            </tr>
          </thead>
          <tbody className="divide-y divide-line">
            {members.map((m) => (
              <MemberRow
                key={m.member_id}
                group={group}
                member={m}
                editable={editable}
                busy={busy === m.member_id}
                onAdjust={() => onAdjust(m)}
                onRemove={() => onRemove(m)}
                onRestore={() => onRestore(m)}
              />
            ))}
          </tbody>
        </table>
      </div>
    </section>
  )
}

function MemberRow({
  group,
  member: m,
  editable,
  busy,
  onAdjust,
  onRemove,
  onRestore,
}: {
  group: LeagueGroup
  member: LeagueMember
  editable: boolean
  busy: boolean
  onAdjust: () => void
  onRemove: () => void
  onRestore: () => void
}) {
  const closed = group.status === 'closed'
  const zone = closed ? null : zoneOf(group, m)
  const out = m.removed || m.hidden
  const name = m.first_name ?? m.shown_name
  return (
    <tr className={cx('hover:bg-canvas', out && 'bg-canvas/60 text-stone')} aria-label={name}>
      <td
        className={cx(
          TD,
          'tnum border-l-4 pl-3 font-bold sm:pl-4',
          zone === 'up' ? 'border-l-forest text-forest' : zone === 'down' ? 'border-l-terracotta text-terracotta' : 'border-l-transparent',
        )}
      >
        {m.rank ?? '—'}
      </td>
      <td className={TD}>
        <span className="flex items-center gap-2.5">
          <Avatar name={name} className={cx('size-8 text-[0.6875rem]', out && 'bg-stone')} />
          <span className="min-w-0">
            <span className="flex flex-wrap items-center gap-1.5">
              <span className={cx('font-semibold', out ? 'text-coffee-soft' : 'text-coffee')}>{name}</span>
              {m.first_name === null && <span className="text-xs text-stone">(shown as {m.shown_name})</span>}
              {m.removed && (
                <Badge tone="draft" title={m.removed_reason ?? undefined}>
                  Removed
                </Badge>
              )}
              {m.hidden && !m.removed && <Badge title="Switched “Show me in leagues” off">Hidden</Badge>}
            </span>
            <span className="block text-xs break-all text-stone">{m.email ?? 'No email'}</span>
            {m.removed && m.removed_reason && <span className="block text-xs text-terracotta">Reason: {m.removed_reason}</span>}
          </span>
        </span>
      </td>
      <td className={cx(TD, 'tnum text-right whitespace-nowrap')}>
        <span className={cx('font-semibold', out ? 'text-coffee-soft' : 'text-coffee')}>{count(m.xp)}</span>
        {m.xp_adjustment !== 0 && (
          <span className="block text-xs text-terracotta" title={m.xp_adjustment_reason ?? undefined}>
            {count(m.earned_xp)} earned {signed(m.xp_adjustment)}
          </span>
        )}
      </td>
      {closed ? (
        <>
          <td className={cx(TD, 'whitespace-nowrap')}>
            {m.movement ? (
              <span className={cx('inline-flex items-center gap-1 font-medium', MOVEMENT[m.movement].className)}>
                <Icon name={MOVEMENT[m.movement].icon} className="text-base" />
                {MOVEMENT[m.movement].label}
                {m.tier_after && m.movement !== 'stayed' && <span className="text-stone">to {tierName(m.tier_after)}</span>}
              </span>
            ) : (
              <span className="text-stone">—</span>
            )}
          </td>
          <td className={cx(TD, 'tnum pr-4 text-right sm:pr-5')}>{m.reward_amole ? count(m.reward_amole) : '—'}</td>
        </>
      ) : (
        <>
          <td className={cx(TD, 'whitespace-nowrap text-coffee-soft')}>{lastSeen(m.last_xp_at)}</td>
          <td className={cx(TD, 'pr-4 text-right whitespace-nowrap sm:pr-5')}>
            {editable && (
              <span className="inline-flex gap-1">
                {!m.removed && (
                  <Button size="sm" variant="ghost" disabled={busy} onClick={onAdjust} aria-label={`Adjust XP for ${name}`}>
                    <Icon name="tune" className="text-base" />
                    Adjust XP
                  </Button>
                )}
                {m.removed ? (
                  <Button size="sm" variant="ghost" disabled={busy} onClick={onRestore} aria-label={`Restore ${name}`}>
                    <Icon name="undo" className="text-base" />
                    Restore
                  </Button>
                ) : (
                  <Button size="sm" variant="danger-ghost" disabled={busy} onClick={onRemove} aria-label={`Remove ${name}`}>
                    <Icon name="person_remove" className="text-base" />
                    Remove
                  </Button>
                )}
              </span>
            )}
          </td>
        </>
      )}
    </tr>
  )
}

/** The rank `xp` would give the member, against the others as they are:
 * more XP first, then whoever reached their total first. */
function rankWith(group: LeagueGroup, member: LeagueMember, xp: number): number {
  const time = (iso: string | null) => (iso ? new Date(iso).getTime() : Number.POSITIVE_INFINITY)
  const ahead = group.members.filter(
    (o) =>
      o.member_id !== member.member_id &&
      o.rank !== null &&
      (o.xp > xp || (o.xp === xp && time(o.last_xp_at) < time(member.last_xp_at))),
  )
  return ahead.length + 1
}

function AdjustDialog({
  group,
  member,
  onClose,
  onSaved,
}: {
  group: LeagueGroup
  member: LeagueMember
  onClose: () => void
  onSaved: () => void
}) {
  const { api } = useSession()
  const [value, setValue] = useState(member.xp_adjustment ? String(member.xp_adjustment) : '')
  const [reason, setReason] = useState(member.xp_adjustment_reason ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const adjustment = Number(value || 0)
  const valid = Number.isInteger(adjustment)
  const total = Math.max(0, member.earned_xp + (valid ? adjustment : 0))
  const name = member.first_name ?? member.shown_name

  async function save() {
    setBusy(true)
    setError(null)
    try {
      await api.put(`${leagueMember(member.member_id)}/xp`, { adjustment, reason: reason.trim() || null })
      onSaved()
    } catch (e) {
      setError(messageOf(e))
      setBusy(false)
    }
  }

  return (
    <Modal title={`Adjust ${name}’s XP this week`} onClose={() => !busy && onClose()}>
      <p className="mt-2 text-sm leading-6 text-coffee-soft">
        Added to what they earned this week, for their league only. It replaces any earlier adjustment; 0 clears it. The app
        shows the new total the next time it is opened.
      </p>
      <form
        className="mt-4 flex flex-col gap-4"
        onSubmit={(e) => {
          e.preventDefault()
          void save()
        }}
      >
        <label className="flex flex-col gap-1.5">
          <span className="text-sm font-semibold text-coffee">Adjustment</span>
          <Input
            type="number"
            inputMode="numeric"
            step={1}
            value={value}
            onChange={(e) => setValue(e.target.value)}
            placeholder="e.g. 40 or -25"
            autoFocus
          />
        </label>
        <dl className="grid grid-cols-3 gap-2 rounded bg-inset px-3 py-2 text-sm">
          <div>
            <dt className="text-xs text-stone">Earned</dt>
            <dd className="tnum font-semibold text-coffee">{count(member.earned_xp)}</dd>
          </div>
          <div>
            <dt className="text-xs text-stone">New total</dt>
            <dd className="tnum font-semibold text-coffee">{count(total)}</dd>
          </div>
          <div>
            <dt className="text-xs text-stone">Rank</dt>
            <dd className="tnum font-semibold text-coffee">
              {member.rank ?? '—'} → {rankWith(group, member, total)}
            </dd>
          </div>
        </dl>
        <div className="flex flex-col gap-1.5">
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-semibold text-coffee">Reason</span>
            <Input
              value={reason}
              maxLength={200}
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g. Lessons lost while offline"
            />
          </label>
          <span className="text-xs text-stone">Kept in the activity log. Needed unless the adjustment is 0.</span>
        </div>
        {error && (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        )}
        <div className="mt-2 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button className="justify-center" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant="primary" className="justify-center" disabled={busy || !valid}>
            Save adjustment
          </Button>
        </div>
      </form>
    </Modal>
  )
}

function RemoveDialog({ member, onClose, onSaved }: { member: LeagueMember; onClose: () => void; onSaved: () => void }) {
  const { api } = useSession()
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const name = member.first_name ?? member.shown_name

  async function save() {
    setBusy(true)
    setError(null)
    try {
      await api.post(`${leagueMember(member.member_id)}/remove`, { reason: reason.trim() })
      onSaved()
    } catch (e) {
      setError(messageOf(e))
      setBusy(false)
    }
  }

  return (
    <Modal title={`Remove ${name} from this week’s league?`} onClose={() => !busy && onClose()}>
      <ul className="mt-3 flex list-disc flex-col gap-1 pl-5 text-sm leading-6 text-coffee-soft">
        <li>Other learners stop seeing them in the group, and the places behind them move up.</li>
        <li>They get no place, move or Amole when the week closes. Their tier stays the same.</li>
        <li>Their app shows “Earn XP this week to join” until the week ends. Next week they join as usual.</li>
      </ul>
      <form
        className="mt-4 flex flex-col gap-4"
        onSubmit={(e) => {
          e.preventDefault()
          void save()
        }}
      >
        <div className="flex flex-col gap-1.5">
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-semibold text-coffee">Reason</span>
            <Input
              value={reason}
              maxLength={200}
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g. XP from repeated lessons in seconds"
              autoFocus
            />
          </label>
          <span className="text-xs text-stone">Kept in the activity log. You can restore them this week.</span>
        </div>
        {error && (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        )}
        <div className="mt-2 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button className="justify-center" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" variant="danger" className="justify-center" disabled={busy || reason.trim().length < 3}>
            Remove from this week
          </Button>
        </div>
      </form>
    </Modal>
  )
}
