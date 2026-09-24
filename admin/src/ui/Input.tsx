import type { InputHTMLAttributes, Ref } from 'react'

import { cx } from './cx'

/** Shared with anything that has to look like a field without being one. */
export const FIELD_CLASS =
  'h-11 sm:h-10 w-full min-w-0 rounded border border-line bg-surface px-3 text-sm text-coffee ' +
  'placeholder:text-stone-soft transition-[border-color,box-shadow] ' +
  'focus:border-forest focus:ring-3 focus:ring-forest/15 focus:outline-none'

export function Input({ className, ref, ...rest }: InputHTMLAttributes<HTMLInputElement> & { ref?: Ref<HTMLInputElement> }) {
  return <input ref={ref} className={cx(FIELD_CLASS, className)} {...rest} />
}
