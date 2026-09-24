// The three editable levels of a course and their admin API routes
// (backend/app/infrastructure/api/admin_routers.py).

export type LevelKey = 'section' | 'skill' | 'lesson'

interface Level {
  /** Singular, for messages: "Delete skill …". */
  name: string
  /** Route segment of this level: `/sections/{id}`. */
  segment: string
  /** Route segment of its parent: `/courses/{id}/sections`. */
  parentSegment: string
  /** The level added beneath it, if any from this screen. */
  child: LevelKey | null
  hasSubtitle: boolean
}

export const LEVELS: Record<LevelKey, Level> = {
  section: { name: 'section', segment: 'sections', parentSegment: 'courses', child: 'skill', hasSubtitle: true },
  skill: { name: 'skill', segment: 'skills', parentSegment: 'sections', child: 'lesson', hasSubtitle: false },
  lesson: { name: 'lesson', segment: 'lessons', parentSegment: 'skills', child: null, hasSubtitle: false },
}

const ADMIN = '/api/v1/admin'

export const routes = {
  node: (level: LevelKey, id: string) => `${ADMIN}/${LEVELS[level].segment}/${id}`,
  create: (level: LevelKey, parentId: string) =>
    `${ADMIN}/${LEVELS[level].parentSegment}/${parentId}/${LEVELS[level].segment}`,
  order: (level: LevelKey, parentId: string) =>
    `${ADMIN}/${LEVELS[level].parentSegment}/${parentId}/${LEVELS[level].segment}/order`,
  course: (id: string) => `${ADMIN}/courses/${id}`,
  tree: (id: string) => `${ADMIN}/courses/${id}/tree`,
  courses: `${ADMIN}/courses`,
  // Exercises (bolt 038): a lesson's list, one exercise, and their order.
  exercises: (lessonId: string) => `${ADMIN}/lessons/${lessonId}/exercises`,
  exercise: (id: string) => `${ADMIN}/exercises/${id}`,
  exerciseOrder: (lessonId: string) => `${ADMIN}/lessons/${lessonId}/exercises/order`,
  // Audio (bolt 039): an upload link for a clip, and a check of a pasted link.
  audioUploads: `${ADMIN}/audio/uploads`,
  audioLinks: `${ADMIN}/audio/links`,
}

/** `ids` with the item at `index` swapped with its neighbour, or null when
 * it is already at that end. */
export function moved(ids: readonly string[], index: number, by: -1 | 1): string[] | null {
  const target = index + by
  if (index < 0 || index >= ids.length || target < 0 || target >= ids.length) return null
  const next = [...ids]
  ;[next[index], next[target]] = [next[target]!, next[index]!]
  return next
}
