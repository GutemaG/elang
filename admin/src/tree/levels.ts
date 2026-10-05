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
  // Feedback (027-learner-feedback): the list, and one message's status.
  feedback: `${ADMIN}/feedback`,
  feedbackItem: (id: string) => `${ADMIN}/feedback/${id}`,
  // App updates: the builds the app checks itself against.
  appConfig: `${ADMIN}/app-config`,
  // Sounds: one chart of letters and recordings per learning language.
  soundCharts: `${ADMIN}/sound-charts`,
  soundChart: (language: string) => `${ADMIN}/sound-charts/${language}`,
  soundLetters: (language: string) => `${ADMIN}/sound-charts/${language}/letters`,
  soundLetter: (language: string, id: string) => `${ADMIN}/sound-charts/${language}/letters/${id}`,
  soundUploads: (language: string) => `${ADMIN}/sound-charts/${language}/audio/uploads`,
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
  // Workbook (intent 025): a course's draft curriculum, one row, and an
  // upload link for a row's recording.
  curriculum: (courseId: string) => `${ADMIN}/courses/${courseId}/curriculum`,
  curriculumRow: (courseId: string, ref: string) =>
    `${ADMIN}/courses/${courseId}/curriculum/rows/${encodeURIComponent(ref)}`,
  curriculumUploads: (courseId: string) => `${ADMIN}/courses/${courseId}/curriculum/audio/uploads`,
  curriculumExercises: (courseId: string, ref: string) =>
    `${ADMIN}/courses/${courseId}/curriculum/lessons/${encodeURIComponent(ref)}/exercises`,
  curriculumPublish: (courseId: string, ref: string) =>
    `${ADMIN}/courses/${courseId}/curriculum/lessons/${encodeURIComponent(ref)}/publish`,
}

/** Every list that can be reordered: the three levels, and a lesson's
 * exercises. */
export type OrderKind = LevelKey | 'exercise'

/** Where a list's new order is sent, whole, by id. `parentId` is the
 * course, section, skill or lesson that holds the list. */
export const orderRoute = (kind: OrderKind, parentId: string): string =>
  kind === 'exercise' ? routes.exerciseOrder(parentId) : routes.order(kind, parentId)
