import type { ReactNode } from 'react'

import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import type { Trend } from './report'

export function Panel({
  title,
  description,
  icon,
  actions,
  children,
  className,
  flush,
}: {
  title: string
  description?: ReactNode
  icon?: string
  actions?: ReactNode
  children: ReactNode
  className?: string
  /** No padding around the body, for a table or list that runs edge to edge. */
  flush?: boolean
}) {
  return (
    <section className={cx('overflow-hidden rounded-lg border border-line bg-surface shadow-e1', className)}>
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-line px-4 py-4 sm:px-6">
        <div className="min-w-0">
          <h2 className="flex items-center gap-2 text-lg leading-6 font-semibold text-coffee">
            {icon && <Icon name={icon} className="text-xl text-forest" />}
            {title}
          </h2>
          {description && <p className="mt-0.5 text-xs text-stone">{description}</p>}
        </div>
        {actions}
      </div>
      <div className={flush ? undefined : 'p-4 sm:p-6'}>{children}</div>
    </section>
  )
}

export function ErrorBanner({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div
      role="alert"
      className="mt-6 flex flex-wrap items-center gap-3 rounded-md border border-danger-line bg-danger-tint px-4 py-3 text-sm text-danger"
    >
      <Icon name="error" className="text-lg" />
      <span className="flex-1">{message}</span>
      <Button size="sm" onClick={onRetry}>
        Try again
      </Button>
    </div>
  )
}

const TREND_TONES = {
  up: 'text-forest',
  down: 'text-terracotta',
  same: 'text-stone',
}
const TREND_ICONS = { up: 'trending_up', down: 'trending_down', same: 'trending_flat' }

/** A KPI tile with how it moved against the range before. The value and
 * label are separate elements, as in `StatCard`. */
export function TrendCard({
  icon,
  label,
  value,
  trend,
  hint,
}: {
  icon: string
  label: string
  value: string
  trend: Trend | null
  hint: string
}) {
  return (
    <div className="rounded-md border border-line bg-surface p-4 shadow-e1" title={hint}>
      <div className="flex items-start justify-between gap-2">
        <dt className="text-xs font-semibold tracking-[0.02em] text-stone">{label}</dt>
        <span className="grid size-8 place-items-center rounded bg-forest-tint text-forest">
          <Icon name={icon} className="text-lg" />
        </span>
      </div>
      <dd className="tnum mt-1 text-3xl leading-9 font-bold tracking-[-0.02em] text-coffee">{value}</dd>
      <dd className={cx('mt-1 flex items-center gap-1 text-xs font-semibold', trend ? TREND_TONES[trend.direction] : 'text-stone')}>
        {trend ? (
          <>
            <Icon name={TREND_ICONS[trend.direction]} className="text-base" />
            {trend.text}
            <span className="font-normal text-stone">vs previous</span>
          </>
        ) : (
          <span className="font-normal">Nothing to compare yet</span>
        )}
      </dd>
    </div>
  )
}

export interface Bar {
  key: string
  /** Under the bar; thinned out when there are many. */
  label: string
  /** The full name, for the tooltip. */
  name: string
  value: number
  display: string
  partial?: boolean
}

/** Vertical bars from plain boxes, so labels stay crisp at any width. The
 * numbers are in the table beside it, so to a screen reader this is only
 * its summary. */
export function BarChart({ bars, summary, tone = 'forest' }: { bars: Bar[]; summary: string; tone?: 'forest' | 'coffee' | 'terracotta' }) {
  const max = Math.max(1, ...bars.map((b) => b.value))
  const every = Math.ceil(bars.length / 8)
  const fill = { forest: 'bg-forest', coffee: 'bg-coffee-soft', terracotta: 'bg-terracotta' }[tone]
  return (
    <figure role="img" aria-label={summary}>
      <div className="relative flex h-44 items-end gap-[3px] border-b border-line-strong sm:gap-1.5">
        <span className="tnum pointer-events-none absolute top-0 left-0 text-[0.625rem] text-stone">{max.toLocaleString('en-GB')}</span>
        <span aria-hidden="true" className="pointer-events-none absolute inset-x-0 top-1/2 border-t border-dashed border-line" />
        {bars.map((bar) => (
          <div
            key={bar.key}
            title={`${bar.name}: ${bar.display}${bar.partial ? ' (so far)' : ''}`}
            className="group relative flex h-full min-w-0 flex-1 items-end"
          >
            <div
              className={cx(
                'w-full rounded-t-sm transition-opacity group-hover:opacity-80',
                fill,
                bar.partial && 'opacity-45',
                bar.value === 0 && 'opacity-0',
              )}
              style={{ height: `${(bar.value / max) * 100}%`, minHeight: bar.value > 0 ? 2 : 0 }}
            />
          </div>
        ))}
      </div>
      <div aria-hidden="true" className="mt-1.5 flex gap-[3px] sm:gap-1.5">
        {bars.map((bar, i) => (
          <span key={bar.key} className="min-w-0 flex-1 truncate text-center text-[0.625rem] text-stone">
            {i % every === 0 || i === bars.length - 1 ? bar.label : ''}
          </span>
        ))}
      </div>
    </figure>
  )
}

/** A thin bar showing `done` out of `total`. */
export function Progress({ done, total, label }: { done: number; total: number; label: string }) {
  const share = total ? Math.min(1, done / total) : 0
  return (
    <div
      role="progressbar"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={total}
      aria-valuenow={done}
      className="h-2 w-full overflow-hidden rounded-full bg-inset"
    >
      <div className="h-full rounded-full bg-forest" style={{ width: `${share * 100}%` }} />
    </div>
  )
}

export function Avatar({ name, className }: { name: string; className?: string }) {
  const letters =
    name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => Array.from(part)[0])
      .join('')
      .toUpperCase() || '?'
  return (
    <span
      aria-hidden="true"
      className={cx('grid shrink-0 place-items-center rounded-full bg-coffee font-bold text-white', className ?? 'size-9 text-xs')}
    >
      {letters}
    </span>
  )
}
