import { useState, type FormEvent } from 'react'

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
  /** Resolves to true when saved; the form then closes. */
  onSubmit: (values: FormValues) => Promise<boolean>
  onCancel: () => void
}

/** Title (and, for sections, subtitle) fields with Save and Cancel. Used
 * for both renaming and adding. */
export function InlineForm({ label, initial, withSubtitle, submitLabel, disabled, onSubmit, onCancel }: Props) {
  const [title, setTitle] = useState(initial?.title ?? '')
  const [subtitle, setSubtitle] = useState(initial?.subtitle ?? '')
  const blank = title.trim() === ''

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (blank) return
    if (await onSubmit({ title: title.trim(), subtitle: subtitle.trim() })) onCancel()
  }

  return (
    <form className="inline-form" aria-label={label} onSubmit={(e) => void submit(e)}>
      <input
        aria-label="Title"
        placeholder="Title"
        value={title}
        autoFocus
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={(e) => e.key === 'Escape' && onCancel()}
      />
      {withSubtitle && (
        <input
          aria-label="Subtitle"
          placeholder="Subtitle (optional)"
          value={subtitle}
          onChange={(e) => setSubtitle(e.target.value)}
          onKeyDown={(e) => e.key === 'Escape' && onCancel()}
        />
      )}
      <button type="submit" className="primary" disabled={disabled || blank}>
        {submitLabel}
      </button>
      <button type="button" onClick={onCancel}>
        Cancel
      </button>
    </form>
  )
}
