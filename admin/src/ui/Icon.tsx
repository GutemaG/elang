import { cx } from './cx'

/** A Material Symbols glyph. Decorative by default, so screen readers skip
 * it and read the button's own label instead. */
export function Icon({ name, className, filled }: { name: string; className?: string; filled?: boolean }) {
  return (
    <span aria-hidden="true" className={cx('icon', filled && 'icon-filled', className)}>
      {name}
    </span>
  )
}
