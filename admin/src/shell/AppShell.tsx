import { useState, type ReactNode } from 'react'
import { Link, useLocation } from 'react-router-dom'

import { Button } from '../ui/Button'
import { cx } from '../ui/cx'
import { Icon } from '../ui/Icon'

/** The next bolts of unit 002, shown so the tool is honest about what is
 * still missing. Plain text, not controls: none of it works yet. */
const PLANNED = [
  { icon: 'translate', label: 'Vocabulary' },
]

function initialsOf(email: string): string {
  const name = email.split('@')[0] ?? ''
  const parts = name.split(/[._-]+/).filter(Boolean)
  const letters = parts.length > 1 ? `${parts[0]![0]}${parts[1]![0]}` : name.slice(0, 2)
  return letters.toUpperCase() || '?'
}

interface Props {
  email: string | null
  onSignOut: () => void
  children: ReactNode
}

/** The Buna Studio frame: a permanent sidebar from `lg` up, the same panel
 * as a slide-over drawer below it. Rendered once, so there is only ever one
 * Sign out. */
export function AppShell({ email, onSignOut, children }: Props) {
  const [drawerOpen, setDrawerOpen] = useState(false)
  const close = () => setDrawerOpen(false)
  // The course list and every course page are the curriculum.
  const { pathname } = useLocation()
  const onCurriculum = pathname === '/' || pathname.startsWith('/courses/')

  return (
    <div className="min-h-screen lg:flex">
      {/* Mobile top bar: glass-morphic over the parchment canvas. */}
      <header className="sticky top-0 z-30 flex h-14 items-center gap-2 border-b border-line bg-canvas/92 px-4 backdrop-blur-md lg:hidden">
        <Button
          size="icon"
          variant="ghost"
          aria-label={drawerOpen ? 'Close menu' : 'Open menu'}
          aria-expanded={drawerOpen}
          onClick={() => setDrawerOpen((open) => !open)}
        >
          <Icon name={drawerOpen ? 'close' : 'menu'} className="text-xl" />
        </Button>
        <Brand compact />
      </header>

      {drawerOpen && (
        <button
          type="button"
          aria-label="Close menu"
          className="fixed inset-0 z-40 bg-[rgb(30_20_18_/_0.45)] lg:hidden"
          onClick={close}
        />
      )}

      <aside
        className={cx(
          'fixed inset-y-0 left-0 z-50 flex w-[17rem] flex-col border-r border-line bg-canvas',
          'transition-transform duration-200 lg:sticky lg:top-0 lg:z-auto lg:h-screen lg:translate-x-0',
          drawerOpen ? 'translate-x-0 shadow-e3' : '-translate-x-full',
        )}
      >
        <div className="flex items-center justify-between px-5 pt-5 pb-4">
          <Brand />
          <Button size="icon" variant="ghost" className="lg:hidden" aria-label="Close menu" onClick={close}>
            <Icon name="close" className="text-xl" />
          </Button>
        </div>

        <nav className="flex-1 overflow-y-auto px-3 pb-4" aria-label="Sections">
          <p className="px-2 pt-2 pb-2 text-[0.6875rem] font-bold tracking-[0.12em] text-stone uppercase">Workspace</p>
          <Link
            to="/"
            onClick={close}
            aria-current={onCurriculum ? 'page' : undefined}
            className={cx(
              'flex items-center gap-3 rounded border-l-[3px] px-3 py-2.5 text-sm font-semibold transition-colors',
              onCurriculum
                ? 'border-l-forest bg-inset text-forest'
                : 'border-l-transparent text-coffee-soft hover:bg-inset hover:text-coffee',
            )}
          >
            <Icon name="menu_book" className="text-xl" />
            Curriculum
          </Link>

          <p className="px-2 pt-6 pb-2 text-[0.6875rem] font-bold tracking-[0.12em] text-stone uppercase">
            Coming next
          </p>
          {PLANNED.map((item) => (
            <p
              key={item.label}
              className="flex items-center gap-3 border-l-[3px] border-l-transparent px-3 py-2.5 text-sm font-semibold text-stone-soft"
            >
              <Icon name={item.icon} className="text-xl" />
              <span className="flex-1">{item.label}</span>
              <span className="rounded-full border border-line px-2 py-px text-[0.625rem] font-bold tracking-wider uppercase">
                Soon
              </span>
            </p>
          ))}
        </nav>

        <div className="border-t border-line p-3">
          <button
            type="button"
            onClick={onSignOut}
            className="flex w-full items-center gap-3 rounded px-3 py-2.5 text-sm font-semibold text-coffee-soft transition-colors hover:bg-inset hover:text-coffee"
          >
            <Icon name="logout" className="text-xl" />
            Sign out
          </button>
          {email && (
            <div className="mt-2 flex items-center gap-3 rounded-md bg-inset px-3 py-2.5">
              <span
                aria-hidden="true"
                className="grid size-9 shrink-0 place-items-center rounded-full bg-coffee text-xs font-bold text-white"
              >
                {initialsOf(email)}
              </span>
              <span className="min-w-0 truncate text-sm font-semibold text-coffee" title={email}>
                {email}
              </span>
            </div>
          )}
        </div>
      </aside>

      <div className="min-w-0 flex-1">{children}</div>
    </div>
  )
}

function Brand({ compact }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-3">
      <span
        aria-hidden="true"
        className="grid size-9 shrink-0 place-items-center rounded-md bg-forest text-white shadow-e1"
      >
        <Icon name="local_cafe" className="text-xl" filled />
      </span>
      <span className="min-w-0">
        <span className="block text-base leading-5 font-extrabold tracking-[-0.015em] text-coffee">Buna Studio</span>
        {!compact && <span className="block text-xs text-stone">Curriculum &amp; Audio Admin</span>}
      </span>
    </div>
  )
}
