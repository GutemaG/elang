import type { ReactNode } from 'react'

import { Button } from '../ui/Button'
import { DEFAULT_SPEED, SPEED_MAX, SPEED_MIN } from './api'

/** A labelled control with a hint, or its error in the hint's place. */
export function Field({
  id,
  label,
  hint,
  error,
  children,
}: {
  id: string
  label: string
  hint?: string
  error?: string | null
  children: ReactNode
}) {
  return (
    <div className="min-w-0">
      <label htmlFor={id} className="mb-1.5 block text-sm font-semibold text-coffee">
        {label}
      </label>
      {children}
      {error ? (
        <p role="alert" className="mt-1 text-xs text-danger">
          {error}
        </p>
      ) : (
        hint && <p className="mt-1 text-xs text-stone">{hint}</p>
      )}
    </div>
  )
}

/** Addis's speed, 0 to 100 (FR-13, FR-17): the Voices page's saved speed,
 * or one clip's in the Generate tab. */
export function SpeedField({
  id,
  value,
  error,
  onChange,
  defaultValue = DEFAULT_SPEED,
  hint = 'Small changes are hard to hear; each take also varies a little.',
}: {
  id: string
  value: number
  error?: string
  onChange: (v: number) => void
  /** Where Reset goes: Addis's 50, or the language's saved speed. */
  defaultValue?: number
  hint?: string
}) {
  return (
    <Field
      id={id}
      label="Speed"
      hint={hint}
      error={error}
    >
      <div className="flex flex-wrap items-center gap-3">
        <span aria-hidden="true" className="text-xs text-stone">
          Slower
        </span>
        <input
          id={id}
          type="range"
          min={SPEED_MIN}
          max={SPEED_MAX}
          step={5}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          className="min-w-[8rem] flex-1 accent-forest"
        />
        <span aria-hidden="true" className="text-xs text-stone">
          Faster
        </span>
        <span className="tnum w-8 text-right text-sm font-semibold text-coffee">{value}</span>
        <Button size="sm" variant="ghost" disabled={value === defaultValue} onClick={() => onChange(defaultValue)}>
          Reset to {defaultValue}
        </Button>
      </div>
    </Field>
  )
}
