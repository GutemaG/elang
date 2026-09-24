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

// --- Exercises (bolt 038), mirroring backend/app/domain/lesson/exercise_parts.py

/** A choice, word, letter or match-pairs tile. `id` is identity; `text` is
 * only what is shown, and may repeat (two tiles can both read "ላ"). */
export interface Tile {
  id: string
  text: string
}

export type ExerciseType =
  | 'multiple_choice'
  | 'listening'
  | 'sentence_construction'
  | 'match_pairs'
  | 'gap_fill'
  | 'spell_tiles'

export const EXERCISE_TYPES: readonly ExerciseType[] = [
  'multiple_choice',
  'listening',
  'gap_fill',
  'sentence_construction',
  'spell_tiles',
  'match_pairs',
]

interface ChoiceKey {
  correct_choice_id: string
}

interface SequenceKey {
  correct_sequence: string[]
}

/** The type, prompt, content and answer key an exercise is written as --
 * exactly what `POST`/`PUT` send and what the server stores. */
export type ExerciseBody =
  | { type: 'multiple_choice'; prompt: string; content: { choices: Tile[] }; answer_key: ChoiceKey }
  | {
      type: 'listening'
      prompt: string
      content: { audio_url: string; choices: Tile[] }
      answer_key: ChoiceKey
    }
  | {
      type: 'gap_fill'
      prompt: string
      content: { sentence_before: string; sentence_after: string; choices: Tile[] }
      answer_key: ChoiceKey
    }
  | {
      type: 'sentence_construction'
      prompt: string
      content: { word_bank: Tile[] }
      answer_key: SequenceKey
    }
  | { type: 'spell_tiles'; prompt: string; content: { tiles: Tile[] }; answer_key: SequenceKey }
  | {
      type: 'match_pairs'
      prompt: string
      content: { left_tiles: Tile[]; right_tiles: Tile[] }
      answer_key: { correct_pairs: [string, string][] }
    }

export type AdminExercise = ExerciseBody & {
  id: string
  lesson_id: string
  order_index: number
  vocab_item_id: string | null
}

export interface AdminExerciseList {
  exercises: AdminExercise[]
}
