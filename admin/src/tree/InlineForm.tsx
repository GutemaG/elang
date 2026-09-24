import { useState, type FormEvent, type KeyboardEvent } from 'react'

import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'
import { Input } from '../ui/Input'

export interface FormValues {
  title: string
  subtitle: string
}

interface Props {
  /** Accessible name of the form, e.g. "Rename section". */
  label: string
  initial?: Partial<FormValues>
  withSubtitle?: boolean
  submitLabel: string
  disabled?: boolean
  className?: string
  /** Resolves to true when saved; the form then closes. */
  onSubmit: (values: FormValues) => Promise<boolean>
  onCancel: () => void
}

/** Title (and, for sections, subtitle) fields with Save and Cancel. Used
 * for both renaming and adding. */
export function InlineForm({ label, initial, withSubtitle, submitLabel, disabled, className, onSubmit, onCancel }: Props) {
  const [title, setTitle] = useState(initial?.title ?? '')
  const [subtitle, setSubtitle] = useState(initial?.subtitle ?? '')
  const blank = title.trim() === ''

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (blank) return
    if (await onSubmit({ title: title.trim(), subtitle: subtitle.trim() })) onCancel()
  }

  const escape = (e: KeyboardEvent) => e.key === 'Escape' && onCancel()

  return (
    <form
      aria-label={label}
      onSubmit={(e) => void submit(e)}
      className={cx('flex min-w-0 flex-1 flex-wrap items-center gap-2', className)}
    >
      <Input
        aria-label="Title"
        placeholder="Title"
        value={title}
        autoFocus
        className="flex-[2_1_12rem] sm:w-auto"
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={escape}
      />
      {withSubtitle && (
        <Input
          aria-label="Subtitle"
          placeholder="Subtitle (optional)"
          value={subtitle}
          className="flex-[2_1_12rem] sm:w-auto"
          onChange={(e) => setSubtitle(e.target.value)}
          onKeyDown={escape}
        />
      )}
      <div className="flex gap-2">
        <Button type="submit" variant="primary" disabled={disabled || blank}>
          <Icon name="check" className="text-lg" />
          {submitLabel}
        </Button>
        <Button variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
      </div>
    </form>
  )
}
