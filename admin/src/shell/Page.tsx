import type { ReactNode } from 'react'

import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'

interface HeaderProps {
  eyebrow?: ReactNode
  title: string
  description?: ReactNode
  actions?: ReactNode
}

export function PageHeader({ eyebrow, title, description, actions }: HeaderProps) {
  return (
    <header className="flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        {eyebrow && <p className="text-xs font-bold tracking-[0.12em] text-forest uppercase">{eyebrow}</p>}
        <h1 className="mt-1 text-[1.75rem] leading-9 font-bold tracking-[-0.02em] text-coffee lg:text-4xl lg:leading-11">
          {title}
        </h1>
        {description && <p className="mt-2 max-w-2xl text-sm leading-6 text-stone">{description}</p>}
      </div>
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </header>
  )
}

export function StatRow({ children, className }: { children: ReactNode; className?: string }) {
  return <dl className={cx('mt-6 grid grid-cols-2 gap-3 lg:grid-cols-4', className)}>{children}</dl>
}

type StatTone = 'coffee' | 'forest' | 'terracotta'

const VALUE_TONES: Record<StatTone, string> = {
  coffee: 'text-coffee',
  forest: 'text-forest',
  terracotta: 'text-terracotta',
}

const ICON_TONES: Record<StatTone, string> = {
  coffee: 'bg-inset text-coffee-soft',
  forest: 'bg-forest-tint text-forest',
  terracotta: 'bg-terracotta-tint text-terracotta',
}

/** A KPI tile. The number and its label are separate elements, so "2" and
 * "Sections" never read as one run of text such as "2 sections". */
export function StatCard({
  icon,
  label,
  value,
  tone = 'coffee',
}: {
  icon: string
  label: string
  value: number
  tone?: StatTone
}) {
  return (
    <div className="rounded-md border border-line bg-surface p-4 shadow-e1">
      <div className="flex items-start justify-between gap-2">
        <dt className="text-xs font-semibold tracking-[0.02em] text-stone">{label}</dt>
        <span className={cx('grid size-8 place-items-center rounded', ICON_TONES[tone])}>
          <Icon name={icon} className="text-lg" />
        </span>
      </div>
      <dd className={cx('tnum mt-1 text-3xl leading-9 font-bold tracking-[-0.02em]', VALUE_TONES[tone])}>{value}</dd>
    </div>
  )
}
