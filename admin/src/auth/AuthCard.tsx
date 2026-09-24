import type { ReactNode } from 'react'

import { Icon } from '../ui/Icon'

/** The frame for the screens seen before the admin is let in: the brand on
 * a parchment canvas, and one white card. */
export function AuthCard({ children }: { children: ReactNode }) {
  return (
    <main className="relative grid min-h-screen place-items-center overflow-hidden px-4 py-10">
      {/* Soft acacia and terracotta glows; decoration only. */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -top-40 -left-32 size-[28rem] rounded-full bg-forest/8 blur-3xl"
      />
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -right-24 -bottom-40 size-[26rem] rounded-full bg-terracotta/8 blur-3xl"
      />
      <div className="relative w-full max-w-md">
        <div className="mb-6 flex items-center justify-center gap-3">
          <span className="grid size-11 place-items-center rounded-md bg-forest text-white shadow-e2">
            <Icon name="local_cafe" className="text-2xl" filled />
          </span>
          <span>
            <span className="block text-lg leading-6 font-extrabold tracking-[-0.015em] text-coffee">Buna Studio</span>
            <span className="block text-xs text-stone">Curriculum &amp; Audio Admin</span>
          </span>
        </div>
        <div className="rounded-lg border border-line bg-surface p-6 shadow-e2 sm:p-8">{children}</div>
      </div>
    </main>
  )
}
