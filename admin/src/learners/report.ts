// Wording and arithmetic for the learner pages and the dashboard
// (026-learner-reports). Dates from the server are UTC days (`YYYY-MM-DD`)
// and UTC instants; everything here reads them in UTC, as the server
// counts them, so a week never shifts by a day in another time zone.

import type { AdminBucket, AdminReport, AdminTotals, ReportPeriod } from '../types'
import type { BadgeTone } from '../ui/Badge'

const DAY_MS = 86_400_000

export const PERIODS: { key: ReportPeriod; label: string; noun: string }[] = [
  { key: 'day', label: 'Daily', noun: 'day' },
  { key: 'week', label: 'Weekly', noun: 'week' },
  { key: 'month', label: 'Monthly', noun: 'month' },
]

/** How many days, weeks or months the dashboard shows at once. */
export const PERIOD_COUNT: Record<ReportPeriod, number> = { day: 30, week: 12, month: 12 }

export function parseDay(day: string): Date {
  return new Date(`${day}T00:00:00Z`)
}

export function formatDay(date: Date): string {
  return date.toISOString().slice(0, 10)
}

function addDays(day: string, n: number): string {
  return formatDay(new Date(parseDay(day).getTime() + n * DAY_MS))
}

const fmt = (options: Intl.DateTimeFormatOptions) =>
  new Intl.DateTimeFormat('en-GB', { timeZone: 'UTC', ...options })
const DAY_MONTH = fmt({ day: 'numeric', month: 'short' })
const DAY_MONTH_YEAR = fmt({ day: 'numeric', month: 'short', year: 'numeric' })
const MONTH = fmt({ month: 'short' })
const MONTH_YEAR = fmt({ month: 'long', year: 'numeric' })
const WEEKDAY = fmt({ weekday: 'short', day: 'numeric', month: 'short' })

/** The short label under a chart's bar: "2 Oct", "28 Sep" or "Oct". */
export function bucketLabel(bucket: AdminBucket, period: ReportPeriod): string {
  const start = parseDay(bucket.start)
  return period === 'month' ? MONTH.format(start) : DAY_MONTH.format(start)
}

/** The full name of a bucket: "Fri 2 Oct", "Week of 28 Sep 2026", "October 2026". */
export function bucketName(bucket: AdminBucket, period: ReportPeriod): string {
  const start = parseDay(bucket.start)
  if (period === 'month') return MONTH_YEAR.format(start)
  if (period === 'week') return `Week of ${DAY_MONTH_YEAR.format(start)}`
  return WEEKDAY.format(start)
}

/** "1 Sep – 30 Sep 2026". */
export function rangeLabel(start: string, end: string): string {
  return `${DAY_MONTH.format(parseDay(start))} – ${DAY_MONTH_YEAR.format(parseDay(end))}`
}

export function formatDate(iso: string): string {
  return DAY_MONTH_YEAR.format(new Date(iso))
}

/** The last day to ask for to see the range just before or after this one. */
export function shiftedEnd(report: AdminReport, direction: -1 | 1): string {
  if (direction === -1) return addDays(report.start, -1)
  // The day after this range, then as many buckets on again as are shown.
  const length = report.buckets.length
  if (report.period === 'month') {
    const d = parseDay(report.end)
    return formatDay(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + length + 1, 0)))
  }
  const days = report.period === 'week' ? 7 * length : length
  return addDays(report.end, days)
}

export function percent(value: number | null): string {
  return value === null ? '—' : `${Math.round(value * 100)}%`
}

export function count(n: number): string {
  return n.toLocaleString('en-GB')
}

export type Trend = { text: string; direction: 'up' | 'down' | 'same' }

/** This range against the one before: "+25%", "−3 pts" for accuracy, or
 * "New" from nothing. Null when there is nothing to compare. */
export function trend(now: number | null, before: number | null, kind: 'count' | 'rate' = 'count'): Trend | null {
  if (now === null || before === null) return null
  if (kind === 'rate') {
    const points = Math.round((now - before) * 100)
    if (points === 0) return { text: 'No change', direction: 'same' }
    return { text: `${points > 0 ? '+' : '−'}${Math.abs(points)} pts`, direction: points > 0 ? 'up' : 'down' }
  }
  if (now === before) return before === 0 ? null : { text: 'No change', direction: 'same' }
  if (before === 0) return { text: 'New', direction: 'up' }
  const change = Math.round(((now - before) / before) * 100)
  if (change === 0) return { text: 'No change', direction: 'same' }
  return { text: `${change > 0 ? '+' : '−'}${Math.abs(change)}%`, direction: change > 0 ? 'up' : 'down' }
}

/** When a learner last studied, in words: "Today", "Yesterday", "5 days
 * ago", then a date; "Never" before their first lesson. */
export function lastSeen(iso: string | null, now = new Date()): string {
  if (!iso) return 'Never'
  const days = Math.floor((startOfUtcDay(now) - startOfUtcDay(new Date(iso))) / DAY_MS)
  if (days <= 0) return 'Today'
  if (days === 1) return 'Yesterday'
  if (days < 7) return `${days} days ago`
  return formatDate(iso)
}

function startOfUtcDay(d: Date): number {
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate())
}

/** A pill for how recently a learner studied. */
export function activity(iso: string | null, now = new Date()): { label: string; tone: BadgeTone } {
  if (!iso) return { label: 'Not started', tone: 'neutral' }
  const days = Math.floor((startOfUtcDay(now) - startOfUtcDay(new Date(iso))) / DAY_MS)
  if (days <= 0) return { label: 'Active today', tone: 'published' }
  if (days < 7) return { label: 'Active this week', tone: 'forest' }
  return { label: `Away ${days} days`, tone: 'draft' }
}

/** The metrics a report counts, in the order the dashboard shows them. */
export const METRICS: {
  key: keyof AdminTotals
  label: string
  icon: string
  kind: 'count' | 'rate'
  hint: string
}[] = [
  { key: 'active_learners', label: 'Active learners', icon: 'person_check', kind: 'count', hint: 'Finished at least one lesson or practice' },
  { key: 'new_learners', label: 'New learners', icon: 'person_add', kind: 'count', hint: 'Accounts made' },
  { key: 'lessons', label: 'Lessons completed', icon: 'menu_book', kind: 'count', hint: 'Every finish counts, repeats too' },
  { key: 'practice_sessions', label: 'Practice sessions', icon: 'fitness_center', kind: 'count', hint: 'Word reviews finished' },
  { key: 'xp', label: 'XP earned', icon: 'bolt', kind: 'count', hint: 'From lessons and practice' },
  { key: 'skills_completed', label: 'Skills completed', icon: 'workspace_premium', kind: 'count', hint: 'Skills finished for the first time' },
  { key: 'accuracy', label: 'Accuracy', icon: 'percent', kind: 'rate', hint: 'Right answers out of all answers' },
]

export function metricValue(totals: AdminTotals, key: keyof AdminTotals): string {
  const value = totals[key]
  return key === 'accuracy' ? percent(value) : count(value ?? 0)
}

const csvCell = (value: string | number) => {
  const text = String(value)
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
}

/** The report's buckets as CSV, one row each, for a spreadsheet. */
export function reportCsv(report: AdminReport): string {
  const header = ['Start', 'End', ...METRICS.map((m) => m.label), 'Partial']
  const rows = report.buckets.map((b) => [
    b.start,
    b.end,
    ...METRICS.map((m) =>
      m.key === 'accuracy' ? (b.totals.accuracy === null ? '' : Math.round(b.totals.accuracy * 1000) / 10) : b.totals[m.key] ?? 0,
    ),
    b.partial ? 'yes' : 'no',
  ])
  return [header, ...rows].map((row) => row.map(csvCell).join(',')).join('\n') + '\n'
}
