import { createContext, useContext } from 'react'

import type { LevelKey } from './levels'

export interface NodeRef {
  level: LevelKey
  id: string
  title: string
}

export interface TreeActions {
  /** True while a write is in flight; every action button is disabled. */
  busy: boolean
  /** Runs a write, then reloads the tree from the server. Resolves to
   * whether the write succeeded; a failure is shown in the error banner. */
  run: (write: () => Promise<unknown>) => Promise<boolean>
  /** Starts a delete; the server's answer decides the dialog. */
  requestDelete: (node: NodeRef) => void
}

export const TreeActionsContext = createContext<TreeActions | null>(null)

export function useTreeActions(): TreeActions {
  const value = useContext(TreeActionsContext)
  if (!value) throw new Error('useTreeActions must be used inside a course tree')
  return value
}
