// What a course page had open, and how far down it was scrolled, kept for
// the tab (bolt 055). The page is left for an exercise and come back to by
// the browser's Back button, the breadcrumb or "Back to lesson"; each way
// finds it as it was. sessionStorage, like the sign-in: it goes with the tab.

import type { AdminCourseTree } from '../types'

const openKey = (courseId: string) => `buna_admin.tree_open.${courseId}`
const scrollKey = (courseId: string) => `buna_admin.tree_scroll.${courseId}`

/** The ids of the sections, skills and lessons left open. */
export function readOpen(courseId: string): Set<string> {
  try {
    const stored: unknown = JSON.parse(sessionStorage.getItem(openKey(courseId)) ?? '[]')
    return new Set(Array.isArray(stored) ? stored.filter((id): id is string => typeof id === 'string') : [])
  } catch {
    return new Set()
  }
}

export function writeOpen(courseId: string, open: ReadonlySet<string>): void {
  try {
    sessionStorage.setItem(openKey(courseId), JSON.stringify([...open]))
  } catch {
    // Storage full or blocked: the page still works, it just forgets.
  }
}

export function readScroll(courseId: string): number | null {
  try {
    const y = Number(sessionStorage.getItem(scrollKey(courseId)))
    return Number.isFinite(y) && y > 0 ? y : null
  } catch {
    return null
  }
}

export function writeScroll(courseId: string, y: number): void {
  try {
    sessionStorage.setItem(scrollKey(courseId), String(Math.round(y)))
  } catch {
    // As above.
  }
}

/** The section, skill and lesson holding `lessonId`, outermost first, or
 * nothing when the course has no such lesson. */
export function pathTo(tree: AdminCourseTree, lessonId: string): string[] {
  for (const section of tree.sections) {
    for (const skill of section.skills) {
      if (skill.lessons.some((l) => l.id === lessonId)) return [section.id, skill.id, lessonId]
    }
  }
  return []
}
