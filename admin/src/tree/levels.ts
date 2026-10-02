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
  // Languages: the list courses pick from, and one language by its code.
  languages: `${ADMIN}/languages`,
  language: (code: string) => `${ADMIN}/languages/${code}`,
  // Learners and reports (026-learner-reports): read-only.
  learners: `${ADMIN}/learners`,
  learner: (id: string) => `${ADMIN}/learners/${id}`,
  reports: `${ADMIN}/reports`,
  // Exercises (bolt 038): a lesson's list, one exercise, and their order.
  exercises: (lessonId: string) => `${ADMIN}/lessons/${lessonId}/exercises`,
  exercise: (id: string) => `${ADMIN}/exercises/${id}`,
  exerciseOrder: (lessonId: string) => `${ADMIN}/lessons/${lessonId}/exercises/order`,
  // Import (bolt 056): many exercises at once, checked first.
  importExercises: (lessonId: string) => `${ADMIN}/lessons/${lessonId}/exercises/import`,
  // Audio (bolt 039): an upload link for a clip, and a check of a pasted link.
  audioUploads: `${ADMIN}/audio/uploads`,
  audioLinks: `${ADMIN}/audio/links`,
  // Pictures (bolt 050): an upload link for a picture.
  imageUploads: `${ADMIN}/images/uploads`,
  // Vocabulary (bolt 040): a course's words, and one word.
  vocab: (courseId: string) => `${ADMIN}/courses/${courseId}/vocab`,
  vocabItem: (id: string) => `${ADMIN}/vocab/${id}`,
}

/** Every list that can be reordered: the three levels, and a lesson's
 * exercises. */
export type OrderKind = LevelKey | 'exercise'

/** Where a list's new order is sent, whole, by id. `parentId` is the
 * course, section, skill or lesson that holds the list. */
export const orderRoute = (kind: OrderKind, parentId: string): string =>
  kind === 'exercise' ? routes.exerciseOrder(parentId) : routes.order(kind, parentId)
