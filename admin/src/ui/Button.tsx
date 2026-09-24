import type { ButtonHTMLAttributes } from 'react'

import { cx } from './cx'

export type ButtonVariant = 'primary' | 'coffee' | 'outline' | 'ghost' | 'danger' | 'danger-ghost'
export type ButtonSize = 'sm' | 'md' | 'icon'

const VARIANTS: Record<ButtonVariant, string> = {
  primary: 'bg-forest text-white border-transparent hover:bg-forest-hover shadow-e1',
  coffee: 'bg-coffee text-white border-transparent hover:bg-coffee-soft shadow-e1',
  outline: 'bg-surface text-coffee border-line hover:bg-inset',
  ghost: 'bg-transparent text-coffee-soft border-transparent hover:bg-inset hover:text-coffee',
  danger: 'bg-danger text-white border-transparent hover:bg-danger/90 shadow-e1',
  'danger-ghost': 'bg-transparent text-danger border-transparent hover:bg-danger-tint',
}

// 44px tall on touch viewports, per the design's tap-target rule.
const SIZES: Record<ButtonSize, string> = {
  sm: 'h-11 sm:h-8 px-3 text-[0.8125rem] gap-1.5',
  md: 'h-11 sm:h-10 px-4 text-sm gap-2',
  icon: 'h-11 w-11 sm:h-8 sm:w-8 justify-center',
}

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant
  size?: ButtonSize
}

/** Every button in the admin. Kept as one component so the focus ring, the
 * disabled treatment and the tap targets stay identical everywhere. */
export function Button({ variant = 'outline', size = 'md', className, type = 'button', ...rest }: Props) {
  return (
    <button
      type={type}
      className={cx(
        'inline-flex shrink-0 items-center rounded border font-semibold tracking-[0.01em] transition-colors',
        'disabled:pointer-events-none disabled:opacity-45',
        VARIANTS[variant],
        SIZES[size],
        className,
      )}
      {...rest}
    />
  )
}
