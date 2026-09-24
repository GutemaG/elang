import { useId, type ReactNode } from 'react'

import { cx } from './cx'

/** A dialog over a dimmed page: a bottom sheet on a phone, a centred card
 * from `sm` up. Escape closes it, as does the backdrop. */
export function Modal({
  title,
  onClose,
  children,
  className,
}: {
  title: ReactNode
  onClose: () => void
  children: ReactNode
  className?: string
}) {
  const titleId = useId()
  return (
    <div className="fixed inset-0 z-50 grid place-items-end sm:place-items-center sm:p-4">
      {/* The backdrop: a mouse shortcut only, so it is hidden from screen
          readers and never competes with the dialog's own Close. */}
      <div aria-hidden="true" className="absolute inset-0 bg-[rgb(30_20_18_/_0.45)]" onClick={onClose} />
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onKeyDown={(e) => e.key === 'Escape' && onClose()}
        className={cx(
          'relative max-h-[92vh] w-full overflow-y-auto rounded-t-lg border border-line bg-surface p-6 shadow-e3 sm:max-w-md sm:rounded-lg',
          className,
        )}
      >
        <h2 id={titleId} className="text-lg leading-6 font-semibold break-words text-coffee">
          {title}
        </h2>
        {children}
      </div>
    </div>
  )
}
