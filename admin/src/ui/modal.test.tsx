import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { Modal } from './Modal'

describe('a dialog’s width', () => {
  it('is the default one unless the caller gives its own', () => {
    const { unmount } = render(
      <Modal title="Plain" onClose={() => {}}>
        x
      </Modal>,
    )
    expect(screen.getByRole('dialog').className).toContain('sm:max-w-md')
    unmount()

    render(
      <Modal title="Wide" onClose={() => {}} className="sm:max-w-4xl">
        x
      </Modal>,
    )
    const wide = screen.getByRole('dialog').className
    expect(wide).toContain('sm:max-w-4xl')
    expect(wide).not.toContain('sm:max-w-md')
  })
})
