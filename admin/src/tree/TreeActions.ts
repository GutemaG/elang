import { createContext, useContext } from 'react'

import type { LevelKey, OrderKind } from './levels'

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
  /** A list has a new order that is not saved yet. Other edits wait, so a
   * reload cannot throw it away (bolt 055). */
  ordering: boolean
  /** Records a list's new order, unsaved, by the id of what holds it. */
  reorder: (kind: OrderKind, parentId: string, ids: string[]) => void
  /** Whether a section, skill or lesson is open; kept for the tab. */
  isOpen: (id: string) => boolean
  setOpen: (id: string, open: boolean) => void
}

/** Why the edit buttons are off while a new order waits. */
export const SAVE_ORDER_FIRST = 'Save or discard the new order first'

export const TreeActionsContext = createContext<TreeActions | null>(null)

export function useTreeActions(): TreeActions {
  const value = useContext(TreeActionsContext)
  if (!value) throw new Error('useTreeActions must be used inside a course tree')
  return value
}
