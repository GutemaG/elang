import { createContext, useContext, type ReactNode } from 'react'

import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import type { Slot } from './model'

/** The server's error, placed at the part of the form it names. */
export const SlotErrors = createContext<Partial<Record<Slot, string>>>({})

export function FieldError({ slot, className }: { slot: Slot; className?: string }) {
  const message = useContext(SlotErrors)[slot]
  if (!message) return null
  return (
    <p role="alert" className={cx('mt-1.5 flex items-start gap-1.5 text-sm text-danger', className)}>
      <Icon name="error" className="mt-px text-base" />
      <span>{message}</span>
    </p>
  )
}

/** A card holding one part of the form, with a heading and a hint. */
export function Section({
  title,
  hint,
  action,
  children,
}: {
  title: string
  hint?: ReactNode
  action?: ReactNode
  children: ReactNode
}) {
  return (
    <section className="rounded-lg border border-line bg-surface p-4 shadow-e1 sm:p-5">
      <div className="mb-3 flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-base leading-6 font-semibold text-coffee">{title}</h2>
          {hint && <p className="mt-0.5 text-xs leading-5 text-stone">{hint}</p>}
        </div>
        {action}
      </div>
      {children}
    </section>
  )
}

/** Up, down and remove for one row of a list. */
export function RowTools({
  what,
  index,
  count,
  onMove,
  onRemove,
  removeDisabled,
}: {
  /** e.g. "choice 2" -- names every button for screen readers and tests. */
  what: string
  index: number
  count: number
  onMove?: (by: -1 | 1) => void
  onRemove: () => void
  removeDisabled?: boolean
}) {
  return (
    <div className="flex shrink-0 items-center">
      {onMove && (
        <>
          <Button
            size="icon"
            variant="ghost"
            aria-label={`Move ${what} up`}
            title="Move up"
            disabled={index === 0}
            onClick={() => onMove(-1)}
          >
            <Icon name="arrow_upward" className="text-lg" />
          </Button>
          <Button
            size="icon"
            variant="ghost"
            aria-label={`Move ${what} down`}
            title="Move down"
            disabled={index === count - 1}
            onClick={() => onMove(1)}
          >
            <Icon name="arrow_downward" className="text-lg" />
          </Button>
        </>
      )}
      <Button
        size="icon"
        variant="danger-ghost"
        aria-label={`Remove ${what}`}
        title="Remove"
        disabled={removeDisabled}
        onClick={onRemove}
      >
        <Icon name="close" className="text-lg" />
      </Button>
    </div>
  )
}

export function AddRowButton({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <Button size="sm" variant="outline" className="mt-3" onClick={onClick}>
      <Icon name="add" className="text-base" />
      {label}
    </Button>
  )
}

/** A soft note under a list, for what the form can already tell is missing. */
export function Hint({ children }: { children: ReactNode }) {
  return (
    <p className="mt-2 flex items-center gap-1.5 text-sm text-terracotta">
      <Icon name="info" className="text-base" />
      {children}
    </p>
  )
}
