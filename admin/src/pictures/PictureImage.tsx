import { useState } from 'react'

import { playableUrl } from '../exercises/model'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'

/** One picture of a picture question, filling its square box. With no
 * address, or one that fails to load, its alt text shows in its place --
 * which is also what a learner who can't see it gets. */
export function PictureImage({ url, alt, className }: { url: string; alt: string; className?: string }) {
  // Remembered per address, so choosing a new picture tries again.
  const [failed, setFailed] = useState<string | null>(null)
  const src = url.trim()

  if (!src || failed === src) {
    return (
      <span
        className={cx(
          'flex flex-col items-center justify-center gap-1 overflow-hidden rounded-md border-2 border-dashed border-line-strong bg-inset p-1.5 text-center text-xs text-stone',
          className,
        )}
      >
        <Icon name={src ? 'broken_image' : 'image'} className="text-xl" />
        <span className="line-clamp-3 break-words">{alt.trim() || (src ? 'Picture didn’t load' : 'No picture')}</span>
      </span>
    )
  }
  return (
    <img
      src={playableUrl(src)}
      alt={alt}
      onError={() => setFailed(src)}
      className={cx('rounded-md bg-surface object-contain', className)}
    />
  )
}
