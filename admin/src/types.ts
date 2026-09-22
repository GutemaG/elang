// Shapes of the admin API, mirrored from backend/app/infrastructure/api/
// admin_schemas.py (and AuthResponse from schemas.py). Keep them in step.

export interface AuthResponse {
  session_token: string
  expires_at: string
}

export interface AdminMe {
  email: string
}

export interface AdminCourse {
  id: string
  title: string
  learning_language: string
  from_language: string
  status: string
  section_count: number
}

export interface AdminCourseList {
  courses: AdminCourse[]
}

/** Listening exercises only: the piano placeholder, a hosted https clip,
 * or a local-backend `/media` clip. */
export type AudioStatus = 'placeholder' | 'hosted' | 'local'

export interface AdminTreeExercise {
  id: string
  order_index: number
  type: string
  prompt: string
  audio: AudioStatus | null
}

export interface AdminTreeLesson {
  id: string
  title: string
  order_index: number
  exercise_count: number
  exercises: AdminTreeExercise[]
}

export interface AdminTreeSkill {
  id: string
  title: string
  order_index: number
  lesson_count: number
  lessons: AdminTreeLesson[]
}

export interface AdminTreeSection {
  id: string
  title: string
  subtitle: string
  order_index: number
  skill_count: number
  skills: AdminTreeSkill[]
}

export interface AdminCourseTree {
  course: AdminCourse
  sections: AdminTreeSection[]
}

/** A section, skill or lesson after a write. */
export interface AdminNode {
  id: string
  title: string
  subtitle: string | null
  order_index: number
}

/** `details` of a refused or unconfirmed delete. */
export interface DeleteDetails {
  skills: number
  lessons: number
  exercises: number
  learners?: number
}
