import type { ReactNode } from 'react'

import { cx } from './cx'

export type BadgeTone = 'published' | 'draft' | 'neutral' | 'forest'

const TONES: Record<BadgeTone, string> = {
  published: 'bg-forest-tint text-forest border-forest-line',
  draft: 'bg-terracotta-tint text-terracotta border-terracotta-line',
  neutral: 'bg-slate-100 text-slate-500 border-line',
  forest: 'bg-inset text-coffee border-line-strong/60',
}

const DOTS: Record<BadgeTone, string> = {
  published: 'bg-forest',
  draft: 'bg-terracotta',
  neutral: 'bg-slate-400',
  forest: 'bg-stone',
}

interface Props {
  tone?: BadgeTone
  /** Adds the 6px leading dot the design uses for status pills. */
  dot?: boolean
  title?: string
  className?: string
  children: ReactNode
}

/** A status pill: fully rounded so it never reads as a form control. */
export function Badge({ tone = 'neutral', dot, title, className, children }: Props) {
  return (
    <span
      title={title}
      className={cx(
        'inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5',
        'text-[0.6875rem] leading-3.5 font-bold tracking-[0.04em] uppercase',
        TONES[tone],
        className,
      )}
    >
      {dot && <span aria-hidden="true" className={cx('size-1.5 rounded-full', DOTS[tone])} />}
      {children}
    </span>
  )
}
